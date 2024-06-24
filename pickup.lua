function Pickup:delete_unit()
	if Network:is_server() or self._unit:id() == -1 then
		World:delete_unit(self._unit)
	else
		-- clients don't have the authority to remove network synced units
		self:set_active(false)

		if self._unit:interaction() then
			self._unit:interaction():set_active(false)
		end

		self._unit:set_enabled(false)
	end
end