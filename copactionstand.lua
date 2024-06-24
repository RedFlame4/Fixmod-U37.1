local idstr_base = Idstring("base")

function CopActionStand:init(action_desc, common_data)
	self._ext_movement = common_data.ext_movement

	if common_data.active_actions[2] and common_data.active_actions[2]._nav_link then
		return
	end

	local ext_anim = common_data.ext_anim
	self._ext_anim = ext_anim

	local enter_t = nil
	if ext_anim.move then
		local walk_anim_length = nil
		if ext_anim.run_start_turn then
			walk_anim_length = common_data.ext_movement._actions.walk._walk_anim_lengths.stand[common_data.stance.name].run_start_turn[ext_anim.move_side]
		elseif ext_anim.run_start then
			walk_anim_length = common_data.ext_movement._actions.walk._walk_anim_lengths.stand[common_data.stance.name].run_start[ext_anim.move_side]
		elseif ext_anim.run_stop then
			walk_anim_length = common_data.ext_movement._actions.walk._walk_anim_lengths.stand[common_data.stance.name].run_stop[ext_anim.move_side]
		else
			walk_anim_length = common_data.ext_movement._actions.walk._walk_anim_lengths
			walk_anim_length = walk_anim_length and walk_anim_length["stand"][common_data.stance.name]
			walk_anim_length = walk_anim_length and walk_anim_length[ext_anim.run and "run" or "walk"]
			walk_anim_length = walk_anim_length and walk_anim_length[ext_anim.move_side] or 29
		end

		enter_t = common_data.machine:segment_relative_time(idstr_base) * walk_anim_length
	end

	if common_data.ext_movement:play_redirect("stand", enter_t) then
		if not action_desc.no_sync and Network:is_server() then -- why this isn't a thing normally is beyond me
			common_data.ext_network:send("set_pose", 1)
		end

		self._ext_movement:enable_update()

		return true
	end
end