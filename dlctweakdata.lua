Hooks:PostHook(DLCTweakData, "init", "fixmod_init", function(self)
	self.pd2_clan.verified = true -- check is broken now so just give it by default
end)