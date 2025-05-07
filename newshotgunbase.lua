-- fix range being set incorrectly, reducing suppression and autohit range
Hooks:PostHook(NewShotgunBase, "init", "promod_init", function(self)
	self._range = self._damage_near + self._damage_far -- the max distance before damage hits zero is actually damage_near + damage_far for some reason
end)

local mvec_temp = Vector3()
local mvec_to = Vector3()
local mvec_direction = Vector3()
local mvec_spread_direction = Vector3()
function NewShotgunBase:_fire_raycast( user_unit, from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul, shoot_through_data ) -- ( user_unit, from_pos, direction )
	local result = {}
	local hit_enemies = {}
	local hit_objects = {}
	local col_rays
	if self._alert_events then
		col_rays = {}
	end

	local damage = self:_get_current_damage( dmg_mul )
	local pellet_damage = damage / self._rays
	local autoaim, dodge_enemies = self:check_autoaim( from_pos, direction, self._range )
	local weight = 0.1
	local function hit_enemy(col_ray)
		local unit = col_ray.unit
		if unit:character_damage() then
			local enemy_key = unit:key()
			if not hit_enemies[ enemy_key ] or unit:character_damage().is_head and unit:character_damage():is_head( col_ray.body ) then
				hit_enemies[ enemy_key ] = col_ray
			end
		else
			local add_shoot_through_bullet = self._can_shoot_through_shield or self._can_shoot_through_wall
			if add_shoot_through_bullet then
				hit_objects[unit:key()] = hit_objects[unit:key()] or {}
				table.insert(hit_objects[unit:key()], col_ray)
			else
				-- per-pellet damage, as to prevent the shotgun from exceeding it's base damage since it can hit the same unit more than once
				self._bullet_class:on_collision(col_ray, self._unit, user_unit, self:get_damage_falloff(pellet_damage, col_ray, user_unit))
			end
		end
	end

	local spread = self:_get_spread( user_unit )

	mvector3.set( mvec_direction, direction )

	for _ = 1, shoot_through_data and 1 or self._rays do -- 6 killer rays 
		mvector3.set( mvec_spread_direction, mvec_direction )

		if spread then
			mvector3.spread( mvec_spread_direction, spread * ( spread_mul or 1 ) )
		end

		mvector3.set( mvec_to, mvec_spread_direction )
		mvector3.multiply( mvec_to, self._range ) -- limit ray range to the max distance the shotgun can do damage
		mvector3.add( mvec_to, from_pos )

		local ray_from_unit = shoot_through_data and alive(shoot_through_data.ray_from_unit) and shoot_through_data.ray_from_unit or nil
		local col_ray = (ray_from_unit or World):raycast("ray", from_pos, mvec_to, "slot_mask", self._bullet_slotmask, "ignore_unit", self._setup.ignore_units)
		if col_rays then -- remember all rays. we need them for alert propagation
			if col_ray then
				table.insert( col_rays, col_ray )
			else
				local ray_to = mvector3.copy( mvec_to )
				local spread_direction = mvector3.copy( mvec_spread_direction )
				table.insert( col_rays, { position = ray_to, ray = spread_direction } )
			end
		end

		if self._autoaim and autoaim then
			if col_ray and col_ray.unit:in_slot( managers.slot:get_mask( "enemies" ) ) then
				self._autohit_current = ( self._autohit_current + weight ) / ( 1 + weight )
				hit_enemy( col_ray )
				autoaim = false
			else
				autoaim = false -- only try once
				local autohit = self:check_autoaim( from_pos, direction, self._range )
				if autohit then	--	We missed an autoaim unit
					local autohit_chance = 1 - math.clamp( ( self._autohit_current - self._autohit_data.MIN_RATIO ) / ( self._autohit_data.MAX_RATIO - self._autohit_data.MIN_RATIO ), 0, 1 )
					if autohit_chance > math.random() then
						self._autohit_current = ( self._autohit_current + weight ) / ( 1 + weight )
						hit_enemy( autohit )
					else
						self._autohit_current = self._autohit_current / ( 1 + weight )
					end
				elseif col_ray then
					hit_enemy( col_ray )
				end
			end
		elseif col_ray then
			hit_enemy( col_ray )
		end
	end

	for _, col_rays in pairs(hit_objects) do
		local center_ray = col_rays[1]
		if #col_rays > 1 then
			mvector3.set_static(mvec_temp, center_ray)

			for _, col_ray in ipairs(col_rays) do
				mvector3.add(mvec_temp, col_ray.position)
			end

			mvector3.divide(mvec_temp, #col_rays)

			local closest_dist_sq = mvector3.distance_sq(mvec_temp, center_ray.position)
			local dist_sq
			for _, col_ray in ipairs(col_rays) do
				dist_sq = mvector3.distance_sq(mvec_temp, col_ray.position)

				if closest_dist_sq > dist_sq then
					closest_dist_sq = dist_sq
					center_ray = col_ray
				end
			end
		end

		NewShotgunBase.super._fire_raycast(self, user_unit, from_pos, center_ray.ray, dmg_mul, shoot_player, 0, autohit_mul, suppr_mul, shoot_through_data)
	end

	for _, col_ray in pairs( hit_enemies ) do
		local damage = self:get_damage_falloff(damage, col_ray, user_unit)
		if damage > 0 then
			local result
			local add_shoot_through_bullet = self._can_shoot_through_shield or self._can_shoot_through_enemy or self._can_shoot_through_wall
			if add_shoot_through_bullet then
				result = NewShotgunBase.super._fire_raycast(self, user_unit, from_pos, col_ray.ray, dmg_mul, shoot_player, 0, autohit_mul, suppr_mul, shoot_through_data)
			else
				result = self._bullet_class:on_collision(col_ray, self._unit, user_unit, damage)
			end

			if result and result.type == "death" then
				managers.game_play_central:do_shotgun_push(col_ray.unit, col_ray.position, col_ray.ray, col_ray.distance)
			end
		end
	end

	if dodge_enemies and self._suppression then
		for enemy_data, dis_error in pairs( dodge_enemies ) do
			if not enemy_data.unit:movement():cool() then -- fix suppression with shotguns in stealth
				enemy_data.unit:character_damage():build_suppression( suppr_mul * dis_error * self._suppression, self._panic_suppression_chance )
			end
		end
	end

	result.hit_enemy = next( hit_enemies ) and true or false

	if self._alert_events then
		result.rays = #col_rays	> 0 and col_rays
	end

	if not shoot_through_data then
		managers.statistics:shot_fired({
			hit = false,
			weapon_unit = self._unit
		})
	end

	for _ in pairs(hit_enemies) do
		managers.statistics:shot_fired({
			hit = true,
			weapon_unit = self._unit,
			skip_bullet_count = true
		})
	end

	return result
end