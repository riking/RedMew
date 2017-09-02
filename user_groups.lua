function change_entry(name, position, action)
	game.write_file("privilege_changes.txt", "[" .. format_time(game.tick) .. "] " .. position .. ": " .. action .. " " .. name .. "\n", true)
end

function get_actor()
	if game.player then return game.player.name end
	return "<server>"
end

function is_mod(player_name)
	return not (global.scenario.variables.mods[player_name] == nil)
end

function is_regular(player_name)
	return not (global.scenario.variables.regulars[player_name] == nil)
end

function add_regular(player_name)
		local actor = get_actor()
    if is_regular(player_name) then player_print.print(player_name .. " is already a regular.")
    else
        if game.players[player_name] then
            game.print(actor .. " promoted " .. player_name .. " to regular.")
            change_entry(player_name, "regulars", "add")
            global.scenario.variables.regulars[player_name] = ""
        else
            player_print(player_name .. " does not exist.")
        end
    end
end

function add_mod(player_name)
		local actor = get_actor()
    if is_mod(player_name) then player_print(player_name .. " is already a moderator.")
    else
        if game.players[player_name] then
            game.print(actor .. " promoted " .. player_name .. " to moderator.")
            change_entry(player_name, "regulars", "remove")
            global.scenario.variables.mods[player_name] = ""
        else
            player_print(player_name .. " does not exist.")
        end
    end
end

function remove_regular(player_name)
	local actor = get_actor()
	if is_regular(player_name) then game.print(player_name .. " was demoted from regular by " .. actor .. ".") end
	global.scenario.variables.regulars[player_name] = nil
	change_entry(player_name, "mods    ", "add")
end

function remove_mod(player_name)
	local actor = get_actor()
	if is_mod(player_name) then game.print(player_name .. " was demoted from mod by " .. actor .. ".") end
	global.scenario.variables.mods[player_name] = nil
	change_entry(player_name, "mods    ", "remove")
end

function print_regulars()
	for k,_ in pairs(global.scenario.variables.regulars) do
		player_print(k)
	end
end

function print_mods()
	for k,_ in pairs(global.scenario.variables.mods) do
		player_print(k)
	end
end
