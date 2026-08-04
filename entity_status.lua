-- entity_status.lua
-- Aggregate machine states per surface, force and entity type. This is the
-- "the factory is stalled, but where?" metric: no_ingredients, no_power,
-- full_output and friends, counted rather than listed.
--
-- Cost note: unlike count_entities_filtered, reading .status requires real
-- entity objects, so this is the most expensive collector in the mod. It is
-- therefore its own time-sliced stage, limited to a configurable set of
-- entity types, and hard-capped in the number of entities scanned per cycle.
-- Exceeding the cap is reported as a metric rather than silently truncating.

--- @type table<integer, string> Reverse lookup: entity_status value -> name
local status_names = {}
for name, value in pairs(defines.entity_status) do
	status_names[value] = name
end

--- Collect machine status counts.
--- @param event NthTickEventData
--- @return nil
function collect_entity_status(_event)
	if #entity_status_types == 0 then
		return
	end

	gauge_entity_status:reset()

	--- @type table<string, integer> "surface\0force\0type\0status" -> count
	local counts = {}
	local scanned = 0
	local truncated = false

	for _, surface in pairs(collected_surfaces()) do
		for _, entity_type in ipairs(entity_status_types) do
			if scanned >= entity_status_max_entities then
				truncated = true
				break
			end
			local entities = surface.find_entities_filtered({ type = entity_type })
			for _, entity in pairs(entities) do
				scanned = scanned + 1
				if scanned >= entity_status_max_entities then
					truncated = true
					break
				end
				local status = entity.status
				if status ~= nil then
					local key = surface.name .. "\0" .. entity.force.name .. "\0"
						.. entity_type .. "\0" .. (status_names[status] or "unknown")
					counts[key] = (counts[key] or 0) + 1
				end
			end
		end
		if truncated then
			break
		end
	end

	for key, count in pairs(counts) do
		local surface_name, force_name, entity_type, status_name = key:match("^(.-)%z(.-)%z(.-)%z(.*)$")
		gauge_entity_status:set(count, { surface_name, force_name, entity_type, status_name })
	end

	gauge_entity_status_scanned:set(scanned)
	gauge_entity_status_truncated:set(truncated and 1 or 0)
end
