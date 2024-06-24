Hooks:PostHook(AttentionTweakData, "_init_player", "promod_init_player", function(self)
	-- Consistency with the crouching preset
	self.settings.pl_foe_combatant_cbt_stand.verification_interval = 0.1
	-- Fix the attention preset used when carrying a bag in stealth
	self.settings.pl_foe_non_combatant_cbt_stand.relation = nil
	self.settings.pl_foe_non_combatant_cbt_stand.verification_interval = 0.1
end)