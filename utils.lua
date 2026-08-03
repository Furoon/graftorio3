-- utils.lua
-- Utility functions for string manipulation

--- Split a string by a separator character.
--- @param inputstr string The string to split
--- @param sep string Single-character separator
--- @return string[] parts The split substrings
function split(inputstr, sep)
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

-- ============================================================================
-- Surface filtering (added in the 2.1 port)
-- ============================================================================

--- @type table<string, boolean>? Parsed allowlist of surface names; nil = all surfaces
surface_allowlist = nil

--- @type boolean Whether space platform surfaces are collected
include_platforms = true

--- Parse the surface filter startup setting into a lookup table.
--- @param raw string Comma-separated surface names; empty means "all surfaces"
--- @return table<string, boolean>? allowlist nil when unrestricted
function parse_surface_filter(raw)
	if not raw or raw:match("^%s*$") then
		return nil
	end
	local set = {}
	for _, name in ipairs(split(raw, ",")) do
		local trimmed = name:match("^%s*(.-)%s*$")
		if trimmed ~= "" then
			set[trimmed] = true
		end
	end
	if next(set) == nil then
		return nil
	end
	return set
end

--- Decide whether a surface should be collected.
--- @param surface LuaSurface
--- @return boolean
function surface_enabled(surface)
	if not surface.valid then
		return false
	end
	if surface_allowlist then
		return surface_allowlist[surface.name] == true
	end
	if not include_platforms and surface.platform then
		return false
	end
	return true
end

--- Build the list of surfaces to collect this cycle.
--- Replaces every `pairs(game.surfaces)` loop in the collection path so that
--- Space Age platforms do not multiply per-surface work and label cardinality.
--- @return LuaSurface[]
function collected_surfaces()
	local out = {}
	for _, surface in pairs(game.surfaces) do
		if surface_enabled(surface) then
			out[#out + 1] = surface
		end
	end
	return out
end

-- ============================================================================
-- Entity-count type filtering (added for the environment/state metrics module)
-- ============================================================================

--- @type table<string, boolean>? Parsed entity-type list for factorio_entity_count; nil = disabled
entity_count_types = nil

--- Parse the entity-count-types startup setting the same way parse_surface_filter
--- parses the surface allowlist: comma-separated, trimmed, empty means "none".
--- @param raw string
--- @return string[] types
function parse_entity_count_types(raw)
	local set = parse_surface_filter(raw)
	if not set then
		return {}
	end
	local out = {}
	for name, _ in pairs(set) do
		out[#out + 1] = name
	end
	table.sort(out)
	return out
end
