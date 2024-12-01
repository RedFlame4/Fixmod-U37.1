-- TODO: a group may spawn with units that can't actually path to criminals due to navlink access level

local math_lerp = math.lerp
local math_max = math.max
local math_min = math.min
local math_random = math.random

local mvec3_cpy = mvector3.copy
local mvec3_dis = mvector3.distance
local mvec3_dis_sq = mvector3.distance_sq

local next_g = next
local ipairs_g = ipairs
local pairs_g = pairs

local table_insert = table.insert
local table_remove = table.remove

local type_g = type

Hooks:PostHook(GroupAIStateBesiege, "init", "promod_init", function(self)
	self._graph_distance_cache = {}
end)

function GroupAIStateBesiege:_queue_police_upd_task()
	self._police_upd_task_queued = true
	managers.enemy:queue_task("GroupAIStateBesiege._upd_police_activity", GroupAIStateBesiege._upd_police_activity, self, self._t + 2)
end

-- Causes more problems than it's worth
--[[function GroupAIStateBesiege:assign_enemy_to_group_ai( unit, team_id )
	local area = self:get_area_from_nav_seg_id(unit:movement():nav_tracker():nav_segment())
	local group = self:_create_group({type = "custom", size = 1})
	group.team = self._teams[team_id]

	local objective = unit:brain():objective()
	local grp_objective
	if objective then
		grp_objective = {
			type = "custom",
			area = objective.area or objective.nav_seg and self:get_area_from_nav_seg_id(objective.nav_seg) or area
		}
		objective.grp_objective = grp_objective
	else
		grp_objective = {
			type = "custom",
			area = area
		}
	end

	grp_objective.moving_out = false

	group.objective = grp_objective
	group.has_spawned = true

	self:_add_group_member( group, unit:key() )
	self:set_enemy_assigned( area, unit:key() )
end--]]

GroupAIStateBesiege.on_enemy_unregistered = nil

function GroupAIStateBesiege:_upd_police_activity()
	self._police_upd_task_queued = false

	if self._ai_enabled then
		self:_upd_SO()
		self:_upd_grp_SO()

		if self._enemy_weapons_hot then
			self:_claculate_drama_value()
			self:_upd_group_spawning() -- Re-ordered so spawned groups get an objective immediately instead of on the next update
			self:_begin_new_tasks() -- Re-ordered because otherwise group objectives will use last update assault info
			self:_upd_regroup_task()
			self:_upd_reenforce_tasks()
			self:_upd_recon_tasks()
			self:_upd_assault_task()
			self:_upd_groups() -- Re-ordered so spawned groups get an objective immediately instead of on the next update
		end
	end

	self:_queue_police_upd_task()
end

-- Fix reinforce delay being applied wrongly
function GroupAIStateBesiege:_begin_reenforce_task(reenforce_area)
	local new_task = {
		target_area = reenforce_area,
		start_t = self._t,
		use_spawn_event = true
	}
	table_insert(self._task_data.reenforce.tasks, new_task)

	self._task_data.reenforce.active = true
end

