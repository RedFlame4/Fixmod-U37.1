Hooks:PostHook(WeaponTweakData, "init", "promod_init", function(self)
	self.beretta92_npc.has_suppressor = "suppressed_b"

	self.benelli_npc.sounds.prefix = "benelli_m4_npc" -- actually use benelli sounds

	self.mac11_npc.sounds.prefix = "mac10_npc" -- actually use mac11 sounds

	self.mossberg_npc = clone(self.huntsman_npc) -- huntsman_npc makes far more sense for the weapon

	self.s552_npc.muzzleflash_silenced = "effects/payday2/particles/weapons/9mm_auto_silence" -- chunky suppressor
	self.s552_npc.has_suppressor = "suppressed_c" -- chunky suppressor

	local clip_upgrade_block = {
		weapon = {
			"clip_ammo_increase"
		}
	}

	-- these aren't mag-fed weapons
	self.r870.upgrade_blocks = clip_upgrade_block
	self.serbu.upgrade_blocks = clip_upgrade_block
	self.striker.upgrade_blocks = clip_upgrade_block
	self.benelli.upgrade_blocks = clip_upgrade_block
	self.ksg.upgrade_blocks = clip_upgrade_block

	self.saw.sounds.dryfire = nil -- makes no sense for it to play a dryfire sound
end)