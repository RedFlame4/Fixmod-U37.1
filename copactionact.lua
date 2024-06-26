Hooks:PreHook(CopActionAct, "init", "promod_init", function(self, action_desc)
	if action_desc.align_sync and action_desc.body_part == 3 then
		action_desc.align_sync = nil -- generic patch for random teleports
	end
end)