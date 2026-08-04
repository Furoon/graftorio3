# Vendored Prometheus library

## Origin

This directory contains a vendored copy of the Prometheus client from
**[tarantool/metrics](https://github.com/tarantool/metrics)**, licensed
BSD 2-Clause (see `LICENSE`, copyright 2010-2018 Tarantool AUTHORS, see
`AUTHORS`).

It reached graftorio3 by inheritance: the original graftorio vendored it, and
every fork since carried it along. The upstream version it was taken from was
never recorded, and the code has been modified in the meantime (Lua
annotations were added, and the Factorio ports adjusted it), so it can no
longer be diffed cleanly against any upstream tag. Treat this copy as a fork,
not as a pinned dependency.

## Local modifications

- **Removed `init()`** and its export. It called
  `require("prometheus.tarantool-metrics")`, a module that was never part of
  the vendored subset, so any caller would have hit a load error. It was
  publicly exported, which made it a live landmine rather than dead code --
  including for mods using the graftorio3 remote interface.
- Lua language-server annotations were added by earlier forks.

## What is used

graftorio3 uses `counter`, `gauge`, `histogram` and `collect`. `collect_http`
is retained but unused: it returns a Tarantool HTTP-server response envelope,
which has no meaning in Factorio. `clear` is retained and unused.

## If you are considering replacing it

The exposition format this produces is validated by `promtool` in the runtime
verification CI job, so a replacement has an executable acceptance test. The
parts that matter are label escaping (station names and instance labels can
contain quotes and backslashes) and histogram bucket serialisation, which the
train metrics depend on.
