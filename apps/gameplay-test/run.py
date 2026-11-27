#!/usr/bin/env python3
"""Drive the in-process gameplay test harness (.dca test ...) over SOAP.

    python apps/gameplay-test/run.py validate apps/gameplay-test/scenarios/*.json
    python apps/gameplay-test/run.py run harness-smoke.json dc-item-upgrade-stats.json \
        --report-dir K:/Dark-Chaos/Server/gameplay-tests/reports
    python apps/gameplay-test/run.py list | status [RUN_ID] | abort

`validate` is offline: it checks scenario files against the same rules the server
applies (minus the game-data lookups: spell, item, quest, creature and map ids are
checked by the server's `.dca test validate`). Everything else talks to a running
worldserver through SOAP, using SOAP.Enabled/SOAP.IP/SOAP.Port from the worldserver
config and the credentials in DC_SOAP_USER / DC_SOAP_PASSWORD. Credentials are never
printed or written anywhere.

Exit code: 0 every run passed, 1 a run failed or errored, 2 the runner could not do
its job (SOAP unreachable, invalid scenario, timeout).

The schema lives in README.md next to this file; the server-side validator is
src/server/scripts/DC/GameplayTest/GameplayTestSteps.cpp. Keep the three in step.
"""

import argparse
import base64
import json
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_CONFIG = Path("K:/Dark-Chaos/Server/configs/worldserver.conf")

EXIT_PASS = 0
EXIT_FAIL = 1
EXIT_INFRA = 2

# action -> keys it needs besides "action" (GameplayTestSteps.cpp: Actions()).
ACTIONS = {
    "teleport": [], "set_level": ["level"], "learn": ["spell"], "unlearn": ["spell"],
    "add_item": ["item"], "remove_item": ["item"], "equip": ["item"], "cast": ["spell"],
    "add_aura": ["spell", "target"], "remove_aura": ["spell", "target"],
    "spawn": ["id", "entry"], "spawn_object": ["id", "entry"], "despawn": ["target"],
    "kill": ["target"], "revive": [], "accept_resurrect": [], "set_health": ["target"],
    "set_power": ["target", "value"], "set_money": ["copper"], "quest_add": ["quest"],
    "quest_complete": ["quest"], "quest_remove": ["quest"], "item_upgrade": ["slot"],
    "prestige": [], "wait": [], "assert": ["metric"], "snapshot": ["metric", "save_as"],
    "log": ["message"],
}

# metric -> extra key it needs (GameplayTestSteps.cpp: Metrics()).
METRICS = {
    "health": "", "max_health": "", "health_pct": "", "power": "", "max_power": "", "level": "",
    "alive": "", "in_combat": "", "display_id": "", "native_display_id": "", "phase_mask": "",
    "map_id": "", "zone_id": "", "exists": "", "creature_alive": "", "aura": "spell",
    "aura_stacks": "spell", "aura_charges": "spell", "aura_duration_ms": "spell", "stat": "stat",
    "knows_spell": "spell", "item_count": "item", "equipped_item": "slot", "quest_status": "quest",
    "quest_rewarded": "quest", "money": "", "distance": "target", "resurrect_requested": "",
    "mplus_active": "", "mplus_keystone_level": "", "mplus_run_deaths": "",
    "mplus_can_activate": "target", "mplus_activation_error": "target", "battle_res_charges": "",
    "prestige_level": "", "prestige_refusal": "", "prestige_restart_level": "",
    "item_upgrade_level": "slot", "upgrade_currency": "currency",
}

COMPARATORS = ("equals", "not_equals", "min", "max", "contains", "not_contains")
STATS = ("strength", "agility", "stamina", "intellect", "spirit")
CURRENCIES = ("token", "essence", "sap")
IDENT = re.compile(r"^[a-z0-9_-]{1,32}$")
SAFE_NAME = re.compile(r"^[A-Za-z0-9_./-]+\.json$")


# --------------------------------------------------------------------------
# Offline validation
# --------------------------------------------------------------------------

class ScenarioError(Exception):
    pass