-- Search from spawn to player, not vice versa as there might be one-way links due to navlinks
function GroupAIStateBesiege:_find_spawn_group_near_area(target_area, allowed_groups, target_pos, max_dis, verify_clbk)
	target_pos = target_pos or target_area.pos

	local t = self._t
	local valid_spawn_groups = {}
	local valid_spawn_group_distances = {}

	for _, area in pairs_g(self._area_data) do -- ugly, but no easy and clean way to do it
		local spawn_groups = area.spawn_groups
		if spawn_groups then
			for i = 1, #spawn_groups do
				local spawn_group = spawn_groups[i]
				if spawn_group.delay_t <= t and (not verify_clbk or verify_clbk(spawn_group)) then
					local dis_id = spawn_group.nav_seg .. "-" .. target_area.pos_nav_seg -- we cannot presume the opposite is also valid like vanilla as navlinks can cause this to not be the case
					local my_dis = self._graph_distance_cache[dis_id]
					if not my_dis then
						local path = managers.navigation:search_coarse({
							access_pos = "swat",
							from_seg = spawn_group.nav_seg,
							to_seg = target_area.pos_nav_seg,
							id = dis_id
						})

						if path and #path >= 2 then
							local dis = 0
							local current = spawn_group.pos
							for j = 2, #path do
								local nxt = path[j][2]
								if current and nxt then
									dis = dis + mvec3_dis(current, nxt)
								end

								current = nxt
							end

							my_dis = dis
							self._graph_distance_cache[dis_id] = dis
						end
					end

					if my_dis and (not max_dis or my_dis < max_dis) then
						table_insert(valid_spawn_groups, spawn_group)
						table_insert(valid_spawn_group_distances, my_dis * my_dis)
					end
				end
			end
		end
	end

	if not next( valid_spawn_groups ) then
		--print( "no distances", inspect( valid_spawn_groups ), inspect( valid_spawn_group_distances ) )
		return
	end

	local total_weight = 0
	local candidate_groups = {}

	-- calculate unnormalized weights
	local dis_limit = 10000 * 10000 -- minimum weight at 100m
	for i, dis in ipairs( valid_spawn_group_distances ) do
		local my_wgt = valid_spawn_group_distances[ i ]
		my_wgt = math.lerp( 1, 0.2, math.min( 1, my_wgt / dis_limit ) )
		local my_spawn_group = valid_spawn_groups[ i ]
		local my_group_types = my_spawn_group.mission_element:spawn_groups()
		for _, group_type in ipairs( my_group_types ) do
			if tweak_data.group_ai.enemy_spawn_groups[ group_type ] then
				local cat_weights = allowed_groups[ group_type ]
				if cat_weights then
					local cat_weight = self:_get_difficulty_dependent_value( cat_weights )
					local mod_weight = my_wgt * cat_weight
					table.insert( candidate_groups, { group = my_spawn_group, group_type = group_type, wght = mod_weight } )
					total_weight = total_weight + mod_weight
				end
			else
				debug_pause( "[GroupAIStateBesiege:_find_spawn_group_near_area] inexistent spawn_group:", group_type, ". element id:", my_spawn_group.mission_element._id )
			end
		end
	end

	if total_weight == 0 then
		return
	end

	local rand_wgt = total_weight * math.random()
	--print( "\nrand_wgt", rand_wgt )
	local best_grp, best_grp_type
	for i, candidate in ipairs( candidate_groups ) do
		rand_wgt = rand_wgt - candidate.wght
		--print( "checking candidate", i, candidate.wght, rand_wgt )
		if rand_wgt <= 0 then
			best_grp = candidate.group
			best_grp_type = candidate.group_type
			break
		end
	end

	return best_grp, best_grp_type
end

