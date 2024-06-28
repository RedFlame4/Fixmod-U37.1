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

function CopLogicBase._upd_attention_obj_detection(data, min_reaction, max_reaction)
	local t = data.t
	local detected_obj = data.detected_attention_objects
	local my_data = data.internal_data
	local my_key = data.key
	local my_pos = data.unit:movement():m_head_pos()
	local my_access = data.SO_access
	local all_attention_objects = managers.groupai:state():get_AI_attention_objects_by_filter(data.SO_access_str, data.team)
	local my_head_fwd
	local my_tracker = data.unit:movement():nav_tracker()
	local chk_vis_func = my_tracker.check_visibility
	local is_detection_persistent = managers.groupai:state():is_detection_persistent()
	local delay = 1
	local player_importance_wgt = data.unit:in_slot(managers.slot:get_mask("enemies")) and {}
	local function _angle_chk(attention_pos, dis, strictness)
		mvector3.direction(tmp_vec1, my_pos, attention_pos)
		my_head_fwd = my_head_fwd or data.unit:movement():m_head_rot():z()
		local angle = mvector3.angle(my_head_fwd, tmp_vec1)
		local angle_max = math.lerp(180, my_data.detection.angle_max, math.clamp((dis - 150) / 700, 0, 1))
		if angle_max > angle * strictness then
			return true
		end
	end

	local function _angle_and_dis_chk(handler, settings, attention_pos)
		attention_pos = attention_pos or handler:get_detection_m_pos()
		local dis = mvector3.direction(tmp_vec1, my_pos, attention_pos)
		local dis_multiplier, angle_multiplier
		local max_dis = math.min(my_data.detection.dis_max, settings.max_range or my_data.detection.dis_max)
		if settings.detection and settings.detection.range_mul then
			max_dis = max_dis * settings.detection.range_mul
		end
		dis_multiplier = dis / max_dis
		if settings.uncover_range and my_data.detection.use_uncover_range and dis < settings.uncover_range then
			return -1, 0
		end
		if dis_multiplier < 1 then
			if settings.notice_requires_FOV then
				my_head_fwd = my_head_fwd or data.unit:movement():m_head_rot():z()
				local angle = mvector3.angle(my_head_fwd, tmp_vec1)
				if angle < 55 and not my_data.detection.use_uncover_range and settings.uncover_range and dis < settings.uncover_range then
					return -1, 0
				end
				local angle_max = math.lerp(180, my_data.detection.angle_max, math.clamp((dis - 150) / 700, 0, 1))
				angle_multiplier = angle / angle_max
				if angle_multiplier < 1 then
					return angle, dis_multiplier
				end
			else
				return 0, dis_multiplier
			end
		end
	end

	local function _nearly_visible_chk(attention_info, detect_pos)
		local near_pos = tmp_vec1
		if attention_info.verified_dis < 2000 and math.abs(detect_pos.z - my_pos.z) < 300 then
			mvec3_set(near_pos, detect_pos)
			mvec3_set_z(near_pos, near_pos.z + 100)
			local near_vis_ray = World:raycast("ray", my_pos, near_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report")
			if near_vis_ray then
				local side_vec = tmp_vec2
				mvec3_set(side_vec, detect_pos)
				mvec3_sub(side_vec, my_pos)
				mvector3.cross(side_vec, side_vec, math.UP)
				mvector3.set_length(side_vec, 150)
				mvector3.set(near_pos, detect_pos)
				mvector3.add(near_pos, side_vec)
				local near_vis_ray = World:raycast("ray", my_pos, near_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report")
				if near_vis_ray then
					mvector3.multiply(side_vec, -2)
					mvector3.add(near_pos, side_vec)
					near_vis_ray = World:raycast("ray", my_pos, near_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report")
				end
			end
			if not near_vis_ray then
				attention_info.nearly_visible = true
				attention_info.last_verified_pos = mvector3.copy(near_pos)
			end
		end
	end

	local function _chk_record_pl_importance_wgt(attention_info)
		if not player_importance_wgt or not attention_info.is_human_player then
			return
		end
		local weight = mvector3.direction(tmp_vec1, attention_info.m_head_pos, my_pos)
		local e_fwd
		if attention_info.is_husk_player then
			e_fwd = attention_info.unit:movement():detect_look_dir()
		else
			e_fwd = attention_info.unit:movement():m_head_rot():y()
		end
		local dot = mvector3.dot(e_fwd, tmp_vec1)
		weight = weight * weight * (1 - dot)
		table.insert(player_importance_wgt, attention_info.u_key)
		table.insert(player_importance_wgt, weight)
	end

	for u_key, attention_info in pairs(all_attention_objects) do
		if u_key ~= my_key and not detected_obj[u_key] and (not attention_info.nav_tracker or chk_vis_func(my_tracker, attention_info.nav_tracker)) then
			local settings = attention_info.handler:get_attention(my_access, min_reaction, max_reaction, data.team)
			if settings then
				local attention_pos = attention_info.handler:get_detection_m_pos()
				if _angle_and_dis_chk(attention_info.handler, settings, attention_pos) then
					local vis_ray = World:raycast("ray", my_pos, attention_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")
					if not vis_ray or vis_ray.unit:key() == u_key then
						detected_obj[u_key] = CopLogicBase._create_detected_attention_object_data(data, my_data, u_key, attention_info, settings)
					end
				end
			end
		end
	end
	for u_key, attention_info in pairs(detected_obj) do
		if not data.important and t < attention_info.next_verify_t then
			delay = math.min(attention_info.next_verify_t - t, delay)
		else
			attention_info.next_verify_t = t + (attention_info.identified and attention_info.verified and attention_info.settings.verification_interval or attention_info.settings.notice_interval or attention_info.settings.verification_interval)
			delay = math.min(delay, attention_info.settings.verification_interval)
			if not attention_info.identified then
				local noticable
				local angle, dis_multiplier = _angle_and_dis_chk(attention_info.handler, attention_info.settings)
				if angle then
					local attention_pos = attention_info.handler:get_detection_m_pos()
					local vis_ray = World:raycast("ray", my_pos, attention_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")
					if not vis_ray or vis_ray.unit:key() == u_key then
						noticable = true
					end
				end
				local delta_prog
				local dt = t - attention_info.prev_notice_chk_t
				if noticable then
					if angle == -1 then
						delta_prog = 1
					else
						local min_delay = my_data.detection.delay[1]
						local max_delay = my_data.detection.delay[2]
						local angle_mul_mod = 0.25 * math.min(angle / my_data.detection.angle_max, 1)
						local dis_mul_mod = 0.75 * dis_multiplier
						local notice_delay_mul = attention_info.settings.notice_delay_mul or 1
						if attention_info.settings.detection and attention_info.settings.detection.delay_mul then
							notice_delay_mul = notice_delay_mul * attention_info.settings.detection.delay_mul
						end
						local notice_delay_modified = math.lerp(min_delay * notice_delay_mul, max_delay, dis_mul_mod + angle_mul_mod)
						delta_prog = notice_delay_modified > 0 and dt / notice_delay_modified or 1
					end
				else
					delta_prog = dt * -0.125
				end
				attention_info.notice_progress = attention_info.notice_progress + delta_prog
				if 1 < attention_info.notice_progress then
					attention_info.notice_progress = nil
					attention_info.prev_notice_chk_t = nil
					attention_info.identified = true
					attention_info.release_t = t + attention_info.settings.release_delay
					attention_info.identified_t = t
					noticable = true
					data.logic.on_attention_obj_identified(data, u_key, attention_info)
				elseif 0 > attention_info.notice_progress then
					CopLogicBase._destroy_detected_attention_object_data(data, attention_info)
					noticable = false
				else
					noticable = attention_info.notice_progress
					attention_info.prev_notice_chk_t = t
					if data.cool and attention_info.settings.reaction >= AIAttentionObject.REACT_SCARED then
						managers.groupai:state():on_criminal_suspicion_progress(attention_info.unit, data.unit, noticable)
					end
				end
				if noticable ~= false and attention_info.settings.notice_clbk then
					attention_info.settings.notice_clbk(data.unit, noticable)
				end
			end
			if attention_info.identified then
				delay = math.min(delay, attention_info.settings.verification_interval)
				attention_info.nearly_visible = nil
				local verified, vis_ray
				local attention_pos = attention_info.handler:get_detection_m_pos()
				local dis = mvector3.distance(data.m_pos, attention_info.m_pos)
				if dis < my_data.detection.dis_max * 1.2 and ( not attention_info.settings.max_range or dis < attention_info.settings.max_range * ( attention_info.settings.detection and attention_info.settings.detection.range_mul or 1 ) * 1.2 ) then -- 20% tolerance
					local in_FOV = not attention_info.settings.notice_requires_FOV or data.enemy_slotmask and attention_info.unit:in_slot(data.enemy_slotmask) or _angle_chk(attention_pos, dis, 0.8)
					if in_FOV then
						vis_ray = World:raycast("ray", my_pos, attention_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")
						if not vis_ray or vis_ray.unit:key() == u_key then
							verified = true
						end
					end
				end
				attention_info.verified = verified
				attention_info.dis = dis
				attention_info.vis_ray = vis_ray and vis_ray.dis or nil
				if verified then
					attention_info.release_t = nil
					attention_info.verified_t = t
					mvector3.set(attention_info.verified_pos, attention_pos)
					attention_info.last_verified_pos = mvector3.copy(attention_pos)
					attention_info.verified_dis = dis
				elseif data.enemy_slotmask and attention_info.unit:in_slot(data.enemy_slotmask) then
					if attention_info.criminal_record and attention_info.settings.reaction >= AIAttentionObject.REACT_COMBAT then
						if not is_detection_persistent and mvector3.distance(attention_pos, attention_info.criminal_record.pos) > 700 then -- should be using last_verified_pos
							CopLogicBase._destroy_detected_attention_object_data(data, attention_info)
						else
							delay = math.min(0.2, delay)
							attention_info.verified_pos = mvector3.copy(attention_info.criminal_record.pos)
							attention_info.verified_dis = dis
							if vis_ray and data.logic._chk_nearly_visible_chk_needed(data, attention_info, u_key) then
								_nearly_visible_chk(attention_info, attention_pos)
							end
						end
					elseif attention_info.release_t and t > attention_info.release_t then
						CopLogicBase._destroy_detected_attention_object_data(data, attention_info)
					else
						attention_info.release_t = attention_info.release_t or t + attention_info.settings.release_delay
					end
				elseif attention_info.release_t and t > attention_info.release_t then
					CopLogicBase._destroy_detected_attention_object_data(data, attention_info)
				else
					attention_info.release_t = attention_info.release_t or t + attention_info.settings.release_delay
				end
			end
		end
		_chk_record_pl_importance_wgt(attention_info)
	end

	if player_importance_wgt then
		managers.groupai:state():set_importance_weight(data.key, player_importance_wgt)
	end

	return delay
end

-- TODO: Fix detection progress resetting on mask up
--[[function CopLogicBase.on_detected_attention_obj_modified(data, modified_u_key)
	if data.logic.on_detected_attention_obj_modified_internal then
		data.logic.on_detected_attention_obj_modified_internal(data, modified_u_key)
	end
	local attention_info = data.detected_attention_objects[modified_u_key]
	if not attention_info then
		return
	end
	local new_settings = attention_info.handler:get_attention(data.SO_access, nil, nil, data.team)
	local old_settings = attention_info.settings
	if new_settings == old_settings then
		return
	end
	local old_notice_clbk = not attention_info.identified and old_settings.notice_clbk
	if new_settings then
		local switch_from_suspicious = new_settings.reaction >= AIAttentionObject.REACT_SCARED and attention_info.reaction <= AIAttentionObject.REACT_SUSPICIOUS
		attention_info.settings = new_settings
		attention_info.stare_expire_t = nil
		attention_info.pause_expire_t = nil
		if attention_info.uncover_progress then
			attention_info.uncover_progress = nil
			attention_info.unit:movement():on_suspicion(data.unit, false)
			managers.groupai:state():on_criminal_suspicion_progress(attention_info.unit, data.unit, nil)
		end
		if attention_info.identified then
			if switch_from_suspicious then
				attention_info.identified = false
				attention_info.notice_progress = attention_info.uncover_progress or 0
				attention_info.verified = nil
				attention_info.next_verify_t = 0
				attention_info.prev_notice_chk_t = TimerManager:game():time()
			end
		elseif switch_from_suspicious then
			attention_info.next_verify_t = 0
			attention_info.notice_progress = 0
			attention_info.prev_notice_chk_t = TimerManager:game():time()
		end
		attention_info.reaction = math.min(new_settings.reaction, attention_info.reaction)
	else
		CopLogicBase._destroy_detected_attention_object_data(data, attention_info)
		local my_data = data.internal_data
		if data.attention_obj and data.attention_obj.u_key == modified_u_key then
			CopLogicBase._set_attention_obj(data, nil, nil)
			if my_data and (my_data.firing or my_data.firing_on_client) then
				data.unit:movement():set_allow_fire(false)
				my_data.firing = nil
				my_data.firing_on_client = nil
			end
		end
		if my_data.arrest_targets then
			my_data.arrest_targets[modified_u_key] = nil
		end
	end
	if old_notice_clbk and (not new_settings or not new_settings.notice_clbk) then
		old_notice_clbk(data.unit, false)
	end
	if old_settings.reaction >= AIAttentionObject.REACT_SCARED and (not new_settings or not (new_settings.reaction >= AIAttentionObject.REACT_SCARED)) then
		managers.groupai:state():on_criminal_suspicion_progress(attention_info.unit, data.unit, nil)
	end
end--]]

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