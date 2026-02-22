-- Fix "X has revived X" message not displaying for other players when a client revives
function ReviveInteractionExt:interact(reviving_unit)
	if reviving_unit and reviving_unit == managers.player:player_unit() then
		if not self:can_interact(reviving_unit) then
			return
		end

		if self._tweak_data.equipment_consume then
			managers.player:remove_special(self._tweak_data.special_equipment)
		end

		if self._tweak_data.sound_event then
			reviving_unit:sound():play(self._tweak_data.sound_event)
		end

		ReviveInteractionExt.super.interact(self, reviving_unit)
		
		managers.achievment:set_script_data("player_reviving", false)
		managers.player:activate_temporary_upgrade("temporary", "combat_medic_damage_multiplier")
		managers.player:activate_temporary_upgrade("temporary", "combat_medic_enter_steelsight_speed_multiplier")
	end

	self:remove_interact()

	if self._unit:damage() and self._unit:damage():has_sequence("interact") then
		self._unit:damage():run_sequence_simple("interact")
	end

	if self._unit:base().is_husk_player then
		local revive_rpc_params = {
			"revive_player",
			managers.player:upgrade_value("player", "revive_health_boost", 0)
		}
		managers.statistics:revived({npc = false, reviving_unit = reviving_unit})
		self._unit:network():send_to_unit(revive_rpc_params)
	else
		self._unit:character_damage():revive(reviving_unit)
		managers.statistics:revived({npc = true, reviving_unit = reviving_unit})
	end

	if reviving_unit:in_slot(managers.slot:get_mask("criminals")) then
		local hint = self.tweak_data == "revive" and 2 or 3
		managers.network:session():send_to_peers_synched("sync_teammate_helped_hint", hint, self._unit, reviving_unit)
		managers.trade:sync_teammate_helped_hint(self._unit, reviving_unit, hint)
	end

	if managers.blackmarket:equipped_mask().mask_id == tweak_data.achievement.witch_doctor.mask then
		managers.achievment:award_progress(tweak_data.achievement.witch_doctor.stat)
	end
end

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