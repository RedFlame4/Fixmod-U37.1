local mvec3_set = mvector3.set

-- generic vanilla code fix for the function not doing what was expected
local random_orthogonal_orig = mvector3.random_orthogonal
function mvector3.random_orthogonal(vec1, vec2)
	if vec2 then
		mvec3_set(vec1, vec2)
	end
	
	return random_orthogonal_orig(vec1) -- tailcall
end