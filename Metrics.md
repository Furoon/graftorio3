# Metrics

Generated from control.lua by scripts/gen_metrics.py -- do not edit by hand.

| Metric | Type | Labels | Description |
| --- | --- | --- | --- |
| factorio_tick | gauge |  | game tick |
| factorio_connected_player_count | gauge |  | connected players |
| factorio_total_player_count | gauge |  | total registered players |
| factorio_seed | gauge | surface | seed |
| factorio_mods | gauge | name, version | mods |
| factorio_item_production_input | gauge | force, name, surface, quality | items produced |
| factorio_item_production_output | gauge | force, name, surface, quality | items consumed |
| factorio_fluid_production_input | gauge | force, name, surface | fluids produced |
| factorio_fluid_production_output | gauge | force, name, surface | fluids consumed |
| factorio_kill_count_input | gauge | force, name, surface | kills |
| factorio_kill_count_output | gauge | force, name, surface | losses |
| factorio_entity_build_count_input | gauge | force, name, surface | entities placed |
| factorio_entity_build_count_output | gauge | force, name, surface | entities removed |
| factorio_pollution_production_input | gauge | name, surface | pollutions produced |
| factorio_pollution_production_output | gauge | name, surface | pollutions consumed |
| factorio_evolution | gauge | force, type, surface | evolution |
| factorio_research_queue | gauge | force, name, level, index | research |
| factorio_items_launched | gauge | force, name, quality | items launched in rockets |
| factorio_yarm_site_amount | gauge | force, name, type | YARM - site amount remaining |
| factorio_yarm_site_ore_per_minute | gauge | force, name, type | YARM - site ore per minute |
| factorio_yarm_site_remaining_permille | gauge | force, name, type | YARM - site permille remaining |
| factorio_train_trip_time | gauge | from, to, train_id | train trip time |
| factorio_train_wait_time | gauge | from, to, train_id | train wait time |
| factorio_train_trip_time_groups | histogram | from, to, train_id | train trip time |
| factorio_train_wait_time_groups | histogram | from, to, train_id | train wait time |
| factorio_train_direct_loop_time | gauge | a, b | train direct loop time |
| factorio_train_direct_loop_time_groups | histogram | a, b | train direct loop time |
| factorio_train_arrival_time | gauge | station | train arrival time |
| factorio_train_arrival_time_groups | histogram | station | train arrival time |
| factorio_logistic_network_all_construction_robots | gauge | force, surface, network | the total number of construction robots in the network (idle and active + in roboports) |
| factorio_logistic_network_available_construction_robots | gauge | force, surface, network | the number of construction robots available for a job |
| factorio_logistic_network_all_logistic_robots | gauge | force, surface, network | the total number of logistic robots in the network (idle and active + in roboports) |
| factorio_logistic_network_available_logistic_robots | gauge | force, surface, network | the number of logistic robots available for a job |
| factorio_logistic_network_robot_limit | gauge | force, surface, network | the maximum number of robots the network can work with |
| factorio_logistic_network_items | gauge | force, surface, network, name, quality | the number of items in a logistic network |
| factorio_accumulator_charge_joules | gauge | surface, network | stored energy in accumulators |
| factorio_accumulator_capacity_joules | gauge | surface, network | total accumulator buffer size |
| factorio_generation_capacity_watts | gauge | surface, network | installed maximum generation capacity |
| factorio_logistic_storage_items | gauge | force, surface, network, name, quality | items sitting in storage chests |
| factorio_logistic_provider_items | gauge | force, surface, network, name, quality | items available in provider chests |
| factorio_rocket_silo_parts | gauge | surface, force, silo | rocket parts built in this silo |
| factorio_rocket_silo_status | gauge | surface, force, silo | rocket silo status enum value |
| factorio_depth_scanned | gauge |  | entities inspected during the last depth scan |
| factorio_circuit_network_signal | gauge | force, surface, network, name, quality | the value of a signal in a circuit network |
| factorio_circuit_network_monitored | gauge | force, surface, network | whether a circuit network with given ID is being monitored |
| factorio_power_production_input | gauge | force, name, network, surface | power produced |
| factorio_power_production_output | gauge | force, name, network, surface | power consumed |
| factorio_platforms | gauge | force | number of space platforms |
| factorio_rockets_launched | gauge | force | rockets launched per force |
| factorio_collector_errors_total | counter | module | collector stages that raised an error |
| factorio_exporter_series | gauge |  | metric series written in the previous cycle |
| factorio_exporter_output_bytes | gauge |  | bytes written in the previous cycle |
| factorio_exporter_last_collection_tick | gauge |  | game tick of the last completed collection |
| factorio_surface_pollution | gauge | surface | total pollution on the surface |
| factorio_events_total | counter | type | game events observed since map creation |
| factorio_entity_status | gauge | surface, force, type, status | machines by operational status |
| factorio_entity_status_scanned | gauge |  | entities inspected during the last status scan |
| factorio_entity_status_truncated | gauge |  | whether the last status scan hit the entity cap (1=truncated) |
| factorio_train_tracked | gauge |  | trains with active trip tracking |
| factorio_train_gc_removed | gauge |  | stale train entries removed by the last garbage collection |
| factorio_train_series_truncated | gauge |  | whether the train series budget is exhausted (1=truncated) |
| factorio_player_deaths_total | counter | player | player deaths |
| factorio_player_kills_total | counter | player | entities killed by a player |
| factorio_platform_state | gauge | force, platform, state | platform state (1=active) |
| factorio_platform_weight | gauge | force, platform | platform total weight |
| factorio_platform_speed | gauge | force, platform | platform speed |
| factorio_platform_distance | gauge | force, platform | platform distance along connection (0-1) |
| factorio_platform_damaged_tiles | gauge | force, platform | number of damaged platform tiles |
| factorio_kr_antimatter_reactors | gauge | force, surface | number of antimatter reactors |
| factorio_game_speed | gauge |  | map simulation speed multiplier (1.0 = normal) |
| factorio_tick_paused | gauge |  | whether the game tick is paused (1=paused) |
| factorio_ticks_played | gauge |  | ticks played since game creation, unaffected by pause |
| factorio_technology_price_multiplier | gauge |  | difficulty setting: technology price multiplier |
| factorio_spoil_time_modifier | gauge |  | difficulty setting: spoil time modifier |
| factorio_peaceful_mode | gauge | surface | whether peaceful mode is enabled (1=enabled) |
| factorio_solar_power_multiplier | gauge | surface | solar power multiplier |
| factorio_darkness | gauge | surface | surface darkness (0-1) |
| factorio_wind_speed | gauge | surface | surface wind speed |
| factorio_wind_orientation | gauge | surface | surface wind orientation (0-1) |
| factorio_freeze_daytime | gauge | surface | whether the surface freezes at night (1=freezes) |
| factorio_entities | gauge | surface, type | entity count by type (includes unit-spawner for enemy pressure) |
| factorio_technologies_researched | gauge | force | technologies researched |
| factorio_technologies_available | gauge | force | technologies available |
| factorio_friendly_fire | gauge | force | whether friendly fire is enabled (1=enabled) |
| factorio_player_online_time_ticks | gauge | player | ticks this player has played this save |
| factorio_player_afk_time_ticks | gauge | player | ticks this player has been afk |
