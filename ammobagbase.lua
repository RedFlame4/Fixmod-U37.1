function AmmoBagBase:_set_empty()
	self._empty = true

	if Network:is_server() or self._unit:id() == -1 then
		self._unit:set_slot(0)
	else
		-- clients don't have the authority to remove network synced units
		-- also patches the infinite corpse/smoke bug with ammo bags
		self._unit:interaction():set_active(false)
		self._unit:set_enabled(false)
	end
end