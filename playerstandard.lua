local mvec3_add = mvector3.add
local mvec3_dis_sq = mvector3.distance_sq
local mvec3_mul = mvector3.multiply
local mvec3_norm = mvector3.normalize
local mvec3_set = mvector3.set
local mvec3_sub = mvector3.subtract

Hooks:PreHook(PlayerStandard, "exit", "promod_exit", function(self, state_data, new_state_name)
	if mvec3_dis_sq(self._pos, self._last_sent_pos) > 1 and new_state_name ~= "standard" and new_state_name ~= "carry" and new_state_name ~= "mask_off" and new_state_name ~= "clean" then
		self._ext_network:send("action_walk_nav_point", self._pos) -- sync our exact position

		mvec3_set(self._last_sent_pos, self._pos)
		self._last_sent_pos_t = managers.player:player_timer():time()
	end
end)

local tmp_vec1 = Vector3()
function PlayerStandard:_upd_nav_data()
	if mvec3_dis_sq(self._m_pos, self._pos) > 1 then
		if self._ext_movement:nav_tracker() then
			self._ext_movement:nav_tracker():move(self._pos)

			local nav_seg_id = self._ext_movement:nav_tracker():nav_segment()
			if self._standing_nav_seg_id ~= nav_seg_id then
				self._standing_nav_seg_id = nav_seg_id

				local metadata = managers.navigation:get_nav_seg_metadata(nav_seg_id)
				local location_id = metadata.location_id

				managers.hud:set_player_location(location_id)

				self._unit:base():set_suspicion_multiplier("area", metadata.suspicion_mul)
				self._unit:base():set_detection_multiplier("area", metadata.detection_mul and 1 / metadata.detection_mul or nil)

				managers.groupai:state():on_criminal_nav_seg_change(self._unit, nav_seg_id)
			end
		end

		if self._pos_reservation then
			managers.navigation:move_pos_rsrv(self._pos_reservation)

			local slow_dist = 100

			mvec3_set(tmp_vec1, self._pos_reservation_slow.position)
			mvec3_sub(tmp_vec1, self._pos_reservation.position)

			if slow_dist < mvec3_norm(tmp_vec1) then
				mvec3_mul(tmp_vec1, slow_dist)
				mvec3_add(tmp_vec1, self._pos_reservation.position)
				mvec3_set(self._pos_reservation_slow.position, tmp_vec1)

				managers.navigation:move_pos_rsrv(self._pos_reservation_slow) -- moves the wrong position reservation, nice job overkill!
			end
		end

		self._ext_movement:set_m_pos(self._pos)
	end
end

Hooks:PostHook(PlayerStandard, "_calculate_standard_variables", "promod_calculate_standard_variables", function(self)
    self._cam_fwd_flat = Rotation(self._camera_unit:rotation():yaw(), 0, 0):y()
end)

Hooks:PostHook(PlayerStandard, "_interupt_action_reload", "promod_interupt_action_reload", function(self)
    self._queue_reload_interupt = nil
end)