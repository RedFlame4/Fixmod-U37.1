-- Fix shoot action sync not properly ending shoot actions when playing as client
function UnitNetworkHandler:action_aim_state(unit, state)
    if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
        return
    end

    if state then
        unit:movement():action_request({
            block_type = "action",
            body_part = 3,
            type = "shoot"
        })
    else
        unit:movement():sync_action_aim_end()
    end
end