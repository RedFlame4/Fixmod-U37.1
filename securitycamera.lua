function SecurityCamera:_upd_detect_attention_objects( t )
	local detected_obj = self._detected_attention_objects
	local my_key = self._u_key
	local my_pos = self._pos
	local my_fwd = self._look_fwd
	
	local det_delay = self._detection_delay
	
	for u_key, attention_info in pairs( detected_obj ) do
		if attention_info.next_verify_t > t then
		else
			attention_info.next_verify_t = t + ( attention_info.identified and attention_info.verified and attention_info.settings.verification_interval * 1.3 or attention_info.settings.verification_interval * 0.3 )
			if not attention_info.identified then
				--print( "checking identification\n", inspect( attention_info ) )
				local noticable
				local angle, dis_multiplier = self:_detection_angle_and_dis_chk( my_pos, my_fwd, attention_info.handler, attention_info.settings, attention_info.handler:get_detection_m_pos() )
				if angle then -- inside FOV
					local attention_pos = attention_info.handler:get_detection_m_pos()
					local vis_ray = self._unit:raycast( "ray", my_pos, attention_pos, "slot_mask", self._visibility_slotmask, "ray_type", "ai_vision" )
					if not vis_ray or vis_ray.unit:key() == u_key then
						noticable = true
					end
				end
				
				local delta_prog
				local dt = t - attention_info.prev_notice_chk_t
				
				if noticable then
					--print( "\nnoticeable" )
					if angle == -1 then -- instant detection
						delta_prog = 1
					else
						local min_delay = det_delay[1]
						local max_delay = det_delay[2]
						local angle_mul_mod = 0.15 * math.min( angle / self._cone_angle, 1 ) -- angle only plays 25% role
						local dis_mul_mod = 0.85 * dis_multiplier
						local notice_delay_mul = (attention_info.settings.notice_delay_mul or 1)
						
						if attention_info.settings.detection and attention_info.settings.detection.delay_mul then
							notice_delay_mul = notice_delay_mul * attention_info.settings.detection.delay_mul
						end
						
						local notice_delay_modified = math.lerp( min_delay * notice_delay_mul, max_delay, dis_mul_mod + angle_mul_mod )
						delta_prog = notice_delay_modified > 0 and dt / notice_delay_modified or 1
						--[[if attention_info.unit == managers.player:player_unit() then
							print( "notice_delay_modified", notice_delay_modified, "max_delay", max_delay, "angle_mul_mod", angle_mul_mod, "dis_mul_mod", dis_mul_mod, "dis_multiplier", dis_multiplier, "angle_mul", angle / self._cone_angle, "dt", dt, "delta_prog", delta_prog )
						end]]
					end
				else
					delta_prog = det_delay[2] > 0 and -dt / det_delay[2] or -1
					--print( "non-noticeable delta_prog", delta_prog )
				end
				
				attention_info.notice_progress = attention_info.notice_progress + delta_prog
				--print( "notice_progress", attention_info.notice_progress, self._unit, attention_info.unit )
				if attention_info.notice_progress > 1 then
					--print( "GAME OVER" )
					attention_info.notice_progress = nil
					attention_info.prev_notice_chk_t = nil
					attention_info.identified = true
					attention_info.release_t = t + attention_info.settings.release_delay
					attention_info.identified_t = t
					noticable = true --identified
					if attention_info.settings.reaction >= AIAttentionObject.REACT_SCARED then
						managers.groupai:state():on_criminal_suspicion_progress( attention_info.unit, self._unit, true )
					end
				elseif attention_info.notice_progress < 0 then
					--print( "LOST" )
					self:_destroy_detected_attention_object_data( attention_info ) -- notice_clbk gets called here
					noticable = false --lost
				else
					--print( "COUNTING" )
					noticable = attention_info.notice_progress
					attention_info.prev_notice_chk_t = t
					if attention_info.settings.reaction >= AIAttentionObject.REACT_SCARED then
						managers.groupai:state():on_criminal_suspicion_progress( attention_info.unit, self._unit, noticable )
					end
				end
				if noticable ~= false and attention_info.settings.notice_clbk then
					--print( "calling notice_clbk:", noticable )
					attention_info.settings.notice_clbk( self._unit, noticable )
				end
			end
			
			if attention_info.identified then
				--print( "checking verification\n", inspect( attention_info ) )
				attention_info.nearly_visible = nil
				local verified, vis_ray
				local attention_pos = attention_info.handler:get_detection_m_pos()
				local dis = mvector3.distance( my_pos, attention_info.m_pos )
				if dis < self._range * 1.2 then -- 20% tolerance
					local in_FOV = self:_detection_angle_chk( my_pos, my_fwd, attention_pos, 0.8 )
					if in_FOV then
						vis_ray = self._unit:raycast( "ray", my_pos, attention_pos, "slot_mask", self._visibility_slotmask, "ray_type", "ai_vision" )
						--print( "[SecurityCamera:_upd_detect_attention_objects] attention vis_ray", vis_ray and vis_ray.unit:name():s() )
						if not vis_ray or vis_ray.unit:key() == u_key then
							verified = true
						end
					end
				end

				attention_info.verified = verified
				attention_info.dis = dis
				
				if verified then
					attention_info.release_t = nil
					attention_info.verified_t = t
					mvector3.set( attention_info.verified_pos, attention_pos )
					attention_info.last_verified_pos = mvector3.copy( attention_pos )
					attention_info.verified_dis = dis
				elseif attention_info.release_t and attention_info.release_t < t then
					self:_destroy_detected_attention_object_data( attention_info )
				else
					attention_info.release_t = attention_info.release_t or t + attention_info.settings.release_delay
				end
			end
		end
	end
end