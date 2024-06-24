local init_orig = CopActionDodge.init
function CopActionDodge:init(action_desc, ...)
	if Network:is_server() then
		action_desc.shoot_accuracy = (action_desc.shoot_accuracy or 1) * 10
	end

	if init_orig(self, action_desc, ...) then
		action_desc.shoot_accuracy = action_desc.shoot_accuracy / 10

		CopActionAct._create_blocks_table(self, action_desc.blocks)
		return true
	end
end

function CopActionDodge:chk_block(action_type, t)
	if action_type == "death" then
		return false
	end

	return CopActionAct.chk_block(self, action_type, t)
end