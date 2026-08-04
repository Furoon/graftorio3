# Contributing

## Prerequisites

- `lua` and `luacheck` (`sudo apt install lua5.1 luarocks && sudo luarocks install luacheck`)
- `python3` for the generator and verification scripts
- A Factorio headless build for local testing
- Optionally `promtool` to validate the exposition format

There is no package manager step: the mod has no build dependencies and the
Prometheus library is vendored under `prometheus/`.

## Repository layout

The repository contains more than the mod. `scripts/package.sh` uses an
explicit allowlist, so only the files listed there ever reach the published
zip -- Grafana dashboards (`config/`, `data/`), Docker compose files, CI
configuration and `tools/` are development material and stay out of it.

**Adding a new Lua module means adding it to the allowlist in
`scripts/package.sh`.** Forgetting this produces a zip that fails to load at
runtime with `module ... not found`, which the CI smoke test will catch but
your local editor will not.

## Generated files

Two files are generated and must not be edited by hand:

| File | Generator | Enforced by |
| --- | --- | --- |
| `Metrics.md` | `scripts/gen_metrics.py` | CI drift check |
| `.luacheckrc` | `scripts/gen_luacheckrc.py` | zero-warning policy |

After changing metric definitions or adding cross-module globals:

```sh
python3 scripts/gen_metrics.py
python3 scripts/gen_luacheckrc.py
```

## Local checks

```sh
luacheck .                                  # must be 0 warnings, 0 errors
python3 scripts/gen_metrics.py --check      # Metrics.md is up to date
./scripts/package.sh                        # builds dist/<name>_<version>.zip
```

Runtime verification against a real headless server:

```sh
python3 tools/verify/verify.py <factorio-binary> <save> --promtool ./promtool
```

`tools/bench-builder/` generates a deterministic multi-surface world used by
the CI benchmark job.

## CI

Four jobs run on every push:

1. **lint-and-package** -- luacheck, `Metrics.md` drift check, allowlist
   packaging, and a gate that fails if development files reached the zip
2. **headless-smoke** -- the packaged zip must load in a real Factorio
3. **benchmark-regression** -- collection overhead must stay within budget
4. **runtime-verification** -- a real server must actually produce the
   expected metric families, plus a negative control that sabotages a
   collector stage and requires the harness to fail

## Releasing

Releases are tag-driven. Update `info.json` and `changelog.txt` to the same
version, then push a `vX.Y.Z` tag. The release workflow verifies that tag,
`info.json` and the newest changelog entry agree, packages, smoke-tests,
uploads to the mod portal and creates a GitHub release.

## Adding a metric

1. Define it in `control.lua` next to the related metrics.
2. Populate it in the appropriate module, or add a new module and register it
   as a stage in `collection_stages`.
3. Add the module to the packaging allowlist if it is new.
4. Regenerate `Metrics.md` and `.luacheckrc`.
5. Consider cardinality: a label whose values are unbounded (player names,
   train IDs, station names) belongs behind a setting.
