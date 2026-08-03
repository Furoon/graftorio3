-- env.lua
-- Server- and environment-level metrics: simulation state, per-surface
-- environmental factors, per-force research/settings summaries, and
-- (opt-in) per-player playtime. Every value here comes from a single
-- attribute read -- no event handlers, no storage, no iteration beyond
-- the filtered surface/force sets already used elsewhere in the mod.

--- Collect map-wide simulation state: speed, pause, real playtime, and the
--- two difficulty knobs that change how every other rate in the game reads.
--- @return nil
local function collect_simulation_state()
	gauge_game_speed:set(game.speed)
	gauge_tick_paused:set(game.tick_paused and 1 or 0)
	gauge_ticks_played:set(game.ticks_played)

	local difficulty = game.difficulty_settings
	gauge_technology_price_multiplier:set(difficulty.technology_price_multiplier)
	gauge_spoil_time_modifier:set(difficulty.spoil_time_modifier)
end

--- Collect per-surface environmental and mode metrics.
--- @param surfaces LuaSurface[]
--- @return nil
local function collect_surface_state(surfaces)
	for _, surface in pairs(surfaces) do
		gauge_peaceful_mode:set(surface.peaceful_mode and 1 or 0, { surface.name })
		gauge_solar_power_multiplier:set(surface.solar_power_multiplier, { surface.name })
		gauge_darkness:set(surface.darkness, { surface.name })
		gauge_wind_speed:set(surface.wind_speed, { surface.name })
		gauge_wind_orientation:set(surface.wind_orientation, { surface.name })
		gauge_freeze_daytime:set(surface.freeze_daytime and 1 or 0, { surface.name })

		for _, entity_type in ipairs(entity_count_types) do
			local count = surface.count_entities_filtered({ type = entity_type })
			gauge_entity_count:set(count, { surface.name, entity_type })
		end
	end
end

--- Collect per-force technology progress and settings.
--- LuaForce.technologies is a LuaCustomTable; counting via pairs() is the
--- only way to size it, same cost class as the existing production-stat loops.
--- @return nil
local function collect_force_state()
	for _, force in pairs(game.forces) do
		if force.valid then
			local researched, total = 0, 0
			for _, technology in pairs(force.technologies) do
				total = total + 1
				if technology.researched then
					researched = researched + 1
				end
			end
			gauge_technologies_researched:set(researched, { force.name })
			gauge_technologies_total:set(total, { force.name })
			gauge_friendly_fire:set(force.friendly_fire and 1 or 0, { force.name })
		end
	end
end

--- Collect per-player playtime. Off by default (graftorio3-collect-player-metrics):
--- player names as labels are fine on small private servers but unbounded
--- cardinality on a community server with high player turnover.
--- @return nil
local function collect_player_state()
	if not collect_player_metrics then
		return
	end
	for _, player in pairs(game.players) do
		gauge_player_online_time:set(player.online_time, { player.name })
		gauge_player_afk_time:set(player.afk_time, { player.name })
	end
end

--- Entry point for the guarded nth-tick dispatcher.
--- @param event NthTickEventData
--- @return nil
function collect_environment(event)
	collect_simulation_state()
	collect_surface_state(collected_surfaces())
	collect_force_state()
	collect_player_state()
end
