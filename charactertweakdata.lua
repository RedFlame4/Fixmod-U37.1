Hooks:PostHook(CharacterTweakData, "init", "fixmod_init", function(self)
	self.gensec.suppression = self.presets.suppression.easy -- fix GenSec red suppression
	self.fbi_swat.suppression = self.presets.suppression.hard_agg -- either use hard_agg like blue swats or make blue swats use hard_def
	self.city_swat.suppression = self.presets.suppression.hard_agg -- either use hard_agg like blue swats or make blue swats use hard_def
end)

local _presets_orig = CharacterTweakData._presets
function CharacterTweakData:_presets(...)
	local presets = _presets_orig(self, ...)

	self:_process_weapon_usage_table(presets.weapon.deathwish) -- not normalised otherwise

	presets.enemy_chatter.swat.flash_grenade = true -- this line is fully implemented but never plays cause no enemies have this chatter set

	return presets
end

Hooks:PostHook(CharacterTweakData, "_set_normal", "fixmod_set_normal", function(self)
	self:_process_weapon_usage_table(self.hector_boss.weapon) -- not normalised otherwise
end)

Hooks:PostHook(CharacterTweakData, "_set_hard", "fixmod_set_hard", function(self)
	self:_process_weapon_usage_table(self.hector_boss.weapon) -- not normalised otherwise
end)

Hooks:PostHook(CharacterTweakData, "_set_overkill", "fixmod_set_overkill", function(self)
	self:_process_weapon_usage_table(self.hector_boss.weapon) -- not normalised otherwise
end)

Hooks:PostHook(CharacterTweakData, "_set_overkill_145", "fixmod_set_overkill_145", function(self)
   self:_process_weapon_usage_table(self.hector_boss.weapon) -- not normalised otherwise
end)

Hooks:PostHook(CharacterTweakData, "_set_overkill_290", "fixmod_set_overkill_290", function(self)
	 -- none of these are normalised
	self:_process_weapon_usage_table(self.hector_boss.weapon)
	self:_process_weapon_usage_table(self.tank.weapon)
	self:_process_weapon_usage_table(self.shield.weapon)
	self:_process_weapon_usage_table(self.taser.weapon)

	-- calculated off fbi_swat health normally which might be unintended
	-- fbi_swat head health is 32.5 for reference
	-- 147.692307692 head health when broken
	-- 80 head health when fixed
	-- self.city_swat.headshot_dmg_mul = self.city_swat.HEALTH_INIT / 8
end)
