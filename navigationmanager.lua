local mvec3_dis = mvector3.distance

function NavigationManager:_execute_coarce_search(search_data)
    local end_i_seg = search_data.end_i_seg
    local target_areas = managers.groupai:state():get_areas_from_nav_seg_id(end_i_seg)

	local i = 0
	while true do
		if i == 500 then
			debug_pause("[NavigationManager:_execute_coarce_search] endless loop", inspect(search_data))
			return false
		else
			i = i + 1
		end

		local next_search_seg = search_data.seg_to_search[#search_data.seg_to_search]
		local next_search_i_seg = next_search_seg.i_seg

		table.remove(search_data.seg_to_search)

		local all_nav_segments = self._nav_segments
		local neighbours = all_nav_segments[next_search_i_seg].neighbours
		if neighbours[end_i_seg] then
			local entry_found
			for _, i_door in ipairs(neighbours[end_i_seg]) do
				if type(i_door) == "number" then
					entry_found = true
					break
				elseif TimerManager:game():time() > i_door:delay_time() and i_door:check_access(search_data.access_pos, search_data.access_neg) then
                    entry_found = true
                    break
				end
			end

			if entry_found then
				local i_seg = next_search_i_seg
				local this_seg = next_search_seg
				local path = {
					{
						end_i_seg,
						search_data.to_pos
					}
				}

				table.insert(path, 1, {
					next_search_i_seg,
					next_search_seg.pos
				})

				local searched = search_data.seg_searched
				while this_seg.from do
					i_seg = this_seg.from
					this_seg = searched[i_seg]
					table.insert(path, 1, {
						i_seg,
						this_seg.pos
					})
				end

				return path
			end
		end

		local to_pos = search_data.to_pos
		local new_segments = self:_sort_nav_segs_after_pos(to_pos, target_areas, next_search_i_seg, search_data.discovered_seg, search_data.verify_clbk, search_data.access_pos, search_data.access_neg)
		if new_segments then
			local to_search = search_data.seg_to_search
			for i_seg, seg_data in pairs(new_segments) do
				local new_seg_weight = seg_data.weight
				local search_index = #to_search
				while search_index > 0 and new_seg_weight > to_search[search_index].weight do
					search_index = search_index - 1
				end

				table.insert(to_search, search_index + 1, seg_data)
			end
		end

		local nr_seg_to_search = #search_data.seg_to_search
		if nr_seg_to_search == 0 then
			return false
		else
			search_data.seg_searched[next_search_i_seg] = next_search_seg
		end
	end
end

function NavigationManager:_sort_nav_segs_after_pos(to_pos, target_areas, i_seg, ignore_seg, verify_clbk, access_pos, access_neg)
	local all_segs = self._nav_segments
	local all_doors = self._room_doors
	local seg = all_segs[i_seg]
	local neighbours = seg.neighbours
	local found_segs = nil

	for neighbour_seg_id, door_list in pairs(neighbours) do
        local skip_verify = not verify_clbk or table.find_value(target_areas, function(area)
            return area.nav_segs[neighbour_seg_id]
        end)

		if not ignore_seg[neighbour_seg_id] and not all_segs[neighbour_seg_id].disabled and (skip_verify or verify_clbk(neighbour_seg_id)) then
			for _, i_door in ipairs(door_list) do
				if type(i_door) == "number" then
					local door = all_doors[i_door]
					local door_pos = door.center
					local weight = mvec3_dis(door_pos, to_pos)

					if found_segs then
						if found_segs[neighbour_seg_id] then
							if weight < found_segs[neighbour_seg_id].weight then
								found_segs[neighbour_seg_id] = {
									weight = weight,
									from = i_seg,
									i_seg = neighbour_seg_id,
									pos = door_pos
								}
							end
						else
							found_segs[neighbour_seg_id] = {
								weight = weight,
								from = i_seg,
								i_seg = neighbour_seg_id,
								pos = door_pos
							}
							ignore_seg[neighbour_seg_id] = true
						end
					else
						found_segs = {
							[neighbour_seg_id] = {
								weight = weight,
								from = i_seg,
								i_seg = neighbour_seg_id,
								pos = door_pos
							}
						}
						ignore_seg[neighbour_seg_id] = true
					end
				elseif not alive(i_door) then
					debug_pause("[NavigationManager:_sort_nav_segs_after_pos] dead nav_link! between NavSegments", i_seg, "-", neighbour_seg_id)
				elseif not i_door:is_obstructed() and i_door:delay_time() < TimerManager:game():time() and i_door:check_access(access_pos, access_neg) then
					local end_pos = i_door:script_data().element:nav_link_end_pos()
					local my_weight = mvec3_dis(end_pos, to_pos)

					if found_segs then
						if found_segs[neighbour_seg_id] then
							if my_weight < found_segs[neighbour_seg_id].weight then
								found_segs[neighbour_seg_id] = {
									weight = my_weight,
									from = i_seg,
									i_seg = neighbour_seg_id,
									pos = end_pos
								}
							end
						else
							found_segs[neighbour_seg_id] = {
								weight = my_weight,
								from = i_seg,
								i_seg = neighbour_seg_id,
								pos = end_pos
							}
							ignore_seg[neighbour_seg_id] = true
						end
					else
						found_segs = {
							[neighbour_seg_id] = {
								weight = my_weight,
								from = i_seg,
								i_seg = neighbour_seg_id,
								pos = end_pos
							}
						}
						ignore_seg[neighbour_seg_id] = true
					end
				end
			end
		end
	end

	return found_segs
end
