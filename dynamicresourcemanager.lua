Hooks:PostHook(DynamicResourceManager, "init", "promod_init", function(self)
	if PackageManager:has(Idstring("unit"), Idstring("units/payday2/weapons/wpn_npc_sawnoff_shotgun/wpn_npc_sawnoff_shotgun")) then
		self:load(Idstring("bnk"), Idstring("soundbanks/weapon_huntsman"), self.DYN_RESOURCES_PACKAGE) -- needed for npc mosconi to have sounds since the unit doesn't load the required soundbank
	end
end)