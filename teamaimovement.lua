Hooks:PostHook(TeamAIMovement, "on_SPOOCed", "fixmod_on_SPOOCed", function()
	return true
end)

function TeamAIMovement:pre_destroy()
	TeamAIMovement.super.pre_destroy(self)

	if self._heat_listener_clbk then
		managers.groupai:state():remove_listener( self._heat_listener_clbk )
		self._heat_listener_clbk = nil
	end

	if self._switch_to_not_cool_clbk_id then
		managers.enemy:remove_delayed_clbk( self._switch_to_not_cool_clbk_id )
		self._switch_to_not_cool_clbk_id = nil
	end
end