function CopDamage._type_gangster(type)
	return type == "gangster" or type == "biker_escape" or type == "mobster" or type == "mobster_boss"
end

CopDamage.is_civilian = CopDamage.is_civilian or CopDamage._type_civilian
CopDamage.is_gangster = CopDamage.is_gangster or CopDamage._type_gangster