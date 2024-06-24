-- alert_data:
-- if alert_type ==  "vo_ntl", "vo_cbt", "vo_intimidate", "vo_distress", "bullet", "aggression", "bullet" : { alert_type, epicenter, effective_radius, alert_filter, alerting_unit }
-- if the alert comes from a client human player over network then it looks like this: { "aggression", Vector3, nil, nil, husk_player_unit }
function CopLogicIdle.on_alert( data, alert_data )
	--debug_pause_unit( data.unit, "[CopLogicIdle.on_alert]", data.unit, inspect( alert_data ) )
	local alert_type = alert_data[1]
	local alert_unit = alert_data[5]

	if CopLogicBase._chk_alert_obstructed( data.unit:movement():m_head_pos(), alert_data ) then
		return
	end

	local was_cool = data.cool
	if CopLogicBase.is_alert_aggressive( alert_type ) then
		data.unit:movement():set_cool( false, managers.groupai:state().analyse_giveaway( data.unit:base()._tweak_table, alert_data[5], alert_data ) )
	end

	if alert_unit and alert_unit:in_slot( data.enemy_slotmask ) then
		local att_obj_data, is_new = CopLogicBase.identify_attention_obj_instant( data, alert_unit:key() )

		if not att_obj_data then -- not interested in detecting this attention object
			return
		end

		if alert_type == "bullet" or alert_type == "aggression" or alert_type == "explosion" then
			att_obj_data.alert_t = TimerManager:game():time()
		end

		--[[local action_data
		if is_new and ( not data.char_tweak.allowed_poses or  data.char_tweak.allowed_poses.stand ) and att_obj_data.reaction >= AIAttentionObject.REACT_SURPRISED and data.unit:anim_data().idle and not data.unit:movement():chk_action_forbidden( "walk" ) then
			action_data = { type = "act", body_part = 1, variant = "surprised" }
			data.unit:brain():action_request( action_data )
		end--]] -- PD:TH animations, looks like shit in PD2 so i'm just removing it

		if--[[ not action_data and--]] alert_type == "bullet" and data.logic.should_duck_on_alert( data, alert_data ) then
			--[[action_data = --]]CopLogicAttack._chk_request_action_crouch( data )
		end

		if att_obj_data.criminal_record then
			managers.groupai:state():criminal_spotted( alert_unit )
			if alert_type == "bullet" or alert_type == "aggression" or alert_type == "explosion" then
				managers.groupai:state():report_aggression( alert_unit )
			end
		end
	elseif was_cool and ( alert_type == "footstep" or alert_type == "bullet" or alert_type == "aggression" or alert_type == "explosion" or alert_type == "vo_cbt" or alert_type == "vo_intimidate" or alert_type == "vo_distress" ) then -- friendly unit or civilian in action. switch to not cool
		local attention_obj = alert_unit and alert_unit:brain() and alert_unit:brain()._logic_data.attention_obj
		if attention_obj then
			local att_obj_data, is_new = CopLogicBase.identify_attention_obj_instant( data, attention_obj.u_key )
		end
	end
end