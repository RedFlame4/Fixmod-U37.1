function MoneyManager:get_buy_mask_slot_price()
	local multiplier = 1
	multiplier = multiplier * managers.player:upgrade_value("player", "buy_cost_multiplier", 1)
	multiplier = multiplier * managers.player:upgrade_value("player", "crime_net_deal", 1)

    local total_price = self:get_tweak_value("money_manager", "unlock_new_mask_slot_value") * multiplier
	return math.round(total_price)
end

function MoneyManager:get_buy_weapon_slot_price()
	local multiplier = 1
	multiplier = multiplier * managers.player:upgrade_value("player", "buy_cost_multiplier", 1)
	multiplier = multiplier * managers.player:upgrade_value("player", "crime_net_deal", 1)

    local total_price = self:get_tweak_value("money_manager", "unlock_new_weapon_slot_value") * multiplier
	return math.round(total_price)
end