def _no_duplicate_keys(pairs):
    seen = {}
    for key, value in pairs:
        if key in seen:
            raise ScenarioError(f"duplicate key \"{key}\"")
        seen[key] = value
    return seen


def load_scenario(path):
    try:
        text = Path(path).read_text(encoding="utf-8-sig")
    except OSError as exc:
        raise ScenarioError(f"cannot read: {exc}") from exc
    try:
        return json.loads(text, object_pairs_hook=_no_duplicate_keys)
    except json.JSONDecodeError as exc:
        raise ScenarioError(f"line {exc.lineno}, column {exc.colno}: {exc.msg}") from exc


def _is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _check_ref(ctx, step, key, actor_only):
    if key not in step:
        return
    ref = step[key]
    if not isinstance(ref, str):
        raise ScenarioError(f"\"{key}\" must be a string reference")
    if ref in ctx["actors"] or (not actor_only and ref in ctx["spawns"]):
        return
    kind = "actor" if actor_only else "reference"
    raise ScenarioError(f"\"{key}\": unknown {kind} '{ref}'")


def _check_metric(ctx, spec, assertion):
    metric = spec.get("metric")
    if metric not in METRICS:
        raise ScenarioError(f"unknown metric '{metric}'")
    needed = METRICS[metric]
    if needed and needed not in spec:
        raise ScenarioError(f"metric '{metric}' needs \"{needed}\"")
    if metric == "stat" and spec.get("stat") not in STATS:
        raise ScenarioError("\"stat\" must be one of " + ", ".join(STATS))
    if metric == "upgrade_currency" and spec.get("currency") not in CURRENCIES:
        raise ScenarioError("\"currency\" must be one of " + ", ".join(CURRENCIES))
    for key in ("unit", "target", "caster"):
        _check_ref(ctx, spec, key, False)
    if "relative_to" in spec and spec["relative_to"] not in ctx["vars"]:
        raise ScenarioError("\"relative_to\" must name a value saved by an earlier snapshot")
    if not assertion:
        return
    present = [key for key in COMPARATORS if key in spec]
    if not present:
        raise ScenarioError("an assertion needs one of " + ", ".join(COMPARATORS))
    for key in present:
        value = spec[key]
        if "contains" in key and not isinstance(value, str):
            raise ScenarioError(f"\"{key}\" must be a string")
        if key in ("min", "max") and not _is_number(value):
            raise ScenarioError(f"\"{key}\" must be a number")
        if key in ("equals", "not_equals") and not isinstance(value, (int, float, str, bool)):
            raise ScenarioError(f"\"{key}\" must be a number, string or boolean")


def _check_step(ctx, step):
    if not isinstance(step, dict):
        raise ScenarioError("a step must be an object")
    action = step.get("action")
    if action not in ACTIONS:
        raise ScenarioError(f"unknown action '{action}'")
    for key in ACTIONS[action]:
        if key not in step:
            raise ScenarioError(f"action '{action}' needs \"{key}\"")
    if "timeout_ms" in step and (not _is_number(step["timeout_ms"]) or step["timeout_ms"] < 0):
        raise ScenarioError("\"timeout_ms\" must be a non-negative number")
    _check_ref(ctx, step, "actor", True)

    if action in ("assert", "snapshot"):
        _check_metric(ctx, step, action == "assert")
        if action == "snapshot":
            if not IDENT.match(str(step.get("save_as", ""))):
                raise ScenarioError("\"save_as\" must be a lower-case identifier")
            ctx["vars"].add(step["save_as"])
        return

    if action == "wait":
        if "ms" not in step and "until" not in step:
            raise ScenarioError("wait needs \"ms\" or \"until\"")
        if "until" in step:
            if not isinstance(step["until"], dict):
                raise ScenarioError("\"until\" must be an assertion object")
            try:
                _check_metric(ctx, step["until"], True)
            except ScenarioError as exc:
                raise ScenarioError(f"until: {exc}") from exc
        return

    for key in ("target", "caster"):
        _check_ref(ctx, step, key, False)
    if "slot" in step and (not _is_number(step["slot"]) or not 0 <= step["slot"] <= 18):
        raise ScenarioError("slot must be an equipment slot 0-18")

    if action == "teleport":
        if not all(k in step for k in ("map", "x", "y", "z")) and "to" not in step:
            raise ScenarioError("teleport needs map/x/y/z or \"to\"")
        _check_ref(ctx, step, "to", False)
    elif action in ("spawn", "spawn_object"):
        sid = step.get("id", "")
        if not IDENT.match(str(sid)) or sid in ctx["actors"] or sid in ctx["spawns"]:
            raise ScenarioError("\"id\" must be a new lower-case identifier")
        ctx["spawns"].add(sid)
    elif action in ("add_item", "remove_item"):
        count = step.get("count", 1)
        if not _is_number(count) or not 1 <= count <= 1000:
            raise ScenarioError("count must be 1-1000")
    elif action == "prestige" and not ctx["destructive"]:
        raise ScenarioError("prestige changes persistent progression; mark the scenario \"destructive\": true")
    elif action == "set_health" and "pct" not in step and "value" not in step:
        raise ScenarioError("set_health needs \"pct\" or \"value\"")


