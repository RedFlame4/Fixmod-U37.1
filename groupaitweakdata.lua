Hooks:PostHook(GroupAITweakData, "_init_unit_categories", "promod_init_unit_categories", function(self, difficulty_index)
	local access_type_walk_only = {
		walk = true
	}
	local access_type_all = {
		acrobatic = true,
		walk = true
	}

	-- Unit category fixes
	self.unit_categories.CS_cop_C45_R870.unit_types.america = {
		Idstring("units/payday2/characters/ene_cop_1/ene_cop_1"),
		Idstring("units/payday2/characters/ene_cop_2/ene_cop_2"),
		Idstring("units/payday2/characters/ene_cop_4/ene_cop_4")
	}
	self.unit_categories.CS_cop_stealth_MP5.unit_types.america = {
		Idstring("units/payday2/characters/ene_cop_3/ene_cop_3") -- cop HRT, not a random bronco blue
	}
	self.unit_categories.CS_cop_MP5_R870 = {
		unit_types = {
			america = {
				Idstring("units/payday2/characters/ene_cop_3/ene_cop_3"),
				Idstring("units/payday2/characters/ene_cop_4/ene_cop_4")
			},
			russia = {
				Idstring("units/pd2_dlc_mad/characters/ene_akan_cs_cop_akmsu_smg/ene_akan_cs_cop_akmsu_smg"),
				Idstring("units/pd2_dlc_mad/characters/ene_akan_cs_cop_r870/ene_akan_cs_cop_r870")
			}
		},
		access = access_type_walk_only
	}

	if difficulty_index >= 6 then
		self.unit_categories.FBI_swat_M4.unit_types.america = {
			Idstring("units/payday2/characters/ene_city_swat_1/ene_city_swat_1"), -- rifle
			Idstring("units/payday2/characters/ene_city_swat_3/ene_city_swat_3") -- ump
		}
		self.unit_categories.FBI_swat_R870.unit_types.america = {
			Idstring("units/payday2/characters/ene_city_swat_2/ene_city_swat_2") -- benelli
		}
	end

	self.unit_categories.CS_heavy_M4_w.unit_types = self.unit_categories.CS_heavy_M4.unit_types -- ensure it's always consistent with acrobatic
	self.unit_categories.FBI_heavy_G36_w.unit_types = self.unit_categories.FBI_heavy_G36.unit_types -- ensure it's always consistent with acrobatic
end)

Hooks:PostHook(GroupAITweakData, "_init_enemy_spawn_groups", "promod_init_enemy_spawn_groups", function(self, difficulty_index)
	self.enemy_spawn_groups.CS_defend_a = {
		amount = { 3, 4 },
		spawn = {
			{ unit = "CS_cop_MP5_R870", freq = 1, tactics = self._tactics.CS_cop, rank = 1 }
		}
	}
	self.enemy_spawn_groups.FBI_defend_a = {
		amount = { 3, 3 },
		spawn = {
			{ unit = "FBI_suit_C45_M4", freq = 1, amount_min = 1, tactics = self._tactics.FBI_suit, rank = 2 },
			{ unit = "CS_cop_MP5_R870", freq = 1, tactics = self._tactics.FBI_suit, rank = 1 }
		}
	}

	if difficulty_index < 6 then
		self.enemy_spawn_groups.FBI_tanks = {
			amount = { 3, 4 },
			spawn = {
				{ unit = "FBI_tank", freq = 1, amount_min = 1, amount_max = 1, tactics = self._tactics.FBI_tank, rank = 1 }, -- actually guarantee there's a bulldozer and allow the possibility for two like CS_tanks
				{ unit = "FBI_shield", freq = 0.5, amount_min = 1, amount_max = 2, tactics = self._tactics.FBI_shield_flank, rank = 3 },
				{ unit = "FBI_heavy_G36_w", freq = 0.75, amount_min = 1, tactics = self._tactics.FBI_heavy_flank, rank = 1 }
			}
		}
	else
		self.enemy_spawn_groups.CS_tazers = {
			amount = { 4, 4 },
			spawn = {
				{unit = "CS_tazer", freq = 1, amount_min = 3, tactics = self._tactics.CS_tazer, rank = 1},
				{unit = "FBI_shield", freq = 1, amount_min = 2, amount_max = 3, tactics = self._tactics.FBI_shield, rank = 3},
				{unit = "FBI_heavy_G36", freq = 1, amount_max = 2, tactics = self._tactics.FBI_swat_rifle, rank = 1},
			}
		}
	end
end)

--[[Hooks:PostHook(GroupAITweakData, "_init_task_data", "promod_init_task_data", function(self, difficulty_index, difficulty)
	-- Scripted spawns assigned to groupai use custom
	self.besiege.assault.groups.custom = {0, 0, 0}
	self.besiege.recon.groups.custom = {0, 0, 0}
end)--]]