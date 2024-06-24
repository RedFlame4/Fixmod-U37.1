Hooks:PreHook(CopBrain, "set_active", "promod_set_active", function(self, state)
	if not state and self._current_logic_name ~= "inactive" and self._logic_data.is_converted then
		self._attention_handler:override_attention("enemy_team_cbt", nil)
	end
end)

function CopBrain:_chk_use_cover_grenade( unit )
	if not Network:is_server() or not self._logic_data.char_tweak.dodge_with_grenade or not self._logic_data.attention_obj then
		return 
	end
	
	local check_f = self._logic_data.char_tweak.dodge_with_grenade.check
	local t = TimerManager:game():time()
	if check_f and ( not self._next_cover_grenade_chk_t or self._next_cover_grenade_chk_t < t ) then
		local result, next_t = check_f( t, self._nr_flashbang_covers_used or 0 )
		self._next_cover_grenade_chk_t = next_t
		if not result then
			return
		end
	end
	
	local grenade_was_used
	if self._logic_data.attention_obj.dis > 1000 or not self._logic_data.char_tweak.dodge_with_grenade.flash then
		if self._logic_data.char_tweak.dodge_with_grenade.smoke and not managers.groupai:state():is_smoke_grenade_active() then
			local duration = self._logic_data.char_tweak.dodge_with_grenade.smoke.duration
			managers.groupai:state():detonate_smoke_grenade( self._logic_data.m_pos + math.UP * 10, self._unit:movement():m_head_pos(), math.lerp( duration[1], duration[2], math.random() ), false )
			grenade_was_used = true
		end
	elseif self._logic_data.char_tweak.dodge_with_grenade.flash then
		local duration = self._logic_data.char_tweak.dodge_with_grenade.flash.duration
		managers.groupai:state():detonate_smoke_grenade (self._logic_data.m_pos + math.UP * 10, self._unit:movement():m_head_pos(), math.lerp( duration[1], duration[2], math.random() ), true )
		grenade_was_used = true
	end
	
	if grenade_was_used then
		self._nr_flashbang_covers_used = ( self._nr_flashbang_covers_used or 0 ) + 1
	end
end

function CopBrain:on_suppressed(state)
	self._logic_data.is_suppressed = state or nil

	if self._current_logic.on_suppressed_state then
		self._current_logic.on_suppressed_state(self._logic_data)

		if state and self._logic_data.char_tweak.chatter.suppress then
			self._unit:sound():say("hlp", true)
		end
	end
end