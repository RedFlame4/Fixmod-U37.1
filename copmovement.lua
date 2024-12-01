local mvec3_add = mvector3.add
local mvec3_mul = mvector3.multiply
local mvec3_set = mvector3.set

local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()

Hooks:PreHook(CopMovement, "_upd_stance", "fixmod_upd_stance", function(self, t)
	if self._suppression.transition and self._suppression.transition.next_upd_t < t or self._stance.transition and self._stance.transition.next_upd_t < t then
		self._force_head_upd = true -- update head position vector
	end
end)

local play_redirect_orig = CopMovement.play_redirect
function CopMovement:play_redirect(redirect_name, at_time)
	local result = play_redirect_orig(self, redirect_name, at_time)
	if result and redirect_name == "suppressed_reaction" and self._ext_anim.stand then
		self._machine:set_parameter(result, "from_stand", 1) -- so cops don't play a crouch-suppress animation when they're standing
	end

	return result
end

Hooks:PostHook(CopMovement, "_change_stance", "REAI_change_stance", function(self)
	self._force_head_upd = true -- update head position vector
end)

function CopMovement:synch_attention(attention)
	if attention and self._unit:character_damage():dead() then
		debug_pause_unit(self._unit, "[CopMovement:synch_attention] dead AI", self._unit, inspect(attention))
	end

	self:_remove_attention_destroy_listener(self._attention)
	self:_add_attention_destroy_listener(attention)

	if attention and attention.unit and not attention.destroy_listener_key then
		debug_pause_unit(attention.unit, "[CopMovement:synch_attention] problematic attention unit", attention.unit)
		self:synch_attention(nil)
		return
	end

	local old_attention = self._attention
	self._attention = attention
	self._action_common_data.attention = attention

	for _, action in ipairs(self._active_actions) do
		if action and action.on_attention then
			action:on_attention(attention, old_attention) -- actually call the on_attention function with the previous attention, as underdog will bug out for clients otherwise
		end
	end
end

function CopMovement:sync_action_walk_stop()
	local walk_action, is_queued = self:_get_latest_walk_action()
	if is_queued then
		walk_action.persistent = nil
	elseif walk_action then
		walk_action:stop()
	else
		debug_pause("[CopMovement:sync_action_walk_stop] no walk action!!!", self._unit)
	end
end

function CopMovement:sync_action_dodge_start(body_part, var, side, rot, speed, shoot_acc)
	if self._ext_damage:dead() then
		return
	end

	local var_name = CopActionDodge.get_variation_name(var)
	local action_data = {
		type = "dodge",
		body_part = body_part,
		variation = var_name,
		direction = Rotation(rot):y(),
		side = CopActionDodge.get_side_name(side),
		speed = speed,
		shoot_accuracy = shoot_acc,
		blocks = {
			walk = -1,
			act = -1,
			idle = -1,
			turn = -1,
			tase = -1,
			dodge = -1
		}
	}

	if body_part == 1 then
		action_data.blocks.aim = -1
		action_data.blocks.action = -1
	end

	if var_name ~= "side_step" then
		action_data.blocks.hurt = -1
		action_data.blocks.heavy_hurt = -1
	end

	self:action_request(action_data)
end

Hooks:PostHook(CopMovement, "pre_destroy", "fixmod_pre_destroy", function(self)
	if self._melee_item_unit then
		self:anim_clbk_enemy_unspawn_melee_item() -- only happens if the unit despawns while they're meleeing
	end
end)

function CopMovement:look_vec()
	return self._action_common_data.look_vec
end