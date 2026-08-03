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

-- ============================================================================
-- Instance label + output filename (multi-server support, added 1.3.0)
-- ============================================================================

--- Escape a value for use inside a Prometheus label string.
--- @param value string
--- @return string
local function escape_label_value(value)
	value = value:gsub("\\", "\\\\")
	value = value:gsub('"', '\\"')
	value = value:gsub("\n", "\\n")
	return value
end

--- Inject an instance="..." label into every sample line of a rendered
--- exposition-format string. Lines starting with # (HELP/TYPE) and blank
--- lines pass through untouched. Handles both labelled samples
--- (name{a="b"} v) and bare samples (name v).
--- @param text string Rendered exposition text
--- @param instance string Raw instance label value
--- @return string
function apply_instance_label(text, instance)
	local escaped = escape_label_value(instance)
	local out = {}
	for line in text:gmatch("([^\n]*)\n?") do
		if line == "" or line:sub(1, 1) == "#" then
			out[#out + 1] = line
		else
			local replaced = line:gsub("^([%w_:]+)({)", '%1{instance="' .. escaped .. '",', 1)
			if replaced == line then
				replaced = line:gsub("^([%w_:]+)(%s)", '%1{instance="' .. escaped .. '"}%2', 1)
			end
			out[#out + 1] = replaced
		end
	end
	return table.concat(out, "\n")
end

--- Sanitize the configured output filename: strip path separators so the
--- setting cannot escape the graftorio3/ output directory, and guarantee a
--- non-empty name.
--- @param raw string
--- @return string
function sanitize_output_filename(raw)
	local name = (raw or ""):gsub("[/\\%z]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		return "game.prom"
	end
	return name
end
