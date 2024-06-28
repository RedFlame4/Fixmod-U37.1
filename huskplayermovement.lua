local mvec3_set = mvector3.set
local mvec3_set_z = mvector3.set_z

Hooks:PostHook(HuskPlayerMovement, "post_init", "promod_post_init", function(self)
	self._attention_handler:setup_attention_positions(self._m_detect_pos, self._m_newest_pos)
end)

function HuskPlayerMovement:_calculate_m_pose()
	mrotation.set_look_at(self._m_head_rot, self._look_dir, math.UP)
	self._obj_head:m_position(self._m_head_pos)
	self._obj_spine:m_position(self._m_com)
end

function HuskPlayerMovement:set_position( pos )
	mvector3.set(self._m_pos, pos)
	self._unit:set_position(pos)
end

Hooks:PreHook(HuskPlayerMovement, "sync_action_walk_nav_point", "promod_sync_action_walk_nav_point", function(self, pos)
	mvec3_set(self._m_newest_pos, pos)
	mvec3_set(self._m_detect_pos, pos)
	mvec3_set_z(self._m_detect_pos, self._m_detect_pos.z + (self._pose_code == 2 and tweak_data.player.stances.default.crouched.head.translation.z or tweak_data.player.stances.default.standard.head.translation.z))

	if self._nav_tracker then
		self._nav_tracker:move(pos)

		local nav_seg_id = self._nav_tracker:nav_segment()
		if self._standing_nav_seg_id ~= nav_seg_id then
			self._standing_nav_seg_id = nav_seg_id

			local metadata = managers.navigation:get_nav_seg_metadata(nav_seg_id)

			self._unit:base():set_suspicion_multiplier("area", metadata.suspicion_mul)
			self._unit:base():set_detection_multiplier("area", metadata.detection_mul and 1/metadata.detection_mul or nil)
			managers.groupai:state():on_criminal_nav_seg_change(self._unit, nav_seg_id)
		end
	end
end)

Hooks:PreHook(HuskPlayerMovement, "_change_pose", "promod_change_pose", function(self, pose_code)
	-- Doesn't account for the time taken to stand/crouch, but using husk head position isn't accurate for the time taken either + the position isn't consistent with what it would be locally for the player
	mvec3_set_z(self._m_detect_pos, self._m_newest_pos.z + (pose_code == 2 and tweak_data.player.stances.default.crouched.head.translation.z or tweak_data.player.stances.default.standard.head.translation.z))
end)

local _get_max_move_speed_orig = HuskPlayerMovement._get_max_move_speed
function HuskPlayerMovement:_get_max_move_speed(...)
	local move_speed = _get_max_move_speed_orig(self, ...)

	-- increase husk speed if they're particularly far away from the correct position
	-- this only affects the cosmetic husk since detection is now tied to last synced position
	-- but it is still good to keep it relatively in sync anyway
	local path_length = #self._move_data.path - 2
	if path_length > 0 then
		move_speed = move_speed * (1 + path_length / 20) -- 5% boost for every navpoint behind past the first one
	end

	return move_speed
end