function CivilianLogicEscort._begin_advance_action(data, my_data)
	--CopLogicAttack._correct_path_start_pos(data, my_data.advance_path) -- not needed anymore, handled in copactionwalk

	local objective = data.objective
	local haste = objective and objective.haste or "run
	local new_action_data = {
		type = "walk",
		nav_path = my_data.advance_path,
		variant = haste,
		body_part = 2
	}

	if my_data.coarse_path_index >= #my_data.coarse_path - 1 then
		new_action_data.end_rot = objective.rot
	end

	my_data.advancing = data.unit:brain():action_request(new_action_data)

	if my_data.advancing then
		data.brain:rem_pos_rsrv("path")
		my_data.advance_path = nil
	else
		debug_pause("[CivilianLogicEscort._begin_advance_action] failed to start")
	end
end
