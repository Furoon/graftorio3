-- Deterministic benchmark world for CI regression runs.
-- Builds 5 surfaces, ~700 mixed entities on nauvis and filled production /
-- fluid / kill / build / pollution statistics on every surface, so metric
-- collection cost is representative of a real multi-surface save.
script.on_init(function()
  local f = game.forces.player
  local s = game.surfaces.nauvis
  s.request_to_generate_chunks({x=0, y=0}, 3)
  s.force_generate_chunk_requests()

  local made = 0
  for x = -16, 16 do
    for y = -10, 10 do
      local m = (x + y) % 5
      local n
      if m == 0 then n = "medium-electric-pole"
      elseif m == 1 then n = "assembling-machine-2"
      elseif m == 2 then n = "transport-belt"
      elseif m == 3 then n = "inserter"
      else n = "steel-chest" end
      if pcall(function() s.create_entity{name=n, position={x*3, y*3}, force=f, raise_built=true} end) then
        made = made + 1
      end
    end
  end
  pcall(function() s.create_entity{name="roboport", position={60,60}, force=f, raise_built=true} end)
  pcall(function() s.create_entity{name="passive-provider-chest", position={62,60}, force=f, raise_built=true} end)

  for _, n in ipairs({"bench-a","bench-b","bench-c","bench-d"}) do
    if not game.surfaces[n] then game.create_surface(n) end
  end

  local items = {"iron-plate","copper-plate","steel-plate","iron-gear-wheel","electronic-circuit",
    "advanced-circuit","stone-brick","coal","iron-ore","copper-ore","plastic-bar","sulfur",
    "concrete","pipe","rail","battery","copper-cable","engine-unit","low-density-structure","processing-unit"}
  local si = 0
  for _, surf in pairs(game.surfaces) do
    si = si + 1
    local ips = f.get_item_production_statistics(surf)
    for _, it in pairs(items) do
      ips.on_flow(it, 1000 * si)
      ips.on_flow(it, -100 * si)
    end
    local fps = f.get_fluid_production_statistics(surf)
    fps.on_flow("water", 500 * si)
    fps.on_flow("crude-oil", 300 * si)
    fps.on_flow("petroleum-gas", 200 * si)
    f.get_entity_build_count_statistics(surf).on_flow("medium-electric-pole", 100)
    f.get_kill_count_statistics(surf).on_flow("small-biter", 5 * si)
    game.get_pollution_statistics(surf).on_flow("assembling-machine-2", 10 * si)
  end
  local pole = s.find_entities_filtered{type = "electric-pole"}[1]
  if pole then
    pole.electric_network_statistics.on_flow("solar-panel", 5000)
    pole.electric_network_statistics.on_flow("radar", -2000)
  end
  log("BENCH-BUILDER: entities=" .. made .. " surfaces=" .. si)
end)
