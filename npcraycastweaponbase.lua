Hooks:PostHook(NPCRaycastWeaponBase, "init", "promod_init", function(self)
	-- actually use suppressed muzzleflash if applicable
	local weap_tweak = self:weapon_tweak_data()
	if weap_tweak.has_suppressor then
		self._sound_fire:set_switch("suppressed", weap_tweak.has_suppressor)

		self._muzzle_effect = Idstring(weap_tweak.muzzleflash_silenced or "effects/payday2/particles/weapons/9mm_auto_silence")
		self._muzzle_effect_table.effect = self._muzzle_effect
	end
end)