function GroupAIStateBesiege:_upd_group_spawning()
	local spawn_task = self._spawning_groups[1]
	if not spawn_task then
		return
	end

	local nr_units_spawned = 0
	local produce_data = {
		name = true,
		spawn_ai = {}
	}
	local group_ai_tweak = tweak_data.group_ai
	local spawn_points = spawn_task.spawn_group.spawn_pts
	local function _try_spawn_unit(u_type_name, spawn_entry)
		if nr_units_spawned >= GroupAIStateBesiege._MAX_SIMULTANEOUS_SPAWNS then
			return
		end

		local hopeless = true
		for _, sp_data in ipairs(spawn_points) do
			local category = group_ai_tweak.unit_categories[u_type_name]
			if (sp_data.accessibility == "any" or category.access[sp_data.accessibility]) and (not sp_data.amount or sp_data.amount > 0) and sp_data.mission_element:enabled() then
				hopeless = false
				if self._t > sp_data.delay_t then
					produce_data.name = table.random(category.units)

					local spawned_unit = sp_data.mission_element:produce(produce_data)
					local u_key = spawned_unit:key()
					local objective
					if spawn_task.objective then
						objective = self.clone_objective(spawn_task.objective)
					else
						objective = spawn_task.group.objective.element:get_random_SO(spawned_unit)
						if not objective then
							spawned_unit:set_slot(0)
							return true
						end

						objective.grp_objective = spawn_task.group.objective
					end

					local u_data = self._police[u_key]
					self:set_enemy_assigned(objective.area, u_key)

					if spawn_entry.tactics then
						u_data.tactics = spawn_entry.tactics
						u_data.tactics_map = {}

						for _, tactic_name in ipairs(u_data.tactics) do
							u_data.tactics_map[tactic_name] = true
						end
					end

					spawned_unit:brain():set_spawn_entry(spawn_entry, u_data.tactics_map)

					u_data.rank = spawn_entry.rank

					self:_add_group_member(spawn_task.group, u_key)

					if spawned_unit:brain():is_available_for_assignment(objective) then
						if objective.element then
							objective.element:clbk_objective_administered(spawned_unit)
						end

						spawned_unit:brain():set_objective(objective)
					else
						spawned_unit:brain():set_followup_objective(objective)
					end

					nr_units_spawned = nr_units_spawned + 1

					if spawn_task.ai_task then
						spawn_task.ai_task.force_spawned = spawn_task.ai_task.force_spawned + 1
					end

					sp_data.delay_t = self._t + sp_data.interval

					if sp_data.amount then
						sp_data.amount = sp_data.amount - 1
					end

					return true
				end
			end
		end

		if hopeless then
			debug_pause("[GroupAIStateBesiege:_upd_group_spawning] spawn group", spawn_task.spawn_group.id, "failed to spawn unit", u_type_name)
			return true
		end
	end

	local complete = true
	for u_type_name, spawn_info in pairs(spawn_task.units_remaining) do
		if not group_ai_tweak.unit_categories[u_type_name].access.acrobatic then
			for i = spawn_info.amount, 1, -1 do
				if _try_spawn_unit(u_type_name, spawn_info.spawn_entry) then
					spawn_info.amount = spawn_info.amount - 1
				else
					complete = false
					break
				end
			end
		end
	end

	for u_type_name, spawn_info in pairs(spawn_task.units_remaining) do
		for i = spawn_info.amount, 1, -1 do
			if _try_spawn_unit(u_type_name, spawn_info.spawn_entry) then
				spawn_info.amount = spawn_info.amount - 1
			else
				complete = false
				break
			end
		end
	end

	if complete then
		spawn_task.group.has_spawned = true
		table.remove(self._spawning_groups, 1)

		if spawn_task.group.size <= 0 then
			self._groups[spawn_task.group.id] = nil
		end
	end
end