def validate_scenario(data, max_actors=5):
    if not isinstance(data, dict):
        raise ScenarioError("the scenario must be a JSON object")
    if data.get("schema") != 1:
        raise ScenarioError("\"schema\" must be 1")
    if not data.get("name"):
        raise ScenarioError("\"name\" is required")
    location = data.get("location")
    if location is not None and (not isinstance(location, dict) or
                                 not all(k in location for k in ("map", "x", "y", "z"))):
        raise ScenarioError("\"location\" needs map, x, y and z")

    actors = data.get("actors")
    if not isinstance(actors, list) or not actors:
        raise ScenarioError("\"actors\" must be a non-empty array")
    if len(actors) > max_actors:
        raise ScenarioError(f"more than {max_actors} actors (DC.GameplayTest.MaxActors default)")

    ctx = {"actors": set(), "spawns": set(), "vars": set(), "destructive": bool(data.get("destructive"))}
    names = set()
    for actor in actors:
        aid = actor.get("id", "") if isinstance(actor, dict) else ""
        if not IDENT.match(str(aid)) or aid in ctx["actors"]:
            raise ScenarioError("every actor needs a unique lower-case \"id\"")
        name = actor.get("name")
        if not name or name in names:
            raise ScenarioError(f"actor {aid}: every actor needs a unique character \"name\"")
        names.add(name)
        if actor.get("session", "auto") not in ("auto", "headless", "online"):
            raise ScenarioError(f"actor {aid}: \"session\" must be auto, headless or online")
        create = actor.get("create")
        if create is not None and (not isinstance(create, dict) or "race" not in create or "class" not in create):
            raise ScenarioError(f"actor {aid}: \"create\" needs race and class")
        ctx["actors"].add(aid)

    steps = data.get("steps")
    if not isinstance(steps, list) or not 1 <= len(steps) <= 500:
        raise ScenarioError("\"steps\" must be an array of 1-500 steps")
    for index, step in enumerate(steps):
        try:
            _check_step(ctx, step)
        except ScenarioError as exc:
            action = step.get("action", "?") if isinstance(step, dict) else "?"
            raise ScenarioError(f"step {index} ({action}): {exc}") from exc


# --------------------------------------------------------------------------
# SOAP
# --------------------------------------------------------------------------

class InfraError(Exception):
    pass


def read_conf(path):
    values = {}
    try:
        lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return values
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"')
    return values


