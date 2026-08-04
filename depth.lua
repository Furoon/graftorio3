-- depth.lua
-- Deeper metrics for three subsystems that the base collectors only cover at
-- surface level: electric network reserves and capacity, where logistic
-- network stock actually sits, and per-silo rocket progress.
--
-- Like entity_status.lua these need real entity objects, so this is a
-- separate time-sliced stage with a configurable entity type list and a scan
-- cap. Everything here is opt-out via graftorio3-depth-metrics.

--- Aggregate accumulator charge and generation capacity per electric network.
--- Current flow (already collected by power.lua) tells you what is happening
--- now; buffer level and installed capacity tell you whether the network is
--- about to run out, which is the actually actionable question.
--- @param scanned integer
--- @return integer scanned
local function collect_power_depth(scanned)
	local charge, capacity, generation = {}, {}, {}

	for _, surface in pairs(collected_surfaces()) do
		for _, entity in pairs(surface.find_entities_filtered({ type = "accumulator" })) do
			scanned = scanned + 1
			local key = surface.name .. "\0" .. entity.electric_network_id
			charge[key] = (charge[key] or 0) + entity.energy
			capacity[key] = (capacity[key] or 0) + entity.electric_buffer_size
		end

		for _, entity in pairs(surface.find_entities_filtered({ type = { "solar-panel", "generator", "reactor", "burner-generator" } })) do
			scanned = scanned + 1
			local key = surface.name .. "\0" .. entity.electric_network_id
			local max_production = entity.prototype.get_max_energy_production()
			if max_production then
				-- Prototype values are per tick; scale to watts.
				generation[key] = (generation[key] or 0) + max_production * 60
			end
		end
	end

	for key, value in pairs(charge) do
		local surface_name, network = key:match("^(.-)%z(.*)$")
		gauge_accumulator_charge:set(value, { surface_name, network })
		gauge_accumulator_capacity:set(capacity[key] or 0, { surface_name, network })
	end
	for key, value in pairs(generation) do
		local surface_name, network = key:match("^(.-)%z(.*)$")
		gauge_generation_capacity:set(value, { surface_name, network })
	end

	return scanned
end

--- Split logistic network stock into storage versus providers.
--- The API exposes get_contents("storage") and get_contents("providers") but
--- no cheap view of outstanding requests, so this reports where stock sits
--- rather than pretending to measure demand. Stock piling up in storage while
--- providers run empty is the signal worth alerting on.
--- @return nil
local function collect_logistic_depth()
	for _, force in pairs(game.forces) do
		if force.valid then
			for _, surface in pairs(collected_surfaces()) do
				local networks = force.logistic_networks[surface.name]
				if networks then
					for index, network in pairs(networks) do
						if network.valid then
							for _, member in ipairs({ "storage", "providers" }) do
								local gauge = member == "storage" and gauge_logistic_storage_items
									or gauge_logistic_provider_items
								-- get_contents returns an array of records
								-- {name, quality, count}, not a name -> count map.
								for _, entry in pairs(network.get_contents(member)) do
									gauge:set(entry.count, {
										force.name,
										surface.name,
										tostring(index),
										entry.name,
										entry.quality or "normal",
									})
								end
							end
						end
					end
				end
			end
		end
	end
end

--- Per-silo rocket progress and status.
--- @param scanned integer
--- @return integer scanned
local function collect_rocket_silos(scanned)
	gauge_rocket_silo_parts:reset()
	gauge_rocket_silo_status:reset()

	for _, surface in pairs(collected_surfaces()) do
		for _, silo in pairs(surface.find_entities_filtered({ type = "rocket-silo" })) do
			scanned = scanned + 1
			local labels = { surface.name, silo.force.name, tostring(silo.unit_number) }
			gauge_rocket_silo_parts:set(silo.rocket_parts or 0, labels)
			gauge_rocket_silo_status:set(silo.rocket_silo_status or 0, labels)
		end
	end

	return scanned
end

--- Space platform interior: hub stock, asteroid chunks in flight, pause state.
--- The base collector reports a platform's state, weight, speed and distance;
--- none of that says whether it is actually carrying anything or whether its
--- asteroid intake has dried up.
---
--- Guarded per platform: platform APIs are the newest part of the runtime and
--- a single odd platform should not take the stage down.
--- @return nil
local function collect_platform_depth()
	gauge_platform_hub_items:reset()
	gauge_platform_asteroid_chunks:reset()
	gauge_platform_paused:reset()

	for _, force in pairs(game.forces) do
		if force.valid then
			for _, platform in pairs(force.platforms or {}) do
				if platform.valid then
					local labels = { force.name, platform.name }
					pcall(function()
						gauge_platform_paused:set(platform.paused and 1 or 0, labels)
					end)

					pcall(function()
						local hub = platform.hub
						if hub and hub.valid then
							local inventory = hub.get_inventory(defines.inventory.hub_main)
							if inventory then
								-- get_contents returns {name, quality, count} records.
								for _, entry in pairs(inventory.get_contents()) do
									gauge_platform_hub_items:set(entry.count, {
										force.name, platform.name, entry.name, entry.quality or "normal",
									})
								end
							end
						end
					end)

					pcall(function()
						local chunks = platform.find_asteroid_chunks_filtered({})
						gauge_platform_asteroid_chunks:set(#chunks, labels)
					end)
				end
			end
		end
	end
end

--- Entry point for the guarded dispatcher.
--- @param event NthTickEventData
--- @return nil
function collect_depth(_event)
	if not depth_metrics then
		return
	end

	local scanned = 0
	scanned = collect_power_depth(scanned)
	collect_logistic_depth()
	scanned = collect_rocket_silos(scanned)
	collect_platform_depth()
	gauge_depth_scanned:set(scanned)
end
