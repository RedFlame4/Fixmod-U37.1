local math_lerp = math.lerp
local math_min = math.min
local math_random = math.random
local math_up = math.UP

local mrot_axis_angle = mrotation.set_axis_angle

local mvec3_add = mvector3.add
local mvec3_cross = mvector3.cross
local mvec3_rot = mvector3.rotate_with
local mvec3_set = mvector3.set
local mvec3_set_l = mvector3.set_length
local mvec3_sub = mvector3.subtract

local temp_rot1 = Rotation()

local temp_vec2 = Vector3()

function CopActionShoot:_get_unit_shoot_pos(t, pos, dis, w_tweak, falloff, i_range, shooting_local_player)
	local shoot_hist = self._shoot_history
	local focus_delay, focus_prog
	if shoot_hist.focus_delay then
		focus_delay = (shooting_local_player and self._attention.unit:character_damage():focus_delay_mul() or 1) * shoot_hist.focus_delay
		focus_prog = focus_delay > 0 and (t - shoot_hist.focus_start_t) / focus_delay

		if not focus_prog or focus_prog >= 1 then
			shoot_hist.focus_delay = nil
			focus_prog = 1
		end
	else
		focus_prog = 1
	end

	local hit_chances = falloff.acc
	local hit_chance
	if i_range == 1 then
		hit_chance = math_lerp(hit_chances[1], hit_chances[2], focus_prog)
	else
		local prev_falloff = w_tweak.FALLOFF[i_range - 1]
		local dis_lerp = math_min(1, (dis - prev_falloff.r) / (falloff.r - prev_falloff.r))
		local prev_range_hit_chance = math_lerp(prev_falloff.acc[1], prev_falloff.acc[2], focus_prog)
		hit_chance = math_lerp(prev_range_hit_chance, math_lerp(hit_chances[1], hit_chances[2], focus_prog), dis_lerp)
	end

	if self._common_data.is_suppressed then
		hit_chance = hit_chance * 0.5
	end

	if self._common_data.active_actions[2] and self._common_data.active_actions[2]:type() == "dodge" then
		hit_chance = hit_chance * self._common_data.active_actions[2]:accuracy_multiplier()
	end

	hit_chance = hit_chance * self._unit:character_damage():accuracy_multiplier()

	if hit_chance > math_random() then
		mvec3_set(shoot_hist.m_last_pos, pos)
	else
		local enemy_vec = temp_vec2
		mvec3_set(enemy_vec, pos)
		mvec3_sub(enemy_vec, self._shoot_from_pos) -- fix this vector being generated from the wrong position

		local error_vec = Vector3()
		mvec3_cross(error_vec, enemy_vec, math_up)
		mrot_axis_angle(temp_rot1, enemy_vec, shoot_hist.focus_error_roll)
		mvec3_rot(error_vec, temp_rot1)

		local miss_min_dis = shooting_local_player and 31 or 150
		local error_vec_len = miss_min_dis + w_tweak.spread + w_tweak.miss_dis * (1 - focus_prog)

		mvec3_set_l(error_vec, error_vec_len)
		mvec3_add(error_vec, pos)
		mvec3_set(shoot_hist.m_last_pos, error_vec)

		return error_vec
	end
end