function GroupAIStateBesiege:_set_assault_objective_to_group(group, phase)
	if not group.has_spawned then
		return
	end

	local phase_is_anticipation = phase == "anticipation"
	local current_objective = group.objective
	local approach, open_fire, push, pull_back, charge = nil
	local obstructed_area = self:_chk_group_areas_tresspassed(group)
	local group_leader_u_key, group_leader_u_data = self._determine_group_leader(group.units)
	local tactics_map = {}

	if group_leader_u_data and group_leader_u_data.tactics then
		for _, tactic_name in ipairs(group_leader_u_data.tactics) do
			tactics_map[tactic_name] = true
		end

		if current_objective.tactic and not tactics_map[current_objective.tactic] then
			current_objective.tactic = nil
		end

		for i_tactic, tactic_name in ipairs(group_leader_u_data.tactics) do
			if tactic_name == "deathguard" and not phase_is_anticipation then
				if current_objective.tactic == tactic_name then
					for u_key, u_data in pairs(self._char_criminals) do
						if u_data.status and current_objective.follow_unit == u_data.unit then
							local crim_nav_seg = u_data.tracker:nav_segment()

							if current_objective.area.nav_segs[crim_nav_seg] then
								return
							end
						end
					end
				end

				local closest_crim_u_data, closest_crim_dis_sq = nil
				for u_key, u_data in pairs(self._char_criminals) do
					if u_data.status then
						local closest_u_id, closest_u_data, closest_u_dis_sq = self._get_closest_group_unit_to_pos(u_data.m_pos, group.units)

						if closest_u_dis_sq and (not closest_crim_dis_sq or closest_u_dis_sq < closest_crim_dis_sq) then
							closest_crim_u_data = u_data
							closest_crim_dis_sq = closest_u_dis_sq
						end
					end
				end

				if closest_crim_u_data then
					local search_params = {
						id = "GroupAI_deathguard",
						from_tracker = group_leader_u_data.unit:movement():nav_tracker(),
						to_tracker = closest_crim_u_data.tracker,
						access_pos = self._get_group_acces_mask(group)
					}
					local coarse_path = managers.navigation:search_coarse(search_params)
					if coarse_path then
						local grp_objective = {
							distance = 800,
							type = "assault_area",
							attitude = "engage",
							tactic = "deathguard",
							moving_in = true,
							follow_unit = closest_crim_u_data.unit,
							area = self:get_area_from_nav_seg_id(coarse_path[#coarse_path][1]),
							coarse_path = coarse_path
						}
						group.is_chasing = true

						self:_set_objective_to_enemy_group(group, grp_objective)
						self:_voice_deathguard_start(group)

						return
					end
				end
			elseif tactic_name == "charge" and not current_objective.moving_out and group.in_place_t and (self._t - group.in_place_t > 15 or self._t - group.in_place_t > 4 and self._drama_data.amount <= tweak_data.drama.low) and next(current_objective.area.criminal.units) and group.is_chasing and not current_objective.charge then
				charge = true
			end
		end
	end

	local objective_area = current_objective.area
	if obstructed_area then
		if phase_is_anticipation then
			pull_back = true
		elseif current_objective.moving_out then
			if not current_objective.open_fire then
				open_fire = true
				objective_area = obstructed_area
			end
		elseif not current_objective.pushed or charge and not current_objective.charge then
			push = true
		end
	elseif not current_objective.moving_out then
		local has_criminals_close = nil
		for area_id, neighbour_area in pairs(current_objective.area.neighbours) do
			if next(neighbour_area.criminal.units) then
				has_criminals_close = true

				break
			end
		end

		if charge then
			push = true
		elseif not has_criminals_close or not group.in_place_t then
			approach = true
		elseif not phase_is_anticipation then
			if not current_objective.open_fire then
				open_fire = true
			elseif group.is_chasing or not tactics_map.ranged_fire or self._t - group.in_place_t > 15 then
				push = true
			end
		elseif current_objective.open_fire then
			pull_back = true
		end
	elseif not current_objective.open_fire then
		local obstructed_path_index = self:_chk_coarse_path_obstructed(group)
		if obstructed_path_index then
			objective_area = self:get_area_from_nav_seg_id(current_objective.coarse_path[math.max(obstructed_path_index - 1, 1)][1])
			open_fire = true
		end
	end

	if open_fire then
		local grp_objective = {
			attitude = "engage",
			pose = "stand",
			type = "assault_area",
			stance = "hos",
			open_fire = true,
			tactic = current_objective.tactic,
			area = objective_area,
			coarse_path = {
				{
					objective_area.pos_nav_seg,
					mvector3.copy(objective_area.pos)
				}
			}
		}

		self:_set_objective_to_enemy_group(group, grp_objective)
		self:_voice_open_fire_start(group)
	elseif approach or push then
		local assault_area, alternate_assault_area, alternate_assault_area_from, assault_path, alternate_assault_path = nil
		local to_search_areas = {
			objective_area
		}
		local found_areas = {
			[objective_area] = objective_area
		}

		repeat
			local search_area = table.remove(to_search_areas, 1)
			if next(search_area.criminal.units) then
				local assault_from_here = true
				if not push and tactics_map.flank then
					local assault_from_area = found_areas[search_area]
					if assault_from_area ~= objective_area then
						assault_from_here = false

						if not alternate_assault_area or math_random() < 0.5 then
							local new_alternate_assault_path = managers.navigation:search_coarse({
								id = "GroupAI_assault",
								from_seg = current_objective.area.pos_nav_seg,
								to_seg = assault_from_area.pos_nav_seg,
								access_pos = self._get_group_acces_mask(group),
								verify_clbk = callback(self, self, "is_nav_seg_safe"),
							})
							if new_alternate_assault_path then
								alternate_assault_path = new_alternate_assault_path
								alternate_assault_area = search_area
								alternate_assault_area_from = assault_from_area
							end
						end

						found_areas[search_area] = nil
					end
				end

				if assault_from_here then
					assault_path = managers.navigation:search_coarse({
						id = "GroupAI_assault",
						from_seg = current_objective.area.pos_nav_seg,
						to_seg = search_area.pos_nav_seg,
						access_pos = self._get_group_acces_mask(group),
						verify_clbk = callback(self, self, "is_nav_seg_safe"),
					})

					if assault_path then
						assault_area = search_area

						break
					end
				end
			else
				for other_area_id, other_area in pairs(search_area.neighbours) do
					if not found_areas[other_area] then
						table_insert(to_search_areas, other_area)

						found_areas[other_area] = search_area
					end
				end
			end
		until #to_search_areas == 0

		if not assault_area and alternate_assault_area then
			assault_area = alternate_assault_area
			found_areas[assault_area] = alternate_assault_area_from
			assault_path = alternate_assault_path
		end

		if assault_area and assault_path then
			self:_merge_coarse_path_by_area(assault_path)

			local used_grenade = nil
			if push then
				local detonate_pos
				if charge then
					local criminal_positions = {}
					for c_key, c_data in pairs(assault_area.criminal.units) do
						if not self._criminals[c_key].is_deployable then
							table_insert(criminal_positions, c_data.unit:movement():m_pos())
						end
					end

					detonate_pos = table.random(criminal_positions)
				end

				local first_chk = math_random() < 0.5 and self._chk_group_use_flash_grenade or self._chk_group_use_smoke_grenade
				local second_chk = first_chk == self._chk_group_use_flash_grenade and self._chk_group_use_smoke_grenade or self._chk_group_use_flash_grenade
				used_grenade = first_chk(self, group, self._task_data.assault, detonate_pos) or second_chk(self, group, self._task_data.assault, detonate_pos)

				self:_voice_move_in_start(group)
			else
				assault_area = found_areas[assault_area]

				-- Flank is already calculated to one navseg before target segment
				if #assault_path > 2 and assault_area.nav_segs[assault_path[#assault_path - 1][1]] then
					table_remove(assault_path)
				end
			end

			if not push or used_grenade or group.in_place_t and self._t - group.in_place_t > 30 then -- 30s timeout so groups that can't throw nades eventually push
				local grp_objective = {
					type = "assault_area",
					stance = "hos",
					area = assault_area,
					coarse_path = assault_path,
					pose = push and "crouch" or "stand",
					attitude = push and "engage" or "avoid",
					moving_in = push or nil,
					open_fire = push or nil,
					pushed = push or nil,
					charge = charge,
					interrupt_dis = charge and 0 or nil
				}
				group.is_chasing = group.is_chasing or push

				self:_set_objective_to_enemy_group(group, grp_objective)
			end
		end
	elseif pull_back then
		local retreat_area
		for u_key, u_data in pairs(group.units) do
			local nav_seg_id = u_data.tracker:nav_segment()
			if current_objective.area.nav_segs[nav_seg_id] then
				retreat_area = current_objective.area

				break
			end

			if self:is_nav_seg_safe(nav_seg_id) then
				retreat_area = self:get_area_from_nav_seg_id(nav_seg_id)

				break
			end
		end

		if not retreat_area and current_objective.coarse_path then
			local forwardmost_i_nav_point = self:_get_group_forwardmost_coarse_path_index(group)
			if forwardmost_i_nav_point then
				retreat_area = self:get_area_from_nav_seg_id(current_objective.coarse_path[forwardmost_i_nav_point][1])
			end
		end

		if retreat_area then
			local new_grp_objective = {
				attitude = "avoid",
				stance = "hos",
				pose = "crouch",
				type = "assault_area",
				area = retreat_area,
				coarse_path = {
					{
						retreat_area.pos_nav_seg,
						mvector3.copy(retreat_area.pos)
					}
				}
			}
			group.is_chasing = nil

			self:_set_objective_to_enemy_group(group, new_grp_objective)

			return
		end
	end
end

function GroupAIStateBesiege:_chk_group_use_smoke_grenade( group, task_data, detonate_pos )
	if task_data.use_smoke and not self:is_smoke_grenade_active() then
		local shooter_pos, shooter_u_data
		local duration = tweak_data.group_ai.smoke_grenade_lifetime

		for u_key, u_data in pairs( group.units ) do
			if u_data.tactics_map and u_data.tactics_map.smoke_grenade then
				if detonate_pos then
					shooter_pos = mvector3.copy( u_data.m_pos )
					shooter_u_data = u_data -- doesn't really matter who throws it since you can't tell anyway
				else
					local nav_seg_id = u_data.tracker:nav_segment()
					local nav_seg = managers.navigation._nav_segments[ nav_seg_id ]
					for neighbour_nav_seg_id, door_list in pairs( nav_seg.neighbours ) do -- iterate through the neighbour nav_segments of the cop
						local area = self:get_area_from_nav_seg_id(neighbour_nav_seg_id)
						if task_data.target_areas[1].nav_segs[ neighbour_nav_seg_id ] or next(area.criminal.units) then -- it has our primary target area as neighbour
							local random_door_id = door_list[ math.random( #door_list ) ]
							if type( random_door_id ) == "number" then
								detonate_pos = managers.navigation._room_doors[ random_door_id ].center
							else
								detonate_pos = random_door_id:script_data().element:nav_link_end_pos()
							end

							shooter_pos = mvector3.copy( u_data.m_pos )
							shooter_u_data = u_data
							break -- stop iterating doors
						end
					end
				end

				if detonate_pos and shooter_u_data then
					self:detonate_smoke_grenade( detonate_pos, shooter_pos, duration, false )
					task_data.use_smoke_timer = self._t + math.lerp( tweak_data.group_ai.smoke_and_flash_grenade_timeout[1], tweak_data.group_ai.smoke_and_flash_grenade_timeout[2], math.rand(0, 1)^0.5 )
					task_data.use_smoke = false

					if shooter_u_data.char_tweak.chatter.smoke and not shooter_u_data.unit:sound():speaking( self._t ) then
						self:chk_say_enemy_chatter( shooter_u_data.unit, shooter_u_data.m_pos, "smoke" )
					end

					return true
				end
			end
		end
	end
end

function GroupAIStateBesiege:_chk_group_use_flash_grenade( group, task_data, detonate_pos )
	if task_data.use_smoke and not self:is_smoke_grenade_active() then
		local shooter_pos, shooter_u_data
		local duration = tweak_data.group_ai.flash_grenade_lifetime

		for u_key, u_data in pairs( group.units ) do
			if u_data.tactics_map and u_data.tactics_map.flash_grenade then
				if detonate_pos then
					shooter_pos = mvector3.copy( u_data.m_pos )
					shooter_u_data = u_data -- doesn't really matter who throws it since you can't tell anyway
				else
					local nav_seg_id = u_data.tracker:nav_segment()
					local nav_seg = managers.navigation._nav_segments[ nav_seg_id ]
					for neighbour_nav_seg_id, door_list in pairs( nav_seg.neighbours ) do -- iterate through the neighbour nav_segments of the cop
						if task_data.target_areas[1].nav_segs[ neighbour_nav_seg_id ] then -- it has our primary target area as neighbour
							local random_door_id = door_list[ math.random( #door_list ) ]
							if type( random_door_id ) == "number" then
								detonate_pos = managers.navigation._room_doors[ random_door_id ].center
							else
								detonate_pos = random_door_id:script_data().element:nav_link_end_pos()
							end
							shooter_pos = mvector3.copy( u_data.m_pos )
							shooter_u_data = u_data
							break -- stop iterating doors
						end
					end
				end

				if detonate_pos and shooter_u_data then
					self:detonate_smoke_grenade( detonate_pos, shooter_pos, duration, true )
					task_data.use_smoke_timer = self._t + math.lerp( tweak_data.group_ai.smoke_and_flash_grenade_timeout[1], tweak_data.group_ai.smoke_and_flash_grenade_timeout[2], math.random()^0.5 )
					task_data.use_smoke = false

					if shooter_u_data.char_tweak.chatter.flash_grenade and not shooter_u_data.unit:sound():speaking( self._t ) then
						self:chk_say_enemy_chatter( shooter_u_data.unit, shooter_u_data.m_pos, "flash_grenade" )
					end

					return true
				end
			end
		end
	end
end

function GroupAIStateBesiege:_chk_group_areas_tresspassed(group)
	for _, u_data in pairs_g(group.units) do
		for _, area in pairs_g(self:get_areas_from_nav_seg_id(u_data.tracker:nav_segment())) do
			if not self:is_area_safe(area) then
				return area
			end
		end
	end
end

function GroupAIStateBesiege:_chk_coarse_path_obstructed(group)
	local current_objective = group.objective
	if not current_objective.coarse_path then
		return
	end

	local forwardmost_i_nav_point = self:_get_group_forwardmost_coarse_path_index(group)
	if forwardmost_i_nav_point then
		if current_objective.coarse_path[forwardmost_i_nav_point + 1] and not self:is_nav_seg_safe(current_objective.coarse_path[forwardmost_i_nav_point + 1][1]) then
			return forwardmost_i_nav_point + 1
		end
	end
end