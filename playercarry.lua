-- Fix harsher detection when standing with a bag
--[[function PlayerCarry:_upd_attention()
	if self._state_data.ducking then
		return PlayerCarry.super._upd_attention(self)
	else
		self._ext_movement:set_attention_settings({
			"pl_friend_combatant_cbt",
			"pl_friend_non_combatant_cbt",
			"pl_foe_combatant_cbt_stand",
			"pl_foe_non_combatant_cbt_stand"
		})
	end
end--]]