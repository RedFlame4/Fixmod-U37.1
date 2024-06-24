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