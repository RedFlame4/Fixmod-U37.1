-- standing is handled in ActionSpooc now
-- this is both unneeded for flying strikes and causes sync trouble doing it here
function SpoocLogicAttack._chk_request_action_spooc_attack(data, my_data, flying_strike)
	local new_action = {type = "idle", body_part = 3}
	data.unit:brain():action_request(new_action)

	local new_action_data = {
		type = "spooc",
		body_part = 1,
		flying_strike = flying_strike
	}

	if flying_strike then
		new_action_data.blocks = {
			walk = -1,
			turn = -1,
			act = -1,
			idle = -1,
			light_hurt = -1,
			hurt = -1,
			heavy_hurt = -1,
			expl_hurt = -1,
			fire_hurt = -1,
			taser_tased = -1
		}
	end

	return data.unit:brain():action_request(new_action_data)
end