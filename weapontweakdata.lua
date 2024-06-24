Hooks:PostHook(WeaponTweakData, "init", "promod_init", function(self)
    -- NPC BERETTA
    self.beretta92_npc.has_suppressor = "suppressed_b"

    -- NPC BENELLI
    self.benelli_npc.sounds.prefix = "benelli_m4_npc" -- actually use benelli sounds

    -- NPC MAC11
    self.mac11_npc.sounds.prefix = "mac10_npc" -- actually use mac11 sounds

	-- NPC MOSCONI
	self.mossberg_npc = clone(self.huntsman_npc) -- huntsman_npc makes far more sense for the weapon

	-- NPC S552
	self.s552_npc.muzzleflash_silenced = "effects/payday2/particles/weapons/9mm_auto_silence" -- chunky suppressor
	self.s552_npc.has_suppressor = "suppressed_c" -- chunky suppressor

	-- PLAYER SAW
	self.saw.sounds.dryfire = nil -- makes no sense for it to play a dryfire sound
end)