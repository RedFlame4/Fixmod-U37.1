local action_complete_clbk_orig = CopLogicSniper.action_complete_clbk
function CopLogicSniper.action_complete_clbk(data, action, ...)
	local action_type = action:type()
	local my_data = data.internal_data
	if action_type ~= "walk" then
		return action_complete_clbk_orig(data, action, ...)
	end

	-- my_data.advacing and checking for the presence of the expired function instead of whether it actually expired??
	my_data.advancing = nil

	if action:expired() then
		my_data.reposition = nil
	end
end