class Soap:
    ENVELOPE = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:AC">'
        "<SOAP-ENV:Body><ns1:executeCommand><command>{cmd}</command></ns1:executeCommand>"
        "</SOAP-ENV:Body></SOAP-ENV:Envelope>"
    )

    def __init__(self, args):
        conf = read_conf(args.config) if args.config else {}
        self.host = args.host or conf.get("SOAP.IP", "127.0.0.1")
        if self.host in ("0.0.0.0", ""):
            self.host = "127.0.0.1"
        self.port = int(args.port or conf.get("SOAP.Port", "7878"))
        self.enabled_in_conf = conf.get("SOAP.Enabled")
        self.user = os.environ.get("DC_SOAP_USER", "")
        self.password = os.environ.get("DC_SOAP_PASSWORD", "")
        if not self.user or not self.password:
            raise InfraError("set DC_SOAP_USER and DC_SOAP_PASSWORD (an administrator account) in the environment")

    def command(self, cmd):
        if any(c in cmd for c in "\r\n") or len(cmd) > 512:
            raise InfraError("refusing a malformed command")
        body = self.ENVELOPE.format(
            cmd=cmd.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")).encode("utf-8")
        request = urllib.request.Request(f"http://{self.host}:{self.port}/", data=body, method="POST")
        token = base64.b64encode(f"{self.user}:{self.password}".encode("utf-8")).decode("ascii")
        request.add_header("Authorization", f"Basic {token}")
        request.add_header("Content-Type", "text/xml; charset=utf-8")
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                status, payload = response.status, response.read()
        except urllib.error.HTTPError as exc:
            status, payload = exc.code, exc.read()
        except OSError as exc:
            hint = ""
            if self.enabled_in_conf == "0":
                hint = " (SOAP.Enabled = 0 in the config: enable it and restart the worldserver)"
            raise InfraError(f"cannot reach SOAP at {self.host}:{self.port}: {exc}{hint}") from exc

        if status == 401:
            raise InfraError("SOAP refused the credentials (401)")
        if status == 403:
            raise InfraError("the SOAP account is not an administrator (403)")
        result = self._text_of(payload, "result")
        if result is not None:
            return True, result.splitlines()
        fault = self._text_of(payload, "faultstring")
        if fault is not None:
            return False, fault.splitlines()
        raise InfraError(f"unexpected SOAP response (HTTP {status})")

    @staticmethod
    def _text_of(payload, name):
        try:
            root = ET.fromstring(payload)
        except ET.ParseError:
            return None
        for element in root.iter():
            if element.tag.rsplit("}", 1)[-1] == name:
                return element.text or ""
        return None


def parse_fields(line):
    fields = {}
    for match in re.finditer(r'(\w+)=("([^"]*)"|\S+)', line):
        fields[match.group(1)] = match.group(3) if match.group(3) is not None else match.group(2)
    return fields


def gameplay_lines(lines):
    return [line for line in lines if line.startswith("GAMEPLAYTEST")]


# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------

def server_name(path_text, scenario_root):
    """Name the server knows the scenario by: its path relative to the scenario root."""
    path = Path(path_text)
    if path.exists():
        try:
            return path.resolve().relative_to(scenario_root.resolve()).as_posix()
        except ValueError:
            return path.name
    return path_text.replace("\\", "/")


def cmd_validate(args):
    bad = 0
    for item in args.scenarios:
        try:
            validate_scenario(load_scenario(item))
            print(f"ok      {item}")
        except ScenarioError as exc:
            bad += 1
            print(f"INVALID {item}: {exc}")
    return EXIT_INFRA if bad else EXIT_PASS


def run_one(soap, name, args, out_dir):
    ok, lines = soap.command(f".dca test validate {name}")
    if not ok:
        print(f"  server refused {name}: {' '.join(lines)}")
        return "invalid", None

    ok, lines = soap.command(f".dca test run {name}")
    started = parse_fields(" ".join(gameplay_lines(lines)))
    run_id = started.get("run_id")
    if not ok or not run_id:
        print(f"  could not start {name}: {' '.join(lines)}")
        return "error", None
    print(f"  run_id {run_id}")

    deadline = time.monotonic() + args.wait_timeout
    status_lines = []
    while True:
        time.sleep(args.poll)
        ok, status_lines = soap.command(f".dca test status {run_id}")
        head = gameplay_lines(status_lines)
        fields = parse_fields(head[0]) if head else {}
        if fields.get("state") == "finished":
            break
        if time.monotonic() > deadline:
            soap.command(".dca test abort")
            print(f"  no result after {args.wait_timeout} s, aborted")
            return "timeout", run_id

    result = fields.get("result", "error")
    for line in status_lines[1:]:
        print("  " + line.strip())

    report = None
    if args.report_dir:
        source = Path(args.report_dir) / f"{run_id}.json"
        if source.is_file():
            report = out_dir / source.name
            shutil.copyfile(source, report)
        else:
            print(f"  report not found at {source}")
    elif fields.get("report", "none") != "none":
        print(f"  report (server side): {fields['report']}")

    print(f"  -> {result}" + (f"  ({report})" if report else ""))
    return result, run_id


def cmd_run(args):
    scenario_root = Path(args.scenario_root)
    names = []
    for item in args.scenarios:
        if Path(item).is_file():
            try:
                validate_scenario(load_scenario(item))
            except ScenarioError as exc:
                print(f"INVALID {item}: {exc}")
                return EXIT_INFRA
        name = server_name(item, scenario_root)
        if not SAFE_NAME.match(name) or ".." in name:
            print(f"INVALID scenario name {name}")
            return EXIT_INFRA
        names.append((item, name))

    if args.sync_to:
        target = Path(args.sync_to)
        for item, name in names:
            if Path(item).is_file():
                destination = target / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(item, destination)
        print(f"synced {len(names)} scenario(s) to {target}")

    soap = Soap(args)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    out_dir = Path(args.out) / stamp
    out_dir.mkdir(parents=True, exist_ok=True)

    summary = []
    worst = EXIT_PASS
    for _, name in names:
        print(f"{name}")
        result, run_id = run_one(soap, name, args, out_dir)
        summary.append({"scenario": name, "run_id": run_id, "result": result})
        if result in ("invalid", "timeout"):
            worst = max(worst, EXIT_INFRA)
        elif result != "pass":
            worst = max(worst, EXIT_FAIL)

    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    passed = sum(1 for entry in summary if entry["result"] == "pass")
    print(f"{passed}/{len(summary)} passed; summary in {out_dir / 'summary.json'}")
    return worst


def cmd_simple(args, command):
    soap = Soap(args)
    ok, lines = soap.command(command)
    for line in lines:
        print(line)
    return EXIT_PASS if ok else EXIT_FAIL


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--config", default=os.environ.get("DC_WORLDSERVER_CONF", str(DEFAULT_CONFIG)),
                        help="worldserver.conf to read SOAP.Enabled/IP/Port from")
    parser.add_argument("--host", help="SOAP host (overrides the config)")
    parser.add_argument("--port", help="SOAP port (overrides the config)")
    sub = parser.add_subparsers(dest="command", required=True)

    p_validate = sub.add_parser("validate", help="offline schema check")
    p_validate.add_argument("scenarios", nargs="+")

    p_run = sub.add_parser("run", help="run scenarios on the server and collect reports")
    p_run.add_argument("scenarios", nargs="+",
                       help="scenario names inside DC.GameplayTest.ScenarioDir, or local files under --scenario-root")
    p_run.add_argument("--scenario-root", default=str(HERE / "scenarios"))
    p_run.add_argument("--sync-to", help="copy the local scenario files into this directory first "
                                         "(the server's DC.GameplayTest.ScenarioDir)")
    p_run.add_argument("--report-dir", help="the server's DC.GameplayTest.OutputDir, as seen from here")
    p_run.add_argument("--out", default=str(HERE / "results"))
    p_run.add_argument("--wait-timeout", type=int, default=900, help="seconds to wait for one run")
    p_run.add_argument("--poll", type=float, default=1.0, help="seconds between status polls")

    sub.add_parser("list", help="scenarios the server can see")
    p_status = sub.add_parser("status", help="active run or a finished run's result")
    p_status.add_argument("run_id", nargs="?")
    sub.add_parser("abort", help="abort the active run")

    args = parser.parse_args(argv)
    try:
        if args.command == "validate":
            return cmd_validate(args)
        if args.command == "run":
            return cmd_run(args)
        if args.command == "list":
            return cmd_simple(args, ".dca test list")
        if args.command == "status":
            return cmd_simple(args, ".dca test status" + (f" {args.run_id}" if args.run_id else ""))
        return cmd_simple(args, ".dca test abort")
    except InfraError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_INFRA


if __name__ == "__main__":
    sys.exit(main())
