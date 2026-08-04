-- ext.lua
-- Public remote interface. Lets other mods publish their own metrics through
-- graftorio3 instead of shipping a second exporter: register once, set values
-- whenever, and they appear in the same .prom file with the same labels,
-- instance label and write cadence as the built-in metrics.
--
-- Usage from another mod (registration must happen in BOTH on_init and
-- on_load -- prometheus state is rebuilt on every load):
--
--   local function register()
--     if not remote.interfaces["graftorio3"] then return end
--     remote.call("graftorio3", "register_gauge",
--       "mymod_widgets", "widgets produced", { "surface" })
--   end
--   script.on_init(register)
--   script.on_load(register)
--   -- later, from a tick handler:
--   remote.call("graftorio3", "set", "mymod_widgets", 42, { "nauvis" })

--- @type table<string, table> Registered external metric objects by name
local external = {}

--- @type integer Cap on distinct external metrics, guards against runaway
--- registration by a misbehaving mod.
local MAX_EXTERNAL_METRICS = 100

--- Validate a metric name and apply the shared factorio_ namespace.
--- @param name string
--- @return string? normalized, string? error_message
local function normalize_name(name)
	if type(name) ~= "string" or not name:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
		return nil, "invalid metric name (expected [a-zA-Z_][a-zA-Z0-9_]*)"
	end
	if name:sub(1, 9) == "factorio_" then
		return name, nil
	end
	return "factorio_" .. name, nil
end

--- @param kind string "gauge" or "counter"
--- @param name string
--- @param help string?
--- @param labels string[]?
--- @return boolean ok, string? error_message
local function register(kind, name, help, labels)
	local normalized, err = normalize_name(name)
	if not normalized then
		return false, err
	end
	if external[normalized] then
		-- Re-registration after a load is expected and must be idempotent.
		return true, nil
	end
	local count = 0
	for _ in pairs(external) do
		count = count + 1
	end
	if count >= MAX_EXTERNAL_METRICS then
		return false, "external metric limit reached (" .. MAX_EXTERNAL_METRICS .. ")"
	end
	if kind == "counter" then
		external[normalized] = prometheus.counter(normalized, help or "", labels)
	else
		external[normalized] = prometheus.gauge(normalized, help or "", labels)
	end
	return true, nil
end

--- Build the interface table. Every entry returns a boolean so callers can
--- react to failures instead of silently losing metrics.
local interface = {
	--- @return boolean ok, string? error_message
	register_gauge = function(name, help, labels)
		return register("gauge", name, help, labels)
	end,

	--- @return boolean ok, string? error_message
	register_counter = function(name, help, labels)
		return register("counter", name, help, labels)
	end,

	--- @return boolean ok, string? error_message
	set = function(name, value, label_values)
		local normalized = normalize_name(name)
		local metric = normalized and external[normalized]
		if not metric then
			return false, "metric not registered"
		end
		if type(value) ~= "number" then
			return false, "value must be a number"
		end
		metric:set(value, label_values)
		return true, nil
	end,

	--- @return boolean ok, string? error_message
	inc = function(name, amount, label_values)
		local normalized = normalize_name(name)
		local metric = normalized and external[normalized]
		if not metric then
			return false, "metric not registered"
		end
		metric:inc(amount or 1, label_values)
		return true, nil
	end,

	--- Interface version, so dependent mods can feature-detect.
	--- @return integer
	api_version = function()
		return 1
	end,
}

remote.add_interface("graftorio3", interface)
