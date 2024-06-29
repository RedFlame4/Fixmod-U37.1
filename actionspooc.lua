local idstr_base = Idstring("base")

local mvec3_dis = mvector3.distance
local mvec3_set = mvector3.set
local mvec3_set_z = mvector3.set_z

local next_g = next

local tmp_vec1 = Vector3()

-- Distance without the influence of z
local function mvec3_dis_no_z(a, b)
	mvec3_set(tmp_vec1, b)
	mvec3_set_z(tmp_vec1, a.z)

	return mvec3_dis(a, tmp_vec1)
end

Hooks:PreHook(ActionSpooc, "init", "fixmod_init", function(self, action_desc, common_data)
	self._ext_anim = common_data.ext_anim

	if not self._ext_anim.pose then
		debug_pause_unit(self._unit, "[CopActionWalk:init] no pose in anim", self._machine:segment_state(idstr_base), self._unit)

		local res = self._ext_movement:play_redirect("idle")
		if not self._ext_anim.pose then
			print("[CopActionWalk:init] failed restoring pose with anim", self._machine:segment_state(idstr_base), res)

			if not self._ext_movement:play_state("std/stand/still/idle/look") then
				return debug_pause()
			end
		end
	end

	if not action_desc.flying_strike and self._ext_anim.pose ~= "stand" then
		common_data.ext_movement:play_redirect("stand")
	end
end)

function ActionSpooc:complete()
	return self._beating_end_t and TimerManager:game():time() > self._beating_end_t and (not self:is_flying_strike() or self._last_vel_z >= 0)
end

function ActionSpooc:_get_current_max_walk_speed(move_dir)
	if move_dir == "l" or move_dir == "r" then
		move_dir = "strafe"
	end

	local speed = self._common_data.char_tweak.move_speed[self._ext_anim.pose][self._haste][self._stance.name][move_dir]
	-- wack, don't speed up cloakers on clients if they're handling it locally, need i say why that's dumb
	-- also allow them to be sped up on the host if it's being handled by a client
	if not self._is_local and self:_husk_needs_speedup() then
		speed = speed * (1 + (Unit.occluded(self._unit) and 1 or CopActionWalk.lod_multipliers[self._ext_base:lod_stage()] or 1))
	end

	return speed
end

function ActionSpooc:_husk_needs_speedup()
	local queued_actions = self._ext_movement._queued_actions
	if queued_actions and next_g(queued_actions) then
		return true
	elseif #self._nav_path > 2 then
		local prev_pos = self._common_data.pos
		local dis_error_total = 0
		for i = 2, #self._nav_path do
			local next_pos = self._nav_path[i]
			dis_error_total = dis_error_total + mvec3_dis_no_z(prev_pos, next_pos) -- Don't use dis_sq, that's likely to skew the results substantially
			prev_pos = next_pos
		end

		if dis_error_total > 300 then -- Maybe raise this value
			return true
		end
	end
end