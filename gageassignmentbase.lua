function GageAssignmentBase:delete_unit()
	if alive(self._unit) then
		if Network:is_server() or self._unit:id() == -1 then
			self._unit:set_slot(0)
		else
			-- clients don't have the authority to remove network synced units
			self:set_active(false)

			if self._unit:interaction() then
				self._unit:interaction():set_active(false)
			end

			self._unit:set_enabled(false)
		end
	end
end