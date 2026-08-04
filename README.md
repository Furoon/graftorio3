# graftorio3

**Prometheus metrics for your Factorio server — ported to Factorio 2.1, built for headless dedicated servers.**

graftorio3 exports what your factory is doing — production, power, logistics,
trains, research, evolution, circuit signals, space platforms — as native
[Prometheus](https://prometheus.io/) text format, written straight to
`script-output/graftorio3/game.prom` every few seconds. Point a
[node_exporter textfile collector](https://github.com/prometheus/node_exporter#textfile-collector)
at it and your factory shows up in Grafana next to your CPU graphs, where it
belongs.

No sidecar process. No agent. No RCON polling. The mod writes, Prometheus scrapes.

## Factorio 2.1

This fork runs on **Factorio 2.1** (Space Age included) and is verified against
the 2.1 runtime API. The APIs that 2.1 removed (`LuaEntity.neighbours`,
`disconnect_neighbour()`) have been replaced with the `LuaWireConnector` API,
and a set of long-standing silent failures are fixed — most of them only
visible on the exact setup this mod is for:

* Metric collection iterated `game.players` instead of `game.forces`, so a
  **dedicated server nobody had joined yet collected almost nothing**.
* Build/destroy events were registered twice; Factorio keeps one handler per
  event per mod, so all power build/destroy tracking was silently dead.
* `factorio_items_launched` was always empty, quality labels always reported
  `"normal"`, and multi-force setups wiped each other's research series.

## Surface filtering (Space Age)

Every space platform is its own surface. On a mature Space Age save that
multiplies per-surface collection work and Prometheus label cardinality.
Two startup settings keep this under control:

| Setting | Default | Effect |
|---|---|---|
| `graftorio3-surface-filter` | *(empty)* | Comma-separated surface allowlist. Empty = all surfaces. |
| `graftorio3-include-platforms` | off | Collect metrics for space platform surfaces. |
| `graftorio3-nth-tick` | 300 | How often (in ticks) metrics are written. |
| `graftorio3-disable-train-stats` | off | Train histograms carry `train_id`/station labels — disable on megabases if cardinality bites. |

On a 5-surface benchmark map, restricting collection to one surface cut the
series count from 313 to 77 and roughly halved collection cost. A full
collection cycle costs about 4–8 ms on modest hardware — a comparable
prototype-iterating exporter costs ~45 ms per cycle on the same map.

## Installation

**Server (recommended path):**

1. Install `graftorio3` from the [mod portal](https://mods.factorio.com/mod/graftorio3)
   (or drop the release zip into your server's `mods/` folder).
2. Make `script-output/graftorio3/` readable by your node_exporter and add:
   ```
   --collector.textfile.directory=/path/to/factorio/script-output/graftorio3
   ```
3. Metrics appear as `factorio_*` on your existing node_exporter scrape target.

**All-in-one (Grafana + Prometheus via Docker):** the repository ships a
`docker-compose.yml` and pre-built Grafana dashboards under `config/` for a
self-contained local stack. This is a development/convenience setup — none of
it is part of the mod zip.

See [Metrics.md](Metrics.md) for the full list of exported metric families.

## Publishing metrics from your own mod

Other mods can expose their metrics through graftorio3 rather than shipping
a second exporter. Register in both `on_init` and `on_load` (prometheus state
is rebuilt on every load), then set values from any handler:

```lua
local function register()
  if not remote.interfaces["graftorio3"] then return end
  remote.call("graftorio3", "register_gauge",
    "mymod_widgets", "widgets produced", { "surface" })
end
script.on_init(register)
script.on_load(register)

script.on_nth_tick(300, function()
  remote.call("graftorio3", "set", "mymod_widgets", 42, { "nauvis" })
end)
```

Names are validated and namespaced to `factorio_*`, registration is
idempotent, and every call returns `ok, error_message`. `register_counter`
and `inc` exist for counters; `api_version` allows feature detection.

## Fork lineage

This is a fork, standing on a lot of prior work:

* [graftorio](https://github.com/afex/graftorio) by afex — the original idea
* [graftorio2](https://github.com/remijouannet/graftorio2) by remijouannet — the 1.1/2.0 era maintenance
* [jahands/graftorio2](https://github.com/jahands/graftorio2) — circuit network metrics, Space Age platform metrics, tooling

graftorio3 continues from jahands' tree: ported to Factorio 2.1, renamed to
avoid setting conflicts with installed graftorio2 variants, with the
dedicated-server fixes above, surface filtering, and an allowlist-based
release pipeline that guarantees the published mod zip contains the mod and
nothing else.

## Development

CI runs luacheck, an allowlist packaging dry-run with a forbidden-content
gate, and a Factorio headless smoke test on every push. Releases are
tag-driven: pushing `vX.Y.Z` verifies tag == `info.json` == changelog, builds
the zip, smoke-tests it, uploads it to the mod portal and attaches it to a
GitHub release. See `scripts/` and `.github/workflows/`.

## License

MIT, same as its ancestors. See [LICENSE](LICENSE).
