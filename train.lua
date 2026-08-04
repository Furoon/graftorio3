-- train.lua
-- Collects train travel time metrics including trip times, wait times, and loop times
-- Uses histograms with configurable buckets for time distribution analysis

require("utils")

-- Constants
local TICKS_PER_SECOND = 60

--- @class TrainTrip
--- @field source string Source station name where the trip began
--- @field departure_tick uint Game tick when the train departed (updated on each leg)
--- @field wait_start_tick uint Game tick when the train began waiting at a signal (0 if not waiting)
--- @field total_wait_ticks uint Accumulated ticks spent waiting at signals during this trip

--- @class StationArrival
--- @field last_arrival_tick uint Game tick of the last train arrival at this station (0 if none yet)

--- Parse a comma-separated string of bucket boundaries into a numeric array.
--- @param bucket_settings string Comma-separated bucket values (e.g. "10,30,60,90")
--- @return number[]
function train_buckets(bucket_settings)
	local train_buckets = {}
	for _, bucket in pairs(split(bucket_settings, ",")) do
		table.insert(train_buckets, tonumber(bucket))
	end
	return train_buckets
end

-- Trip and arrival state lives in `storage`, not in module locals. As module
-- locals it was silently reset on every save/load: trips in flight were lost
-- and the `seen` table grew without bound because dead trains were never
-- removed. Both are fixed here.

--- Ensure the storage tables exist. Cheap enough to call from every handler.
local function ensure_storage()
	storage.train_trips = storage.train_trips or {}
	storage.train_arrivals = storage.train_arrivals or {}
	storage.train_seen = storage.train_seen or {}
end

--- @type uint Train ID to watch for debug output (0 = disabled)
local watched_train = 0

--- @type string Station name to watch for debug output ("" = disabled)
local watched_station = ""

--- Debug helper: print a message if the event's train matches the watched train.
-- luacheck: ignore watch_train watch_station
--- @param event EventData.on_train_changed_state
--- @param msg string
local function watch_train(event, msg)
	if event.train.id == watched_train then
		game.print(msg)
	end
end

--- Debug helper: print a message if the event's destination matches the watched station.
--- @param event EventData.on_train_changed_state
--- @param msg string
local function watch_station(event, msg)
	if event.train.path_end_stop.backer_name == watched_station then
		game.print(msg)
	end
end

--- Begin tracking a new train trip from its current destination station.
--- @param event EventData.on_train_changed_state
local function create_train(event)
	if event.train.path_end_stop == nil then
		return
	end

	--- @type TrainTrip
	storage.train_trips[event.train.id] = {
		source = event.train.path_end_stop.backer_name,
		departure_tick = game.tick,
		wait_start_tick = 0,
		total_wait_ticks = 0,
	}
	-- watch_train(event, "begin tracking " .. event.train.id)
end

--- Initialize arrival tracking for a new station.
--- @param event EventData.on_train_changed_state
local function create_station(event)
	if event.train.path_end_stop == nil then
		return
	end

	--- @type StationArrival
	storage.train_arrivals[event.train.path_end_stop.backer_name] = { last_arrival_tick = 0 }
	-- watch_station(event, "created station " .. event.train.path_end_stop.backer_name)
end

--- Reset a train's trip data for the next leg of its journey.
--- @param event EventData.on_train_changed_state
local function reset_train(event)
	if event.train.path_end_stop == nil then
		return
	end

	--- @type TrainTrip
	storage.train_trips[event.train.id] = {
		source = event.train.path_end_stop.backer_name,
		departure_tick = game.tick,
		wait_start_tick = 0,
		total_wait_ticks = 0,
	}
end



--- Track direct loop times (round-trip between two stations).
--- @param event EventData.on_train_changed_state
--- @param duration number Trip duration in seconds (unused internally, kept for signature consistency)
--- @param labels {[1]: string, [2]: string, [3]: uint} {from_station, to_station, train_id}
local function direct_loop(_event, _duration, labels)
	local from = labels[1]
	local to = labels[2]
	local train_id = labels[3]

	if storage.train_seen[train_id] == nil then
		storage.train_seen[train_id] = {}
	end

	if storage.train_seen[train_id][from] == nil then
		storage.train_seen[train_id][from] = {}
	end

	if storage.train_seen[train_id][from][to] then
		local total = (game.tick - storage.train_seen[train_id][from][to]) / TICKS_PER_SECOND

		--- @type string[]
		local sorted = { from, to }
		table.sort(sorted)

		-- watch_train(event, sorted[1] .. ":" .. sorted[2] .. " total " .. total)

		gauge_train_direct_loop_time:set(total, sorted)
		histogram_train_direct_loop_time:observe(total, sorted)
	end

	-- Lap timing (disabled debug output); kept for reference:
	-- if storage.train_seen[train_id][to] and storage.train_seen[train_id][to][from] then
	-- 	watch_train(event, from .. ":" .. to .. " lap " .. (game.tick - storage.train_seen[train_id][to][from]) / TICKS_PER_SECOND)
	-- end

	storage.train_seen[train_id][from][to] = game.tick
end

