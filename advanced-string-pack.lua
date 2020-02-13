local old_pack, old_unpack = string.pack, string.unpack
local pack, unpack

local function skip_node(fmt, pos)
	if fmt:find("^%}", pos) then
		error("skip fail")
	end
	local deep = 1
	while (pos <= #fmt and deep > 0) do
		local _, new_pos = fmt:find("[{,}()[%]]", pos)
		if new_pos then
			if fmt:find("^[})%]]", new_pos) then
				deep = deep - 1
				
			elseif fmt:find("^[{[(]", new_pos) then
				deep = deep + 1
				
			elseif fmt:find("^,", new_pos) and deep == 1 then
				return new_pos + 1
				
			end
			
			pos = new_pos + 1
		else
			return #fmt + 1
		end
	end
	return pos
end

local function skip_spaces(fmt, pos)
	if fmt:find("^%s", pos) then
		local _, pos = fmt:find("^%s+", pos)
		return pos + 1
	else
		return pos
	end
end

local function check_key(data_key, fmt_key, index)
	if not data_key then
		return true, index + 1
		
	elseif not fmt_key then
		return data_key == index, index + 1
		
	elseif fmt_key == "*" then
		return true, index + 1

	elseif data_key == fmt_key then
		return true, index + 1
		
	elseif type(data_key) == "number" and tonumber(fmt_key) then
		index = tonumber(fmt_key)
		return data_key == index, index + 1
		
	end
	
	return false, index + 1
end

local function unpack_node(fmt, data, i, fmt_index, stack, data_key, count, tree)
	local index = 1
	local skip_rest = (count == 0)
	local key_found = false
	local value
	
	repeat
		if not skip_rest then
			local fmt_key = fmt:match("^([^:,(){}[%]]+):", fmt_index)
			
			if fmt_key then
				fmt_index = fmt_index + #fmt_key + 1
			end
			
			key_found, index = check_key(data_key, fmt_key, index)
		end
		
		local new_fmt_index
				
		if skip_rest or not key_found then
			new_fmt_index = skip_node(fmt, fmt_index)
		else
			if tree then
				if not count then
					local new_stack
					new_fmt_index, new_stack, i, value = unpack(fmt, data, i, fmt_index, tree)
					table.insert(stack, new_stack)
				else
					local stack_array = {}
				
					for _ = 1, count do
						local new_stack
						new_fmt_index, new_stack, i, value = unpack(fmt, data, i, fmt_index, tree)
						table.insert(stack_array, new_stack)
					end
					
					table.insert(stack, stack_array)
				end
			else
				for _ = 1, (count or 1) do
					local new_stack
					new_fmt_index, new_stack, i, value = unpack(fmt, data, i, fmt_index, tree)
					table.move(new_stack, 1, #new_stack, #stack + 1, stack)
				end
			end
			
			skip_rest = true
		end
		fmt_index = new_fmt_index
	until not fmt:find("^,", fmt_index - 1)
	
	if tree and not key_found then
		table.insert(stack, {})
	end

	return i, fmt_index, value
end

local pack_reg = "^[!0-9<>=xX bBhHlLjJTiIfdnczs]+"
local values_reg = "[bBhHlLjJTiIfdnczs]"

function unpack(fmt, data, i, fmt_index, tree)
	fmt_index = fmt_index or 1
	if fmt_index > #fmt then
		error("out of range")
	end
	
	local stack = {}
	local keys = {}
	local counts = {}
	local value
	local last_value
	local return_next_value
	
	while (#fmt >= fmt_index) do
		fmt_index = skip_spaces(fmt, fmt_index)
		
		if (#fmt < fmt_index) then
			break
		end
		
		local new_value
		
		if fmt:find("^[([]", fmt_index) then
			local it_is_key = fmt:find("^%(", fmt_index)
			local new_stack
			local debug_pos = fmt_index
			fmt_index, new_stack, i, new_value = unpack(fmt, data, i, fmt_index + 1, tree)
			
			if it_is_key then
				table.insert(keys, new_value)
			else
				table.insert(counts, new_value)
			end
			
			table.move(new_stack, 1, #new_stack, #stack + 1, stack)

		elseif fmt:find("^%{c%}", fmt_index) then
			table.remove(keys, 1)
			local count = table.remove(counts, 1)
			new_value = data:sub(i, i + count - 1)
			i = i + #new_value
			fmt_index = fmt_index + 3
			table.insert(stack, new_value)

		elseif fmt:find("^%{", fmt_index) then
			i, fmt_index, new_value = unpack_node(fmt, data, i, fmt_index + 1, stack, table.remove(keys, 1), table.remove(counts, 1), tree)

		elseif fmt:find("^[)}%],]", fmt_index) then
			fmt_index = fmt_index + 1
			break
			
		elseif fmt:find("^%*", fmt_index) then
			return_next_value = true
			fmt_index = fmt_index + 1
			
		elseif fmt:find(pack_reg, fmt_index) then
			local command = fmt:match(pack_reg, fmt_index)
			local new_stack = {old_unpack(command, data, i)}
			i = table.remove(new_stack)
			fmt_index = fmt_index + #command
			
			if #new_stack > 0 then
				table.move(new_stack, 1, #new_stack, #stack + 1, stack)	

				if return_next_value then
					new_value = new_stack[1]
				else
					new_value = new_stack[#new_stack]
				end
			end
			
		else
			error(("strange: %d %q"):format(fmt_index, fmt:sub(fmt_index)))
		end
		
		if new_value then
			if return_next_value and not value then
				value = new_value
				return_next_value = false
			end
			
			last_value = new_value
		end
	end
	
	return fmt_index, stack, i, value or last_value
end


local function count_args(fmt)
	local find_pos = 1
	local count = 0
	local ok
	repeat
		ok, find_pos = fmt:find(values_reg, find_pos)
		if ok then
			find_pos = find_pos + 1
			count = count + 1
		end
	until not ok
	
	find_pos = 1
	repeat
		ok, find_pos = fmt:find("X", find_pos, true)
		if ok then
			find_pos = find_pos + 1
			count = count - 1
		end
	until not ok
	return count
end


function pack(fmt, fmt_index, args, arg_index)

	fmt_index = fmt_index or 1
	arg_index = arg_index or 1
	
	if fmt_index > #fmt then
		error("out of range")
	end
	
	local keys = {}
	local counts = {}
	local buffer = {}
	local value
	local last_value
	local return_next_value
	
	while (#fmt >= fmt_index) do
		local new_value
		fmt_index = skip_spaces(fmt, fmt_index)
		
		if (#fmt < fmt_index) then
			break
		end
		
		if fmt:find("^[)}%],]", fmt_index) then
			fmt_index = fmt_index + 1
			break
			
		elseif fmt:find("^[([]", fmt_index) then
			local in_tbl = counts
		
			if fmt:find("^%(", fmt_index) then
				in_tbl = keys
			end
			
			fmt_index, arg_index, new_value, data = pack(fmt, fmt_index + 1, args, arg_index)
			
			table.insert(in_tbl, new_value)
			
			table.insert(buffer, data)
			
		elseif fmt:find("^%*", fmt_index) then
			return_next_value = true
			fmt_index = fmt_index + 1
			
		elseif fmt:find("^%{c%}", fmt_index) then
			table.remove(keys, 1)
			local count = table.remove(counts, 1)
			
			table.insert(buffer, old_pack(("c%d"):format(count), args[arg_index]))
			arg_index = arg_index + 1
			fmt_index = fmt_index + 3
			
		elseif fmt:find("^%{", fmt_index) then
			local data_key = table.remove(keys, 1)
			local count = table.remove(counts, 1)
			local index = 1
			local skip_rest = (count == 0)
			local key_found
			
			fmt_index = fmt_index + 1
			repeat
				if not skip_rest then
					local fmt_key = fmt:match("^([^:,(){}[%]]+):", fmt_index)
					if fmt_key then
						fmt_index = fmt_index + #fmt_key + 1
					end
					
					key_found, index = check_key(data_key, fmt_key, index)
				end
				
				local new_fmt_index
				
				if skip_rest or not key_found then
					new_fmt_index = skip_node(fmt, fmt_index)
				else
					for _ = 1, count or 1 do
						new_fmt_index, arg_index, new_value, data = pack(fmt, fmt_index, args, arg_index)
						table.insert(buffer, data)
					end
					skip_rest = true
				end
				fmt_index = new_fmt_index
			until not fmt:find("^,", fmt_index - 1)
			
		elseif fmt:find(pack_reg, fmt_index) then
			local fmt = fmt:match(pack_reg, fmt_index)
			local next_index = arg_index + count_args(fmt)
			table.insert(buffer, old_pack(fmt, table.unpack(args, arg_index, next_index - 1)))
			
			if return_next_value then
				new_value = args[arg_index]
			end
			
			arg_index = next_index
			fmt_index = fmt_index + #fmt
			
			if not return_next_value then
				new_value = args[arg_index - 1]
			end
			
		else
			error(("strange: %d %q"):format(fmt_index, fmt:sub(fmt_index)))
		end
		
		if new_value then
			if return_next_value and not value then
				value = new_value
				return_next_value = false
			end
			
			last_value = new_value
		end
	end
	
	return fmt_index, arg_index, value or last_value, table.concat(buffer)
end

local function flat(tbl, stack)
	stack = stack or {}
	for _, v in ipairs(tbl) do
		if type(v) == "table" then
			flat(v, stack)
		else
			table.insert(stack, v)
		end
	end
	return stack
end

function string.unpack(fmt, data, i, tree)
	local pos, stack, i = unpack(fmt, data, i, 1, tree)
	
	if tree then
		return stack, i
	end
	
	table.insert(stack, i)
	return table.unpack(stack)
end

function string.pack(fmt, ...)
	return select(4, pack(fmt, 1, flat({...}), 1))
end