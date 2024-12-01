local math_lerp = math.lerp
local math_min = math.min
local math_random = math.random

local table_remove = table.remove

-- Fix cloaker spawn noise for the host
local _process_recurring_grp_SO_orig = GroupAIStateBase._process_recurring_grp_SO
function GroupAIStateBase:_process_recurring_grp_SO(...)
	if _process_recurring_grp_SO_orig(self, ...) then
		managers.hud:post_event("cloaker_spawn")
		return true
	end
end

Hooks:PostHook(GroupAIStateBase, "on_enemy_unregistered", "REAI_on_enemy_unregistered", function(self, unit)
	if self._is_server then
		self:set_enemy_assigned(nil, unit:key())

		local objective = unit:brain():objective()
		local fail_clbk = objective and objective.fail_clbk
		if fail_clbk then
			objective.fail_clbk = nil

			fail_clbk(unit)
		end
	end
end)

-- Fix team AI spamming combat chatter
function GroupAIStateBase:chk_say_teamAI_combat_chatter(unit)
    if not self:is_detection_persistent() then
        return
    end

    local frequency_lerp = self._drama_data.amount
	local t = self._t
    if t < self._teamAI_last_combat_chatter_t + math_lerp(5, 0.5, frequency_lerp) then
        return
    end

	self._teamAI_last_combat_chatter_t = t

    if math_lerp(0.01, 0.1, math_min(frequency_lerp ^ 2, 1)) < math_random() then
        return
    end

    unit:sound():say("g90", true, true)
end

function GroupAIStateBase:is_nav_seg_safe(nav_seg)
	for _, criminal_data in pairs(self._char_criminals) do
		if criminal_data.tracker:nav_segment() == nav_seg then -- so coarse paths don't fail if they have to go through 2 navsegments that are part of the same area, with criminals inside
			return false
		end
	end

	return true
end

-- Last area is never set in vanilla so this doesn't do anything
-- Removes entries in a coarse path sharing an area
function GroupAIStateBase:_merge_coarse_path_by_area(coarse_path)
	local i_nav_seg = #coarse_path
	local last_area = nil

	while i_nav_seg > 0 and #coarse_path > 2 do
		local area = self:get_area_from_nav_seg_id(coarse_path[i_nav_seg][1])

		if last_area and last_area == area then
			table_remove(coarse_path, i_nav_seg) -- Duplicate entry, remove from the coarse path
		else
			last_area = area -- Normally the vanilla game will not set last_area to the previous area, rendering this function useless
		end

		i_nav_seg = i_nav_seg - 1
	end
end