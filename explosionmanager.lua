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
	local push_units = true
	local alert_radius = params.alert_radius or 10000

	if params.push_units ~= nil then
		push_units = params.push_units
	end

	local player = managers.player:player_unit()
	if alive( player ) and player_dmg ~= 0 then
		player:character_damage():damage_explosion({
			position = hit_pos,
			range = range,
			damage = player_dmg,
			variant = "explosion",
			ignite_character = params.ignite_character
		})
	end

	local bodies = (ignore_unit or World):find_bodies("intersect", "sphere", hit_pos, range, slotmask)
	local alert_unit = user_unit
	if alert_unit and alert_unit:base() and alert_unit:base().thrower_unit then
		alert_unit = alert_unit:base():thrower_unit()
	end

	managers.groupai:state():propagate_alert( { "explosion", hit_pos, alert_radius, alert_filter, alert_unit } )

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
			splinter_ray = World:raycast("ray", hit_pos, pos, "ignore_unit", ignore_unit, "slot_mask", slotmask)
		else
			splinter_ray = World:raycast("ray", hit_pos, pos, "slot_mask", slotmask)
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
		local char_dead = char_dmg_ext and char_dmg_ext:dead()
		local apply_char_dmg = char_dmg_ext and not char_dead and char_dmg_ext.damage_explosion and not characters_hit[hit_unit_key]
		local apply_body_dmg = hit_body:extension() and hit_body:extension().damage

		units_to_push[hit_unit_key] = hit_unit

		-- unit is a character and can take explosion damage, or one of it's bodies can, or it's a bag that can explode
		-- bags previously required a dynamic() check on the body which catches tons of other unneeded things
		if apply_char_dmg or apply_body_dmg or hit_unit:carry_data() and hit_unit:carry_data():can_explode() then
			local ray_hit = false
			if char_dmg_ext and not char_dead then
				if params.no_raycast_check_characters then
					ray_hit = true
				else
					for _, s_pos in ipairs( splinters ) do
						ray_hit = not World:raycast( "ray", s_pos, hit_body:center_of_mass(), "slot_mask", slotmask, "ignore_unit", {
							hit_body:unit(),
							ignore_unit
						}, "report" )

						if ray_hit then
							break
						end
					end
				end

				if ray_hit and hit_unit:base() and hit_unit:base()._tweak_table and not hit_unit:character_damage():dead() then
					type = hit_unit:base()._tweak_table

					if CopDamage.is_civilian(type) then
						count_civilians = count_civilians + 1
					elseif CopDamage.is_gangster(type) then
						count_gangsters = count_gangsters + 1
					elseif not table.contains(CriminalsManager.character_names(), type) then
						count_cops = count_cops + 1
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

				if apply_char_dmg then
					damage = math.max( damage, 1 ) -- under 1 damage is generally not allowed

					characters_hit[hit_unit_key] = true

					local action_data = {
						variant = "explosion",
						damage = damage,
						attacker_unit = user_unit,
						weapon_unit = owner,
						col_ray = self._col_ray or { position = hit_body:position(), ray = dir },
						ignite_character = params.ignite_character
					}

					hit_unit:character_damage():damage_explosion( action_data )

					if hit_unit:base() and hit_unit:base()._tweak_table and hit_unit:character_damage():dead() then
						type = hit_unit:base()._tweak_table

						if CopDamage.is_civilian(type) then
							count_civilian_kills = count_civilian_kills + 1
						elseif CopDamage.is_gangster(type) then
							count_gangster_kills = count_gangster_kills + 1
						elseif not table.contains(CriminalsManager.character_names(), type) then
							count_cop_kills = count_cop_kills + 1
						end
					end
				end
			end
		end
	end

	if push_units and push_units == true then
		managers.explosion:units_to_push(units_to_push, hit_pos, range)
	end

	local results = {}
	if owner then
		results.count_cops = count_cops
		results.count_gangsters = count_gangsters
		results.count_civilians = count_civilians
		results.count_cop_kills = count_cop_kills
		results.count_gangster_kills = count_gangster_kills
		results.count_civilian_kills = count_civilian_kills
	end

	return hit_units, splinters, results
end

function ExplosionManager:client_damage_and_push( position, normal, user_unit, dmg, range, curve_pow )
	local bodies = World:find_bodies( "intersect", "sphere", position, range, managers.slot:get_mask( "explosion_targets" ) )

	local units_to_push = {}
	for _, hit_body in ipairs( bodies ) do
		local hit_unit = hit_body:unit()
		units_to_push[ hit_unit:key() ] = hit_unit

		local apply_dmg = hit_body:extension() and hit_body:extension().damage and hit_unit:id() == -1
		if apply_dmg then
			local dir = hit_body:center_of_mass()
			local len = mvector3.direction( dir, position, dir )
			local damage = dmg * math.pow( math.clamp( 1 - len / range, 0, 1 ), curve_pow )

			self:_apply_body_damage( false, hit_body, user_unit, dir, damage )
		end
	end

	self:units_to_push( units_to_push, position, range )
end