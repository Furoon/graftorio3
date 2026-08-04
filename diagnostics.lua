-- diagnostics.lua
-- In-game /graftorio3 command. The most common support question for an
-- exporter is "nothing arrives in Prometheus" -- this answers it from the
-- server console without digging through logs: is collection running, how
-- many series are being written, where, and did any stage fail.

--- Build the diagnostic report as a plain string.
--- @return string
local function build_report()
	local lines = {}
	local function add(text)
		lines[#lines + 1] = text
	end

	add("graftorio3 " .. script.active_mods["graftorio3"])
	add("current tick: " .. game.tick)

	local last = storage.last_collection_tick
	if last then
		add("last collection: tick " .. last .. " (" .. (game.tick - last) .. " ticks ago)")
	else
		add("last collection: none yet")
	end

	add("output: script-output/graftorio3/" .. output_filename)
	if time_slicing then
		add("interval: full cycle every " .. nth_tick .. " ticks (time sliced, "
			.. #collection_stages .. " stages)")
	else
		add("interval: every " .. nth_tick .. " ticks (all stages in one tick)")
	end

	local surfaces = collected_surfaces()
	local names = {}
	for _, surface in pairs(surfaces) do
		names[#names + 1] = surface.name
	end
	add("surfaces collected: " .. #surfaces .. " (" .. table.concat(names, ", ") .. ")")

	if instance_label ~= "" then
		add('instance label: "' .. instance_label .. '"')
	end
	add("train stats: " .. (disable_train_stats and "disabled" or "enabled"))
	add("player metrics: " .. (collect_player_metrics and "enabled" or "disabled"))

	local errors = storage.collector_error_counts
	if errors and next(errors) then
		local parts = {}
		for module_name, count in pairs(errors) do
			parts[#parts + 1] = module_name .. "=" .. count
		end
		add("COLLECTOR ERRORS: " .. table.concat(parts, ", "))
		add("see the server log for the first error of each stage")
	else
		add("collector errors: none")
	end

	return table.concat(lines, "\n")
end

--- Register the /graftorio3 command.
function register_diagnostics_command()
	commands.add_command("graftorio3", "Show graftorio3 exporter status", function(command)
		local report = build_report()
		if command.player_index then
			local player = game.get_player(command.player_index)
			if player then
				player.print(report)
				return
			end
		end
		-- Server console: rcon.print when invoked via RCON, log otherwise
		if rcon then
			rcon.print(report)
		end
		log(report)
	end)
end
