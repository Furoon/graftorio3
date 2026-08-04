#!/usr/bin/env python3
"""Runtime verification: start a real headless server with the packaged mod
and assert that metrics are actually produced.

CI checks that the mod loads and that it is fast enough. This checks that it
WORKS: that the collection cycle runs, that every expected metric family is
written, that the exposition format is valid, and that a failing collector
stage degrades one family instead of taking down the server.

Usage: verify.py <factorio-binary> <save> [--promtool PATH]
"""
import subprocess, sys, time, os, shutil, pathlib, argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rcon import Rcon

# Families that must be present on an idle, player-less dedicated server.
# This is the regression net: the game.players bug fixed in 1.1.0 made
# exactly these disappear, and nothing but a running server catches it.
REQUIRED = [
    "factorio_tick",
    "factorio_game_speed",
    "factorio_ticks_played",
    "factorio_technologies_researched",
    "factorio_technologies_available",
    "factorio_evolution",
    "factorio_surface_pollution",
    "factorio_entities",
    "factorio_peaceful_mode",
    "factorio_solar_power_multiplier",
    "factorio_exporter_series",
    "factorio_exporter_last_collection_tick",
]

failures = []


def check(condition, message):
    if condition:
        print(f"  OK   {message}")
    else:
        print(f"  FAIL {message}")
        failures.append(message)


def run_server(binary, save, port, script_output, settle=45):
    """Start the server, let it produce at least one collection, return the log."""
    shutil.rmtree(script_output, ignore_errors=True)
    log_path = "verify-server.log"
    log = open(log_path, "wb")
    proc = subprocess.Popen(
        [binary, "--start-server", save, "--server-settings",
         "verify-server-settings.json", "--rcon-port", str(port),
         "--rcon-password", "verifypw"],
        stdin=subprocess.PIPE, stdout=log, stderr=subprocess.STDOUT)
    conn = None
    for _ in range(60):
        time.sleep(1)
        try:
            conn = Rcon("127.0.0.1", port, "verifypw")
            break
        except Exception:
            pass
    if conn is None:
        proc.kill()
        log.close()
        raise SystemExit("RCON kam nicht hoch")

    time.sleep(settle)

    # Query diagnostics AFTER the settle period: before the first collection
    # it reports "no collection yet" and no error counts, which is useless.
    diagnostics = ""
    try:
        diagnostics = conn.cmd("/graftorio3").strip()
    except Exception:
        pass

    try:
        proc.stdin.write(b"/quit\n")
        proc.stdin.flush()
    except Exception:
        pass
    time.sleep(2)
    proc.terminate()
    try:
        proc.wait(timeout=25)
    except Exception:
        proc.kill()
    log.close()
    return pathlib.Path(log_path).read_text(encoding="utf-8", errors="replace"), diagnostics


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("binary")
    parser.add_argument("save")
    parser.add_argument("--promtool", default=None)
    parser.add_argument("--output-dir", default="factorio/script-output/graftorio3")
    parser.add_argument("--fault", action="store_true",
                        help="expect a broken collector stage")
    args = parser.parse_args()

    pathlib.Path("verify-server-settings.json").write_text(
        '{"name":"verify","description":"verify","visibility":{"public":false,"lan":false},'
        '"require_user_verification":false,"allow_commands":"true","auto_pause":false}',
        encoding="utf-8")

    print("Server starten und Sammelzyklus abwarten...")
    log, diagnostics = run_server(args.binary, args.save, 27099, args.output_dir)

    if diagnostics:
        print("--- /graftorio3 ---")
        for line in diagnostics.splitlines():
            print("   " + line)

    prom = pathlib.Path(args.output_dir) / "game.prom"
    check(prom.exists(), "Metrikdatei wurde geschrieben")
    if not prom.exists():
        raise SystemExit(1)

    text = prom.read_text(encoding="utf-8", errors="replace")
    families = {line.split()[2] for line in text.splitlines() if line.startswith("# TYPE")}
    print(f"  ({len(families)} Metrikfamilien, {len(text)} Bytes)")

    if args.fault:
        # A stage was deliberately broken: the file must still be written and
        # the failure must be visible as a metric, not as a dead server.
        check("factorio_collector_errors_total" in families,
              "Fehlerzaehler meldet die defekte Stage")
        check(len(families) > 5, "uebrige Stages sammeln weiter")
    else:
        for family in REQUIRED:
            check(family in families, f"Familie vorhanden: {family}")

    lua_errors = [l for l in log.splitlines()
                  if ("Error" in l and "InterruptibleStdio" not in l)
                  or "attempt to" in l or "doesn't contain key" in l]
    check(not lua_errors, "keine Lua-Fehler im Serverlog")
    for line in lua_errors[:5]:
        print("       " + line.strip()[:150])

    if args.promtool:
        result = subprocess.run([args.promtool, "check", "metrics"],
                                stdin=open(prom), capture_output=True, text=True)
        check(result.returncode == 0, "promtool akzeptiert das Format")
        if result.returncode != 0:
            print("       " + result.stderr.strip()[:300])

    if failures:
        print(f"\n{len(failures)} Pruefung(en) fehlgeschlagen")
        raise SystemExit(1)
    print("\nAlle Laufzeitpruefungen bestanden")


if __name__ == "__main__":
    main()
