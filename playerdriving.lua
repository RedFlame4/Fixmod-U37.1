function PlayerDriving:update(t, dt)
	if self._vehicle == nil then
		print("[DRIVING] No in a vehicle")

		return
	elseif not self._vehicle:is_active() then
		print("[DRIVING] The vehicle is not active")

		return
	end

	if self._controller == nil then
		print("[DRIVING] No controller available")

		return
	end

	self:_update_input(dt)

	local input = self:_get_input(t, dt)

	self:_calculate_standard_variables(t, dt)
	self:_update_ground_ray()
	self:_update_fwd_ray()
	self:_upd_nav_data()
	self:_update_hud(t, input)
	self:_update_action_timers(t, input)
	self:_check_action_exit_vehicle(t, input)

	if self._seat.driving then
		self:_update_check_actions_driver(t, dt, input)
	elseif self._seat.allow_shooting or self._stance == PlayerDriving.STANCE_SHOOTING then
		self:_update_check_actions_passenger(t, dt, input)
	else
		self:_update_check_actions_passenger_no_shoot(t, dt, input)
	end
end