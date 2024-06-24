-- Fix dozer kill taunt playing after the dozer died
function PlayerDamage:clbk_kill_taunt( attack_data )
	if alive(attack_data.attacker_unit) and not attack_data.attacker_unit:character_damage():dead() then
		attack_data.attacker_unit:sound():say("post_kill_taunt")
	end

	self._kill_taunt_clbk_id = nil
end