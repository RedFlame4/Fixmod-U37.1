local mvec3_add = mvector3.add
local mvec3_dot = mvector3.dot
local mvec3_mul = mvector3.multiply
local mvec3_norm = mvector3.normalize
local mvec3_rand_orthogonal = mvector3.random_orthogonal
local mvec3_set = mvector3.set
local mvec3_set_z = mvector3.set_z

function CivilianLogicFlee._find_hide_cover( data )
	local my_data = data.internal_data
	my_data.cover_search_task_key = nil
	
	if data.unit:anim_data().dont_flee then
		return
	end
	
	local avoid_pos
	if my_data.avoid_pos then
		avoid_pos = my_data.avoid_pos
	elseif data.attention_obj and data.attention_obj.reaction >= AIAttentionObject.REACT_SCARED then
		avoid_pos = data.attention_obj.m_pos
	else
		local closest_crim, closest_crim_dis
		for u_key, att_data in pairs( data.detected_attention_objects ) do
			if not closest_crim_dis or closest_crim_dis > att_data.dis then
				closest_crim = att_data
				closest_crim_dis = att_data.dis
			end
		end

		if closest_crim then
			avoid_pos = closest_crim.m_pos
		else
			avoid_pos = Vector3()
			mvec3_rand_orthogonal( avoid_pos, math.UP )
			mvec3_mul( avoid_pos, 100 )
			mvec3_add( data.m_pos, 100 )
		end
	end
	
	if my_data.best_cover then
		local best_cover_vec = avoid_pos - my_data.best_cover[1][1]
		-- Why isn't this done to begin with???
		mvec3_set_z(best_cover_vec, 0)
		mvec3_norm(best_cover_vec)
		
		if mvec3_dot( best_cover_vec, my_data.best_cover[1][2] ) > 0.7 then
			-- present cover was good enough
			return
		end
	end

	local cover = managers.navigation:find_cover_away_from_pos( data.m_pos, avoid_pos, my_data.panic_area.nav_segs )
	if cover then
		if not data.unit:anim_data().panic then
			local action_data = { type = "act", body_part = 1, variant = "panic", clamp_to_graph = true }
			data.unit:brain():action_request( action_data )
		end
		CivilianLogicFlee._cancel_pathing( data, my_data )
		CopLogicAttack._set_best_cover( data, my_data, { cover } )
		data.unit:brain():set_update_enabled_state( true )
		CopLogicBase._reset_attention( data )
	elseif ( data.unit:anim_data().react or data.unit:anim_data().halt ) then
		local action_data = { type = "act", body_part = 1, variant = "panic", clamp_to_graph = true }
		data.unit:brain():action_request( action_data )
		data.unit:sound():say( "a02x_any", true )
		
		if data.unit:unit_data().mission_element then
			data.unit:unit_data().mission_element:event( "panic", data.unit )
		end
		
		CopLogicBase._reset_attention( data )
		
		if not managers.groupai:state():enemy_weapons_hot() then
			local alert = { "vo_distress", data.unit:movement():m_head_pos(), 200, data.SO_access, data.unit }
			managers.groupai:state():propagate_alert( alert )
		end
	end
end