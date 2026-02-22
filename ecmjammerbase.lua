-- Fix ECM jammer duration upgrades not syncing properly
local idstr_ecm_jammer = Idstring("units/payday2/equipment/gen_equipment_jammer/gen_equipment_jammer")
function ECMJammerBase.spawn(pos, rot, battery_life_upgrade_lvl, owner, peer_id)
	local unit = World:spawn_unit(idstr_ecm_jammer, pos, rot)

    -- HACK! can't mess with network_settings while maintaining vanilla compatibility though
	local sync_level = 0
    if battery_life_upgrade_lvl > 1 then
        sync_level = battery_life_upgrade_lvl > tweak_data.upgrades.values.ecm_jammer.duration_multiplier[1] and 2 or 1
    end

	managers.network:session():send_to_peers_synched("sync_equipment_setup", unit, sync_level, peer_id or 0)

	unit:base():setup(battery_life_upgrade_lvl, owner)
	return unit
end

Hooks:PreHook(ECMJammerBase, "sync_setup", "fixmod_sync_setup", function(self, upgrade_lvl)
    local battery_life = tweak_data.upgrades.ecm_jammer_base_battery_life
    if upgrade_lvl >= 1 then
        battery_life = battery_life * tweak_data.upgrades.values.ecm_jammer.duration_multiplier[1]
        battery_life = upgrade_lvl >= 2 and battery_life * tweak_data.upgrades.values.ecm_jammer.duration_multiplier_2[1] or battery_life
    end

	self._max_battery_life = battery_life
	self._battery_life = battery_life
end)