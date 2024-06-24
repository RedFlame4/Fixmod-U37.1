local math_abs = math.abs
local math_lerp = math.lerp
local math_random = math.random
local math_up = math.UP

local mrot_x = mrotation.x

local mvec3_add = mvector3.add
local mvec3_cross = mvector3.cross
local mvec3_dir = mvector3.direction
local mvec3_dis_sq = mvector3.distance_sq
local mvec3_dot = mvector3.dot
local mvec3_len = mvector3.length
local mvec3_mul = mvector3.multiply
local mvec3_negate = mvector3.negate
local mvec3_norm = mvector3.normalize
local mvec3_rand_orth = mvector3.random_orthogonal
local mvec3_set = mvector3.set
local mvec3_set_z = mvector3.set_z
local mvec3_step = mvector3.step
local mvec3_sub = mvector3.subtract

local pairs_g = pairs

local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()

function CopLogicBase.chk_start_action_dodge(data, reason)
	local char_tweak_dodge = data.char_tweak.dodge
	if not char_tweak_dodge or not char_tweak_dodge.occasions[reason] or data.dodge_chk_timeout_t and data.t < data.dodge_chk_timeout_t or data.unit:movement():chk_action_forbidden("walk") then
		return
	end

	local dodge_tweak = char_tweak_dodge.occasions[reason]
	data.dodge_chk_timeout_t = TimerManager:game():time() + math_lerp(dodge_tweak.check_timeout[1], dodge_tweak.check_timeout[2], math_random())

	if dodge_tweak.chance == 0 or dodge_tweak.chance < math_random() then
		return
	end

	local dodge_dir = Vector3()
	if data.attention_obj and AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
		mvec3_set(dodge_dir, data.attention_obj.m_pos)
		mvec3_sub(dodge_dir, data.m_pos)
		mvec3_set_z(dodge_dir, 0)
		mvec3_norm(dodge_dir)
		mvec3_cross(dodge_dir, dodge_dir, math_up)

		if math_random() < 0.5 then
			mvec3_negate(dodge_dir)
		end
	else
		mvec3_rand_orth(dodge_dir, math_up)
	end

	local vec1 = tmp_vec1
	local dis = nil

	mvec3_set(vec1, dodge_dir)
	mvec3_mul(vec1, 130)
	mvec3_add(vec1, data.m_pos)

	local ray_params = {
		trace = true,
		tracker_from = data.unit:movement():nav_tracker(),
		pos_to = vec1
	}

	if managers.navigation:raycast(ray_params) then
		mvec3_set(vec1, ray_params.trace[1])
		mvec3_sub(vec1, data.m_pos)
		mvec3_set_z(vec1, 0)

		dis = mvec3_len(vec1)

		mvec3_set(vec1, dodge_dir)
		mvec3_mul(vec1, -130)
		mvec3_add(vec1, data.m_pos)

		if managers.navigation:raycast(ray_params) then
			mvec3_set(vec1, ray_params.trace[1])
			mvec3_sub(vec1, data.m_pos)
			mvec3_set_z(vec1, 0)

			local new_dis = mvec3_len(vec1)
			if new_dis > dis then
				if new_dis < 90 then
					return -- not enough distance
				else
					mvec3_negate(dodge_dir)
				end
			elseif dis < 90 then
				return -- not enough distance
			end
		else
			mvec3_negate(dodge_dir)
		end
	end

	mrot_x(data.unit:movement():m_rot(), vec1)

	local fwd_dot = mvec3_dot(dodge_dir, data.unit:movement():m_fwd())
	local right_dot = mvec3_dot(dodge_dir, vec1)
	local dodge_side = math_abs(fwd_dot) > 0.7071067690849 and (fwd_dot > 0 and "fwd" or "bwd") or right_dot > 0 and "r" or "l"

	local rand_nr = math_random()
	local total_chance = 0
	local variation, variation_data = nil

	for test_variation, test_variation_data in pairs_g(dodge_tweak.variations) do
		total_chance = total_chance + test_variation_data.chance

		if test_variation_data.chance > 0 and rand_nr <= total_chance then
			variation = test_variation
			variation_data = test_variation_data

			break
		end
	end

	local body_part = 1
	local shoot_chance = variation_data.shoot_chance
	if shoot_chance and shoot_chance > math.random() then
		body_part = 2
	end

	local action_data = {
		type = "dodge",
		body_part = body_part,
		variation = variation,
		side = dodge_side,
		direction = dodge_dir,
		timeout = variation_data.timeout,
		speed = char_tweak_dodge.speed,
		shoot_accuracy = variation_data.shoot_accuracy,
		blocks = {
			walk = -1,
			act = -1,
			tase = -1,
			dodge = -1
		}
	}

	if body_part == 1 then
		action_data.blocks.aim = -1
		action_data.blocks.action = -1
	end

	if variation ~= "side_step" then
		action_data.blocks.hurt = -1
		action_data.blocks.heavy_hurt = -1
	end

	local action = data.unit:movement():action_request(action_data)
	if action then
		local my_data = data.internal_data

		CopLogicAttack._cancel_cover_pathing(data, my_data)
		CopLogicAttack._cancel_charge(data, my_data)
		CopLogicAttack._cancel_expected_pos_path(data, my_data)
		CopLogicAttack._cancel_walking_to_cover(data, my_data, true)
	end

	return action
end

function CopLogicBase.chk_am_i_aimed_at(data, attention_obj, max_dot)
	if not attention_obj.is_person then
		return
	end

	if attention_obj.dis < 700 and max_dot > 0.3 then
		max_dot = math.lerp(0.3, max_dot, (attention_obj.dis - 50) / 650)
	end

	local enemy_look_dir = tmp_vec1
	if attention_obj.is_local_player then
		mrotation.y(attention_obj.unit:movement():m_head_rot(), enemy_look_dir)
	elseif attention_obj.is_husk_player then
		mvec3_set(enemy_look_dir, attention_obj.unit:movement():detect_look_dir())
	else
		mvec3_set(enemy_look_dir, attention_obj.unit:movement():look_vec())
	end

	local enemy_vec = tmp_vec2
	mvec3_dir(enemy_vec, attention_obj.m_head_pos, data.unit:movement():m_com())

	return max_dot < mvec3_dot(enemy_vec, enemy_look_dir)
end

--[[function CopLogicBase._chk_alert_obstructed(my_listen_pos, alert_data)
	if alert_data[3] then
		local alert_epicenter
		if alert_data[1] == "bullet" then
			alert_epicenter = tmp_vec1
			mvec3_step(alert_epicenter, alert_data[2], alert_data[6], 50)
		else
			alert_epicenter = alert_data[2]
		end

		local ray = World:raycast("ray", my_listen_pos, alert_epicenter, "slot_mask", managers.slot:get_mask("AI_visibility"), "ray_type", "ai_vision", "report")
		if ray then
			if alert_data[1] == "footstep" then
				return true
			end

			local my_dis_sq = mvec3_dis_sq(my_listen_pos, alert_epicenter)
			local dampening = alert_data[1] == "bullet" and 0.5 or 0.25
			local effective_dis_sq = alert_data[3] * dampening
			effective_dis_sq = effective_dis_sq * effective_dis_sq

			if my_dis_sq > effective_dis_sq then
				return true
			end
		end
	end
end--]]