local mvec3_add = mvector3.add
local mvec3_dis_sq = mvector3.distance_sq
local mvec3_mul = mvector3.multiply
local mvec3_set = mvector3.set

local tmp_vec1 = Vector3()

-- Fix suppression amount being inverse to angle
local check_autoaim_original = RaycastWeaponBase.check_autoaim
function RaycastWeaponBase:check_autoaim(...)
	local closest_ray, suppression_enemies = check_autoaim_original(self, ...)
	if suppression_enemies then
		for k, dis_error in pairs(suppression_enemies) do
			suppression_enemies[k] = 1 - dis_error
		end
	end

	return closest_ray, suppression_enemies
end

-- Fix stale alerts, if alert radius changed since the last time an alert occurred it may get discarded wrongly
-- This only really affects saws
function RaycastWeaponBase:_check_alert(rays, fire_pos, direction, user_unit)
	local group_ai = managers.groupai:state()
	local t = TimerManager:game():time()
	local exp_t = t + 1.5
	local all_alerts = self._alert_events
	local alert_rad = self._alert_size / 4
	local from_pos = tmp_vec1
	local tolerance = 500 * 500

	mvec3_set(from_pos, direction)
	mvec3_mul(from_pos, -alert_rad) 
	mvec3_add(from_pos, fire_pos)

	for i = #all_alerts, 1, -1 do
		if all_alerts[i][3] < t then	-- This alert is too old. remove
			table.remove(all_alerts, i)
		end
	end

	if #rays > 0 then
		for _, ray in ipairs(rays) do
			local event_pos = ray.position
			for i = #all_alerts, 1, -1 do
				local alert = all_alerts[i]
				if alert_rad <= alert[4] and mvec3_dis_sq(alert[1], event_pos) < tolerance and mvec3_dis_sq(alert[2], from_pos) < tolerance then -- this alert is fresh and very close to the new one. skip the new alert
					event_pos = nil
					break
				end
			end

			if event_pos then
				-- The new alert can go through to enemy manager to be distributed to AI units
				table.insert(all_alerts, {event_pos, from_pos, exp_t, alert_rad})
				group_ai:propagate_alert({"bullet", event_pos, alert_rad, self._setup.alert_filter, user_unit, from_pos})
			end
		end
	end

	local fire_alerts = self._alert_fires
	local cached = false
	for i = #fire_alerts, 1, -1 do
		local alert = fire_alerts[i]
		if alert[2] < t then	-- This alert is too old. remove
			table.remove(fire_alerts, i)
		elseif self._alert_size <= alert[3] and mvec3_dis_sq(alert[1], fire_pos) < tolerance then -- this alert is fresh and very close to the new one. skip the new alert
			cached = true
			break
		end
	end

	if not cached then
		table.insert(fire_alerts, {fire_pos, exp_t, self._alert_size})
		group_ai:propagate_alert({"bullet", fire_pos, self._alert_size, self._setup.alert_filter, user_unit, from_pos})
	end
end

function InstantBulletBase:on_collision(col_ray, weapon_unit, user_unit, damage, blank)
	local hit_unit = col_ray.unit
	local char_dmg_ext = hit_unit:character_damage()
	local play_impact_flesh = not char_dmg_ext or not char_dmg_ext._no_blood
	local result
	if hit_unit:damage() and col_ray.body:extension() and col_ray.body:extension().damage then
		local sync_damage = not blank and hit_unit:id() ~= -1
		local network_damage = math.ceil(damage * 163.84)
		damage = network_damage / 163.84

		if sync_damage then
			local normal_vec_yaw, normal_vec_pitch = self._get_vector_sync_yaw_pitch(col_ray.normal, 128, 64)
			local dir_vec_yaw, dir_vec_pitch = self._get_vector_sync_yaw_pitch(col_ray.ray, 128, 64)

			managers.network:session():send_to_peers_synched("sync_body_damage_bullet", col_ray.unit:id() ~= -1 and col_ray.body or nil, user_unit:id() ~= -1 and user_unit or nil, normal_vec_yaw, normal_vec_pitch, col_ray.position, dir_vec_yaw, dir_vec_pitch, math.min(16384, network_damage))
		end

		local local_damage = not blank or hit_unit:id() == -1
		if local_damage then
			col_ray.body:extension().damage:damage_bullet(user_unit, col_ray.normal, col_ray.position, col_ray.ray, 1)
			col_ray.body:extension().damage:damage_damage(user_unit, col_ray.normal, col_ray.position, col_ray.ray, damage)
		end

		if char_dmg_ext then
			managers.hud:on_hit_confirmed() -- still give the hitmarker even though it didn't damage the unit itself
		end

		managers.game_play_central:physics_push(col_ray)
	elseif char_dmg_ext and char_dmg_ext.damage_bullet then -- only apply damage to a character if not hitting a body that can take damage itself
		local is_alive = not char_dmg_ext:dead()
		result = self:give_impact_damage(col_ray, weapon_unit, user_unit, damage)

		if result ~= "friendly_fire" then
			local is_dead = char_dmg_ext:dead()
			local push_multiplier = self:_get_character_push_multiplier(weapon_unit, is_alive and is_dead)
			managers.game_play_central:physics_push(col_ray, push_multiplier)
		else
			play_impact_flesh = false
		end
	else
		managers.game_play_central:physics_push(col_ray)
	end

	if play_impact_flesh then
		managers.game_play_central:play_impact_flesh({col_ray = col_ray})
		self:play_impact_sound_and_effects(col_ray)
	end

	return result
end