-- I am server and a client wants me to verify that he is allowed to interact
function CarryInteractionExt:sync_interacted(peer, player, status, skip_alive_check)
	player = player or managers.network:game():member(peer:id()):unit()
	if peer and not managers.player:register_carry(peer:id(), self._unit:carry_data() and self._unit:carry_data():carry_id()) then
		return
	end

	if self._unit:damage():has_sequence("interact") then
		self._unit:damage():run_sequence_simple("interact", {unit = player})
	end

	if self._unit:damage():has_sequence("load") then
		self._unit:damage():run_sequence_simple("load", {unit = player})
	end

	if self._global_event then
		managers.mission:call_global_event(self._global_event, player)
	end

	if Network:is_server() then
		if self._remove_on_interact then
			if self._unit == managers.interaction:active_object() then
				self:interact_interupt(managers.player:player_unit(), false)
			end
			self:remove_interact()
			self:set_active(false, true)
			if alive(player) then
				self._unit:carry_data():trigger_load(player)
			end
			self._unit:set_slot(0)
		end
		if peer then
			managers.player:set_carry_approved(peer)
		end
	elseif self._remove_on_interact then
		self._unit:set_enabled(false) -- hide the bag until the host despawns it so it doesn't stick around for a split second after pickup
	end
end