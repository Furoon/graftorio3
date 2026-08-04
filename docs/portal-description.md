# graftorio3

**See what your factory is actually doing — in Grafana, live, from your own server.**

graftorio3 writes your factory's numbers to a file that Prometheus can read: what
you're producing and consuming, how much power you're drawing, what your bots and
trains are up to, how research is coming along, how bad the pollution has gotten,
and which machines are sitting idle waiting for something.

If you already run Grafana and Prometheus, you're about five minutes away from
having your factory on a dashboard next to everything else you monitor.

## What you get

- **Production and consumption** for every item and fluid, per surface
- **Power** per electric network
- **Machine status** — how many assemblers are working, out of power, starved for
  ingredients, or backed up with a full output. This is the one that tells you
  *where* the factory is stalling, not just *that* it is.
- **Trains** — trip times, waiting times, time between arrivals at a station
- **Logistics** — bots in use, bots available, items in the network
- **Research** — current queue and progress, technologies completed
- **Pollution and evolution** per surface
- **Rockets launched**, items sent to space, kill and build counts
- **Space Age** — platform state, weight, speed, distance travelled
- Plus server-level things like tick rate, pause state and player time

## Setting it up

Install the mod, and it starts writing metrics to
`script-output/graftorio3/game.prom` inside your Factorio data folder.

Most people already run **node_exporter** on their server. If that's you, just
point its textfile collector at the folder:

```
--collector.textfile.directory=/path/to/factorio/script-output/graftorio3
```

That's it — no extra container, no extra port, no agent to keep running. The
metrics show up alongside your CPU and memory graphs.

Not sure it's working? Type `/graftorio3` in the server console or in-game. It
tells you when it last collected data, where it's writing, which surfaces it's
watching, and whether anything went wrong.

Full setup guide, ready-made Grafana alerts and Prometheus rules:
https://github.com/Furoon/graftorio3

## Running a big base or Space Age?

Some sensible defaults are already in place, and you can tune the rest in the mod
settings:

- Collection is spread across ticks, so there's no periodic stutter
- Space platforms are **not** collected by default — every platform is its own
  surface and they add up fast. Turn them on if you want them.
- You can restrict collection to specific surfaces
- Train IDs are left out of the metrics by default, because they multiply your
  data enormously on a big rail network. Turn them on if you want per-train
  detail.
- Machine status scanning has a configurable limit so it can't run away on a
  megabase

## Running more than one server?

Give each one an instance name and its own output file name in the settings, and
they can all report into the same Prometheus without stepping on each other.

## Writing a mod?

graftorio3 can publish your mod's metrics too — register through its remote
interface and your numbers land in the same file with the same handling as
everything else. No second exporter needed. Details in the readme.

## Credits

This is a fork, standing on a lot of prior work: **graftorio** by afex,
**graftorio2** by remijouannet, and jahands' fork which added circuit network and
Space Age metrics. graftorio3 continues from there — updated for Factorio 2.1,
with fixes for dedicated servers, surface filtering and a good deal of tuning for
large bases.

MIT licensed. Bug reports and ideas welcome on GitHub.
