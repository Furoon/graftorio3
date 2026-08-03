-- counters.lua
-- Monotonic event counters. Unlike the gauge modules, these are true
-- Prometheus counters intended for rate() queries: "rockets per hour",
-- "deaths per minute during an attack".
--
-- The vendored prometheus library keeps counter state in memory, so it
-- resets on every save/load. The authoritative totals therefore live in
-- `storage`, and each collection cycle re-applies the delta between the
-- stored total and what has already been pushed into the library. After a
-- load, `applied` starts empty, so the first cycle re-inflates the counter
-- to the stored total -- monotonic across restarts, not just within a session.

--- @type table<string, number> Totals already pushed into the library this session
local applied = {}

--- @type table<string, number> Per-player totals already pushed this session
local applied_players = {}

--- Ensure the storage tables exist. Safe to call on every event.
local function ensure_storage()
	storage.event_counts = storage.event_counts or {}
	storage.player_deaths = storage.player_deaths or {}
	storage.player_kills = storage.player_kills or {}
end

--- Increment a durable event total.
--- @param event_type string
--- @param amount number?
local function bump(event_type, amount)
	ensure_storage()
	storage.event_counts[event_type] = (storage.event_counts[event_type] or 0) + (amount or 1)
end

--- @param _event EventData.on_rocket_launched
function on_counter_rocket_launched(_event)
	bump("rocket_launched")
end

--- @param _event EventData.on_research_finished
function on_counter_research_finished(_event)
	bump("research_finished")
end

--- @param event EventData.on_player_died
function on_counter_player_died(event)
	bump("player_died")
	ensure_storage()
	local player = game.get_player(event.player_index)
	if player then
		storage.player_deaths[player.name] = (storage.player_deaths[player.name] or 0) + 1
	end
end

--- Attribute an entity kill to a player when the killing entity is a
--- character with a player attached. Only fires on deaths, so the cost is
--- proportional to combat, not to factory size.
--- @param event EventData.on_entity_died
function on_counter_entity_died(event)
	local cause = event.cause
	if not (cause and cause.valid and cause.type == "character" and cause.player) then
		return
	end
	ensure_storage()
	local name = cause.player.name
	storage.player_kills[name] = (storage.player_kills[name] or 0) + 1
end

--- Push stored totals into the prometheus counters.
--- @param event NthTickEventData
function collect_counters(_event)
	ensure_storage()

	for event_type, total in pairs(storage.event_counts) do
		local delta = total - (applied[event_type] or 0)
		if delta > 0 then
			counter_events:inc(delta, { event_type })
			applied[event_type] = total
		end
	end

	if not collect_player_metrics then
		return
	end

	for name, total in pairs(storage.player_deaths) do
		local key = "d\0" .. name
		local delta = total - (applied_players[key] or 0)
		if delta > 0 then
			counter_player_deaths:inc(delta, { name })
			applied_players[key] = total
		end
	end

	for name, total in pairs(storage.player_kills) do
		local key = "k\0" .. name
		local delta = total - (applied_players[key] or 0)
		if delta > 0 then
			counter_player_kills:inc(delta, { name })
			applied_players[key] = total
		end
	end
end