--- Track time between consecutive arrivals at the same station.
--- @param event EventData.on_train_changed_state
local function track_arrival(event)
	if event.train.path_end_stop == nil then
		return
	end

	if storage.train_arrivals[event.train.path_end_stop.backer_name] == nil then
		create_station(event)
	end

	-- watch_station(event, "arrived at " .. event.train.path_end_stop.backer_name)
	if storage.train_arrivals[event.train.path_end_stop.backer_name].last_arrival_tick ~= 0 then
		local time_since_last_arrival = (game.tick - storage.train_arrivals[event.train.path_end_stop.backer_name].last_arrival_tick) / TICKS_PER_SECOND
		local labels = { event.train.path_end_stop.backer_name }

		gauge_train_arrival_time:set(time_since_last_arrival, labels)
		histogram_train_arrival_time:observe(time_since_last_arrival, labels)

		-- watch_station(event, "time_since_last_arrival was " .. time_since_last_arrival)
	end

	storage.train_arrivals[event.train.path_end_stop.backer_name].last_arrival_tick = game.tick
end

--- Build the label set for trip metrics. The train ID is the worst
--- cardinality offender in the whole mod -- one series per train per station
--- pair -- so it is collapsed to a constant unless explicitly enabled. The
--- label itself stays in the schema so dashboards keep working either way.
--- @param from string
--- @param to string
--- @param train_id uint
--- @return string[]
local function trip_labels(from, to, train_id)
	return { from, to, train_include_id and tostring(train_id) or "all" }
end

--- Check whether a new label combination may still be tracked. Returns false
--- once the configured series budget is exhausted, so a runaway station
--- naming scheme degrades into missing new series instead of an unbounded
--- Prometheus cardinality explosion.
--- @param key string
--- @return boolean
local function may_track(key)
	ensure_storage()
	storage.train_series = storage.train_series or {}
	if storage.train_series[key] then
		return true
	end
	local count = 0
	for _ in pairs(storage.train_series) do
		count = count + 1
	end
	if count >= train_max_series then
		gauge_train_series_truncated:set(1)
		return false
	end
	storage.train_series[key] = true
	gauge_train_series_truncated:set(0)
	return true
end

--- Remove state for trains that no longer exist. Trains get new IDs when
--- they are rebuilt or recoupled, so without this the seen/trip tables grow
--- for the lifetime of the save -- a slow leak on long-running servers.
--- @param event NthTickEventData
--- @return nil
function collect_train_gc(_event)
	ensure_storage()
	local alive = {}
	for _, train in pairs(game.train_manager.get_trains({})) do
		if train.valid then
			alive[train.id] = true
		end
	end
	local removed = 0
	for train_id in pairs(storage.train_trips) do
		if not alive[train_id] then
			storage.train_trips[train_id] = nil
			removed = removed + 1
		end
	end
	for train_id in pairs(storage.train_seen) do
		if not alive[train_id] then
			storage.train_seen[train_id] = nil
			removed = removed + 1
		end
	end
	gauge_train_tracked:set(table_size(storage.train_trips))
	gauge_train_gc_removed:set(removed)
end

--- Main train state change handler. Registered as an event callback from control.lua.
--- Tracks trip times, wait times, direct loop times, and inter-arrival times.
--- @param event EventData.on_train_changed_state
function register_events_train(event)
	if event == nil or event.train == nil then
		return
	end

	ensure_storage()

	if event.train.state == defines.train_state.arrive_station then
		track_arrival(event)
	end

	if storage.train_trips[event.train.id] ~= nil then
		if event.train.state == defines.train_state.arrive_station then
			if event.train.path_end_stop == nil then
				return
			end

			if storage.train_trips[event.train.id].source == event.train.path_end_stop.backer_name then
				return
			end

			local trip = storage.train_trips[event.train.id]
			local duration = (game.tick - trip.departure_tick) / TICKS_PER_SECOND
			local wait = trip.total_wait_ticks / TICKS_PER_SECOND

			-- watch_train(event, event.train.id .. ": " .. trip.source .. "->" .. event.train.path_end_stop.backer_name .. " took " .. duration .. "s waited " .. wait .. "s")

			local labels = trip_labels(trip.source, event.train.path_end_stop.backer_name, event.train.id)
			if not may_track("trip\0" .. labels[1] .. "\0" .. labels[2] .. "\0" .. labels[3]) then
				reset_train(event)
				return
			end

			gauge_train_trip_time:set(duration, labels)
			gauge_train_wait_time:set(wait, labels)
			histogram_train_trip_time:observe(duration, labels)
			histogram_train_wait_time:observe(wait, labels)
			direct_loop(event, duration, labels)

			reset_train(event)
		elseif
			event.train.state == defines.train_state.on_the_path
			and event.old_state == defines.train_state.wait_station
		then
			-- begin moving after waiting at a station
			storage.train_trips[event.train.id].departure_tick = game.tick
		-- watch_train(event, event.train.id .. " leaving for " .. event.train.path_end_stop.backer_name)
		elseif event.train.state == defines.train_state.wait_signal then
			-- waiting at a signal
			storage.train_trips[event.train.id].wait_start_tick = game.tick
		-- watch_train(event, event.train.id .. " waiting")
		elseif event.old_state == defines.train_state.wait_signal then
			-- begin moving after waiting at a signal
			storage.train_trips[event.train.id].total_wait_ticks = storage.train_trips[event.train.id].total_wait_ticks
				+ (game.tick - storage.train_trips[event.train.id].wait_start_tick)
			-- watch_train(event, event.train.id .. " waited for " .. (game.tick - storage.train_trips[event.train.id].wait_start_tick) / TICKS_PER_SECOND)
			storage.train_trips[event.train.id].wait_start_tick = 0
		end
	end

	if storage.train_trips[event.train.id] == nil and event.train.state == defines.train_state.arrive_station then
		create_train(event)
	end
end
