function HUDManager:setup_anticipation(total_t)
	local exists = self._anticipation_dialogs and true or false
	self._anticipation_dialogs = {}

	if not exists and total_t == 30 then
		table.insert(self._anticipation_dialogs, {
			time = 30,
			dialog = 2
		})
		table.insert(self._anticipation_dialogs, {
			time = 20,
			dialog = 3
		})
		table.insert(self._anticipation_dialogs, {
			time = 10,
			dialog = 4
		})
	elseif exists and total_t == 30 then
		table.insert(self._anticipation_dialogs, {
			time = 30,
			dialog = 6
		})
		table.insert(self._anticipation_dialogs, {
			time = 20,
			dialog = 7
		})
		table.insert(self._anticipation_dialogs, {
			time = 10,
			dialog = 8
		})
	end
end