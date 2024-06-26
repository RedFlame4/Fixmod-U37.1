function ExplosionManager:detect_and_give_dmg( params )
	local hit_pos = params.hit_pos
	local slotmask = params.collision_slotmask
	local user_unit = params.user
	local dmg = params.damage
	local player_dmg = params.player_damage or dmg
	local range = params.range
	local ignore_unit = params.ignore_unit
	local curve_pow = params.curve_pow
	local col_ray = params.col_ray
	local alert_filter = params.alert_filter or managers.groupai:state():get_unit_type_filter( "civilians_enemies" )
	local owner = params.owner

	local player = managers.player:player_unit()
	if alive( player ) and player_dmg ~= 0 then
		player:character_damage():damage_explosion( { position = hit_pos, range = range, damage = player_dmg } )
	end

	local bodies = (ignore_unit or World):find_bodies("intersect", "sphere", hit_pos, range, slotmask)
	local alert_unit = user_unit
	if alert_unit and alert_unit:base() and alert_unit:base().thrower_unit then
		alert_unit = alert_unit:base():thrower_unit()
	end

	managers.groupai:state():propagate_alert( { "explosion", hit_pos, 10000, alert_filter, alert_unit } )

	local splinters = { mvector3.copy( hit_pos ) }
	local dirs = { 
		Vector3( range, 0, 0 ),
		Vector3(-range, 0, 0 ),
		Vector3( 0, range, 0 ),
		Vector3( 0,-range, 0 ),
		Vector3( 0, 0, range ),
		Vector3( 0, 0,-range )
	}

	local pos = Vector3()
	for _, dir in ipairs( dirs ) do
		mvector3.set( pos, dir )
		mvector3.add( pos, hit_pos )

		local splinter_ray
		if ignore_unit then
			splinter_ray = World:raycast("ray", hit_pos, pos, "ignore_unit", ignore_unit, "slot_mask", managers.slot:get_mask("world_geometry"))
		else
			splinter_ray = World:raycast("ray", hit_pos, pos, "slot_mask", managers.slot:get_mask("world_geometry"))
		end

		if splinter_ray then
			pos = splinter_ray.position - dir:normalized() * math.min(splinter_ray.distance, 10)
		end

		local near_splinter = false
		for _, s_pos in ipairs( splinters ) do
			if mvector3.distance_sq( pos, s_pos ) < 900 then
				near_splinter = true
				break
			end
		end

		if not near_splinter then
			table.insert( splinters, mvector3.copy( pos ) )
		end
	end

	local count_cops = 0
	local count_gangsters = 0
	local count_civilians = 0
	local count_cop_kills = 0
	local count_gangster_kills = 0
	local count_civilian_kills = 0
	local characters_hit = {}
 	local units_to_push = {}
 	local hit_units = {}
	local type
	for _, hit_body in ipairs( bodies ) do
		local hit_unit = hit_body:unit()
		local hit_unit_key = hit_unit:key()
		local char_dmg_ext = hit_unit:character_damage()
		local apply_char_dmg = char_dmg_ext and char_dmg_ext.damage_explosion and not characters_hit[hit_unit_key]
		local apply_body_dmg = hit_body:extension() and hit_body:extension().damage

		units_to_push[hit_unit_key] = hit_unit

		if apply_char_dmg or apply_body_dmg then -- unit is a character and can take explosion damage, or one of it's bodies can
			local ray_hit = false
			if char_dmg_ext then
				if params.no_raycast_check_characters then
					ray_hit = true
				else
					for _, s_pos in ipairs( splinters ) do
						ray_hit = not World:raycast( "ray", s_pos, hit_body:center_of_mass(), "slot_mask", managers.slot:get_mask("world_geometry"), "report" )
						if ray_hit then
							break
						end
					end
				end

				if ray_hit then
					local hit_unit = hit_body:unit()
					if hit_unit:base() and hit_unit:base()._tweak_table and not hit_unit:character_damage():dead() then
						type = hit_unit:base()._tweak_table

						if CopDamage.is_civilian(type) then
							count_civilians = count_civilians + 1
						elseif CopDamage.is_gangster(type) then
							count_gangsters = count_gangsters + 1
						elseif table.contains(CriminalsManager.character_names(), type) then
						else
							count_cops = count_cops + 1
						end
					end
				end
			else
				ray_hit = true -- no raycasts for non-characters
			end

			if ray_hit then
				hit_units[hit_unit_key] = hit_unit

				local dir = hit_body:center_of_mass()
				local len = mvector3.direction( dir, hit_pos, dir )
				local damage = dmg * math.pow( math.clamp( 1 - len / range, 0, 1 ), curve_pow )
				if apply_body_dmg then
					self:_apply_body_damage( true, hit_body, user_unit, dir, damage )
				end

				damage = math.max( damage, 1 ) -- under 1 damage is generally not allowed

				if apply_char_dmg then
					characters_hit[hit_unit_key] = true

					local dead_before = hit_unit:character_damage():dead()
					local action_data = {
						variant = "explosion",
						damage = damage,
						attacker_unit = user_unit,
						weapon_unit = owner,
						col_ray = self._col_ray or { position = hit_body:position(), ray = dir }
					}

					hit_unit:character_damage():damage_explosion( action_data )

					if not dead_before and hit_unit:base() and hit_unit:base()._tweak_table and hit_unit:character_damage():dead() then
						type = hit_unit:base()._tweak_table

						if CopDamage.is_civilian(type) then
							count_civilian_kills = count_civilian_kills + 1
						elseif CopDamage.is_gangster(type) then
							count_gangster_kills = count_gangster_kills + 1
						elseif table.contains(CriminalsManager.character_names(), type) then
						else
							count_cop_kills = count_cop_kills + 1
						end
					end
				end
			end
		end
	end

	managers.explosion:units_to_push( units_to_push, hit_pos, range )

	if owner then
		managers.statistics:shot_fired({hit = false, weapon_unit = owner})
		for i = 1, count_gangsters + count_cops do
			managers.statistics:shot_fired({
				hit = true,
				weapon_unit = owner,
				skip_bullet_count = true
			})
		end
		local weapon_pass, weapon_type_pass, count_pass, all_pass
		for achievement, achievement_data in pairs(tweak_data.achievement.explosion_achievements) do
			weapon_pass = not achievement_data.weapon or true
			weapon_type_pass = not achievement_data.weapon_type or owner:base() and owner:base().weapon_tweak_data and owner:base():weapon_tweak_data().category == achievement_data.weapon_type
			if achievement_data.count then
				count_pass = (achievement_data.kill and count_cop_kills + count_gangster_kills or count_cops + count_gangsters) >= achievement_data.count
			end
			all_pass = weapon_pass and weapon_type_pass and count_pass
			if all_pass and achievement_data.award then
				managers.achievment:award(achievement_data.award)
			end
		end
	end

	return hit_units, splinters
end

function ExplosionManager:client_damage_and_push( position, normal, user_unit, dmg, range, curve_pow )
	local bodies = World:find_bodies( "intersect", "sphere", position, range, managers.slot:get_mask( "explosion_targets" ) )

	local units_to_push = {}
	for _, hit_body in ipairs( bodies ) do
		local hit_unit = hit_body:unit()
		units_to_push[ hit_body:unit():key() ] = hit_unit

		local apply_dmg = hit_body:extension() and hit_body:extension().damage and hit_unit:id() == -1
		local dir, len, damage
		if apply_dmg then
			dir = hit_body:center_of_mass()
			len = mvector3.direction( dir, position, dir )
			damage = dmg * math.pow( math.clamp( 1 - len / range, 0, 1 ), curve_pow )
			self:_apply_body_damage( false, hit_body, user_unit, dir, damage )
		end
	end

	self:units_to_push( units_to_push, position, range )
end