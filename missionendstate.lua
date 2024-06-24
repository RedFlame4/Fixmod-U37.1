function MissionEndState:play_finishing_sound(success)
	if not self._server_left and not success and managers.groupai:state():bain_state() then
		managers.dialog:queue_dialog("Play_ban_g01x", {}) -- doesn't play in U37.1, thanks Overkill!
	end
end