#!/usr/bin/env python3
"""dc_bugreport_relay.py - turn queued in-game bug reports into GitHub issues.

The worldserver (src/server/scripts/DC/LabTools/dc_bug_report.cpp) appends one JSON line per
accepted /dcbug report to its spool file (DC.BugReport.SpoolFile). This relay reads that file,
keeps a SQLite journal next to it and creates one GitHub issue per report through the REST API.
It is a separate process: the game server makes no HTTP call and never sees a GitHub token.

    python dc_bugreport_relay.py --spool <spool.jsonl>                  # dry run (default)
    python dc_bugreport_relay.py --spool <spool.jsonl> --send           # create issues
    python dc_bugreport_relay.py --spool <spool.jsonl> --send --watch 60
    python dc_bugreport_relay.py --spool <spool.jsonl> --status
    python dc_bugreport_relay.py --spool <spool.jsonl> --resolve <id> --issue 123   # after a manual check
    python dc_bugreport_relay.py --spool <spool.jsonl> --resolve <id> --abandon
    python dc_bugreport_relay.py --spool <spool.jsonl> --retry <id>                 # one uncertain id, by hand

Environment: GITHUB_TOKEN (or DC_BUGREPORT_GITHUB_TOKEN) and DC_BUGREPORT_REPO (owner/name; --repo
overrides). The token is read only with --send and is never printed or written anywhere.

Delivery rules (see README.md):
- the journal records `posting` and commits BEFORE each POST, so a crash mid-request leaves a
  trace; such an entry, and every timeout / 5xx / malformed success, becomes `uncertain` and is
  never re-sent automatically (GitHub has no idempotency key, a resend can duplicate the issue);
- 401/404/410 and non-rate-limit 403 mean the issue was not created: `blocked`, retried on the
  next run once the configuration is fixed; 422 is `failed` (GitHub refused the content);
- rate limits (429, 403 with X-RateLimit-Remaining: 0) and connection refusals leave the report
  pending and end the pass;
- one relay per spool (an OS lock on <journal>.lock), at least --min-interval seconds between posts.

Only whitelisted public fields reach the issue: the report text, category, server-side location
(map/zone/area names and coordinates), level/class/race, instance flag, client build and DC
fingerprint, locale, addon versions, Lua errors, core revision and the report id. The spool's
`private` block (account id, character guid) is never read. @-mentions are neutralised, IPv4/IPv6
addresses are redacted and the player's text is shown in a code block, so it cannot ping anyone,
embed images or inject HTML. Python 3.10+, standard library only.
"""
import argparse
import json
import os
import re
import socket
import sqlite3
import sys
import time
import urllib.error
import urllib.request

SPOOL_VERSION = 1
API_ROOT = "https://api.github.com"
USER_AGENT = "dc-bugreport-relay/1"
ID_RE = re.compile(r"^[0-9a-f]{1,16}-[0-9a-f]{1,8}-[0-9a-f]{4}$")
REPO_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
MENTION_RE = re.compile(r"@(?=[A-Za-z0-9_-])")
IPV4_RE = re.compile(r"(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])")
IPV6_RE = re.compile(r"(?<![0-9A-Fa-f:])(?:[0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{1,4}(?![0-9A-Fa-f:])")
WOW_LINK_RE = re.compile(r"\|H[^|]*\|h(.*?)\|h", re.S)
WOW_COLOR_RE = re.compile(r"\|c[0-9A-Fa-f]{8}|\|r")
CONTROL_RE = re.compile(r"[\x00-\x08\x0b-\x1f\x7f]")
CLASSES = {1: "Warrior", 2: "Paladin", 3: "Hunter", 4: "Rogue", 5: "Priest", 6: "Death Knight", 7: "Shaman",
           8: "Mage", 9: "Warlock", 11: "Druid"}
RACES = {1: "Human", 2: "Orc", 3: "Dwarf", 4: "Night Elf", 5: "Undead", 6: "Tauren", 7: "Gnome", 8: "Troll",
         10: "Blood Elf", 11: "Draenei"}

EXIT_OK, EXIT_ATTENTION, EXIT_USAGE, EXIT_LOCKED = 0, 1, 2, 3


# ---------------------------------------------------------------------------
# Spool
# ---------------------------------------------------------------------------

def read_spool(path):
    """Complete lines of the spool: (reports in file order, problems). A last line without its
    newline is still being written (or was cut by a crash) and is left for the next pass."""
    try:
        with open(path, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        return [], []
    lines = data.split(b"\n")
    reports, problems, seen = [], [], set()
    for number, raw in enumerate(lines[:-1], 1):
        if not raw.strip():
            continue
        try:
            record = json.loads(raw.decode("utf-8", errors="replace"))
        except ValueError as error:
            problems.append("line %d: not JSON (%s)" % (number, error))
            continue
        problem = validate(record)
        if problem:
            problems.append("line %d: %s" % (number, problem))
            continue
        if record["id"] in seen:
            problems.append("line %d: duplicate id %s" % (number, record["id"]))
            continue
        seen.add(record["id"])
        reports.append(record)
    return reports, problems


def validate(record):
    if not isinstance(record, dict):
        return "not an object"
    if record.get("v") != SPOOL_VERSION:
        return "unsupported version %r" % record.get("v")
    if not isinstance(record.get("id"), str) or not ID_RE.match(record["id"]):
        return "bad id"
    report = record.get("report")
    if not isinstance(report, dict) or not isinstance(report.get("title"), str) \
            or not isinstance(report.get("body"), str):
        return "missing report title/body"
    return None


# ---------------------------------------------------------------------------
# Issue text
# ---------------------------------------------------------------------------

def clean_text(text, limit=None):
    """Player text: WoW escapes resolved, control bytes dropped, mentions neutralised, IPs redacted."""
    text = str(text or "")
    text = WOW_LINK_RE.sub(r"\1", text)
    text = WOW_COLOR_RE.sub("", text)
    text = text.replace("||", "|")
    text = CONTROL_RE.sub("", text.replace("\r\n", "\n").replace("\r", "\n"))
    text = IPV4_RE.sub("[ip redacted]", text)
    # Full IPv6 addresses have 7 colons, short ones a "::"; clock times (12:30:45) have neither.
    text = IPV6_RE.sub(lambda m: "[ip redacted]" if "::" in m.group(0) or m.group(0).count(":") >= 5
                       else m.group(0), text)
    text = MENTION_RE.sub("@​", text)
    if limit is not None and len(text) > limit:
        text = text[:limit - 3] + "..."
    return text


def one_line(text, limit):
    return re.sub(r"\s+", " ", clean_text(text)).strip()[:limit]


def fenced(text, info="text"):
    """A code block that the text cannot close early."""
    longest = max((len(run) for run in re.findall(r"`+", text)), default=0)
    fence = "`" * max(3, longest + 1)
    return "%s%s\n%s\n%s" % (fence, info, text, fence)


def number(value, digits=1):
    try:
        return ("%." + str(digits) + "f") % float(value)
    except (TypeError, ValueError):
        return "?"


def compose_issue(record):
    """(title, body) from the whitelisted public fields of one spool record."""
    report = record.get("report") or {}
    context = record.get("context") or {}
    client = record.get("client") or {}
    core = record.get("core") or {}
    category = one_line(report.get("category") or "other", 16) or "other"
    title = "[In-game] %s: %s" % (category, one_line(report.get("title"), 160) or "(no title)")

    lines = [fenced(clean_text(report.get("body"), 6000)), "", "---", "", "| | |", "|---|---|"]

    def row(label, value):
        if value:
            lines.append("| %s | %s |" % (label, one_line(value, 300).replace("|", "\\|")))

    zone = context.get("zoneName") or client.get("zoneText")
    area = context.get("areaName") or client.get("subZoneText")
    location = ", ".join(part for part in (
        "%s (zone %s)" % (zone, context.get("zone")) if zone else None,
        "%s (area %s)" % (area, context.get("area")) if area and area != zone else None,
        "map %s %s" % (context.get("map"), context.get("mapName") or "") if "map" in context else None) if part)
    row("Category", category)
    row("Location", location)
    if "x" in context:
        row("Position", "x %s, y %s, z %s, o %s" % (number(context.get("x")), number(context.get("y")),
                                                    number(context.get("z")), number(context.get("o"), 2)))
    if "level" in context:
        row("Character", "level %s %s %s" % (context.get("level"), RACES.get(context.get("race"), "race %s"
                                                                              % context.get("race")),
                                             CLASSES.get(context.get("class"), "class %s" % context.get("class"))))
    if "instance" in context:
        row("Instance", "yes, difficulty %s" % context.get("difficulty") if context.get("instance") else "no")
    row("Client", ", ".join(str(x) for x in (client.get("build"), client.get("locale")) if x))
    if client.get("fingerprint"):
        row("Fingerprint", "`%s`" % one_line(client["fingerprint"], 96).replace("`", ""))
    row("Native caps", client.get("caps"))
    if core.get("hash"):
        row("Core", "%s (%s)" % (core.get("hash"), core.get("date") or "?"))
    submitted = record.get("ts")
    stamp = time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(submitted)) if isinstance(submitted, (int, float)) else "?"
    row("Report", "`%s`, submitted %s" % (record["id"], stamp))

    addons = [a for a in record.get("addons") or [] if isinstance(a, dict) and a.get("n")]
    if addons:
        lines += ["", "<details><summary>Addons (%d)</summary>" % len(addons), ""]
        lines.append(fenced("\n".join("%s %s" % (one_line(a.get("n"), 48), one_line(a.get("v") or "", 48))
                                      for a in addons[:64])))
        lines += ["", "</details>"]
    errors = [e for e in record.get("errors") or [] if isinstance(e, dict) and e.get("m")]
    if errors:
        lines += ["", "<details><summary>Lua errors (%d)</summary>" % len(errors), ""]
        lines.append(fenced("\n\n".join("%s(x%s)" % (clean_text(e.get("m"), 1500) + "\n", e.get("c") or 1)
                                        for e in errors[:5])))
        lines += ["", "</details>"]
    lines += ["", "_Filed from the game by the DarkChaos bug report relay._"]
    return title[:200], "\n".join(lines)


# ---------------------------------------------------------------------------
# Journal
# ---------------------------------------------------------------------------

SCHEMA = """CREATE TABLE IF NOT EXISTS reports (
    id TEXT PRIMARY KEY,
    state TEXT NOT NULL,
    issue INTEGER,
    url TEXT,
    attempts INTEGER NOT NULL DEFAULT 0,
    updated REAL NOT NULL,
    detail TEXT
)"""

FINAL_STATES = ("posted", "failed", "uncertain", "abandoned")


class Journal:
    def __init__(self, path, read_only=False):
        self.path = path
        if read_only:
            self.db = sqlite3.connect("file:%s?mode=ro" % path, uri=True) if os.path.exists(path) else None
        else:
            self.db = sqlite3.connect(path)
            self.db.execute(SCHEMA)
            self.db.commit()

    def close(self):
        if self.db:
            self.db.close()

    def get(self, report_id):
        if not self.db:
            return None
        row = self.db.execute("SELECT state, issue, url, attempts, detail FROM reports WHERE id = ?",
                              (report_id,)).fetchone()
        return dict(zip(("state", "issue", "url", "attempts", "detail"), row)) if row else None

    def set(self, report_id, state, issue=None, url=None, detail=None, attempt=False):
        self.db.execute(
            "INSERT INTO reports (id, state, issue, url, attempts, updated, detail) VALUES (?, ?, ?, ?, ?, ?, ?) "
            "ON CONFLICT(id) DO UPDATE SET state = excluded.state, issue = COALESCE(excluded.issue, issue), "
            "url = COALESCE(excluded.url, url), attempts = attempts + ?, updated = excluded.updated, "
            "detail = excluded.detail",
            (report_id, state, issue, url, 1 if attempt else 0, time.time(), detail, 1 if attempt else 0))
        self.db.commit()

    def delete(self, report_id):
        self.db.execute("DELETE FROM reports WHERE id = ?", (report_id,))
        self.db.commit()

    def recover_interrupted(self):
        """Entries left in `posting` by a process that died mid-request."""
        rows = [r[0] for r in self.db.execute("SELECT id FROM reports WHERE state = 'posting'")]
        for report_id in rows:
            self.set(report_id, "uncertain", detail="interrupted while posting; check GitHub before --resolve/--retry")
        return rows

    def counts(self):
        if not self.db:
            return {}
        return dict(self.db.execute("SELECT state, COUNT(*) FROM reports GROUP BY state").fetchall())

    def rows(self, states):
        if not self.db:
            return []
        marks = ",".join("?" * len(states))
        return self.db.execute("SELECT id, state, issue, url, attempts, detail FROM reports WHERE state IN (%s) "
                               "ORDER BY updated" % marks, tuple(states)).fetchall()


class SpoolLock:
    """One relay per spool: an exclusive, non-blocking OS lock on <journal>.lock."""

    def __init__(self, path):
        self.path = path
        self.handle = None

    def acquire(self):
        self.handle = open(self.path, "a+b")
        try:
            if os.name == "nt":
                import msvcrt
                self.handle.seek(0)
                msvcrt.locking(self.handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            self.handle.close()
            self.handle = None
            return False
        return True

    def release(self):
        if not self.handle:
            return
        try:
            if os.name == "nt":
                import msvcrt
                self.handle.seek(0)
                msvcrt.locking(self.handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.handle.fileno(), fcntl.LOCK_UN)
        finally:
            self.handle.close()
            self.handle = None


# ---------------------------------------------------------------------------
# GitHub
# ---------------------------------------------------------------------------

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise urllib.error.HTTPError(req.full_url, code, "redirect refused", headers, fp)


class Outcome:
    """What one POST did: kind is created / failed / blocked / retry_later / uncertain."""

    def __init__(self, kind, issue=None, url=None, detail="", wait=0):
        self.kind, self.issue, self.url, self.detail, self.wait = kind, issue, url, detail, wait


def classify_http_error(code, headers, body):
    message = ""
    try:
        message = str(json.loads(body or b"{}").get("message", ""))[:200]
    except ValueError:
        message = ""
    remaining = headers.get("X-RateLimit-Remaining") if headers else None
    retry_after = headers.get("Retry-After") if headers else None
    if code == 429 or (code == 403 and (remaining == "0" or "rate limit" in message.lower() or retry_after)):
        wait = 60
        if retry_after and str(retry_after).isdigit():
            wait = int(retry_after)
        elif headers and str(headers.get("X-RateLimit-Reset", "")).isdigit():
            wait = max(1, int(headers["X-RateLimit-Reset"]) - int(time.time()))
        return Outcome("retry_later", detail="rate limited: %s" % message, wait=min(wait, 3600))
    if code in (401, 403, 404, 410) or 300 <= code < 400:
        # Not created. A redirect (renamed/moved repository) is refused, never followed.
        return Outcome("blocked", detail="HTTP %d: %s" % (code, message))
    if code == 422:
        return Outcome("failed", detail="HTTP 422: %s" % message)
    return Outcome("uncertain", detail="HTTP %d: %s" % (code, message))


def github_post_issue(repo, token, title, body, labels=None, timeout=20):
    payload = {"title": title, "body": body}
    if labels:
        payload["labels"] = labels
    request = urllib.request.Request(
        "%s/repos/%s/issues" % (API_ROOT, repo), data=json.dumps(payload).encode("utf-8"), method="POST",
        headers={"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json",
                 "X-GitHub-Api-Version": "2022-11-28", "User-Agent": USER_AGENT,
                 "Content-Type": "application/json"})
    opener = urllib.request.build_opener(NoRedirect)
    try:
        with opener.open(request, timeout=timeout) as response:
            raw = response.read()
            code = response.status
    except urllib.error.HTTPError as error:
        return classify_http_error(error.code, error.headers, error.read() if error.fp else b"")
    except urllib.error.URLError as error:
        reason = error.reason
        if isinstance(reason, (ConnectionRefusedError, socket.gaierror)):
            return Outcome("retry_later", detail="not sent: %s" % type(reason).__name__, wait=60)
        return Outcome("uncertain", detail="network error after sending may have started: %s" % type(reason).__name__)
    except (TimeoutError, socket.timeout, ConnectionError, OSError) as error:
        return Outcome("uncertain", detail="%s while waiting for GitHub" % type(error).__name__)
    if code != 201:
        return Outcome("uncertain", detail="unexpected HTTP %d" % code)
    try:
        data = json.loads(raw)
        return Outcome("created", issue=int(data["number"]), url=str(data.get("html_url", "")))
    except (ValueError, KeyError, TypeError):
        return Outcome("uncertain", detail="201 without a readable issue number")


# ---------------------------------------------------------------------------
# Passes
# ---------------------------------------------------------------------------

def dry_run(spool, journal_path, verbose=False, out=print):
    reports, problems = read_spool(spool)
    journal = Journal(journal_path, read_only=True)
    try:
        todo = [r for r in reports if not journal.get(r["id"])]
        for record in todo:
            title, body = compose_issue(record)
            out("WOULD CREATE: %s" % title)
            if verbose:
                out(body)
                out("-" * 72)
        for problem in problems:
            out("SKIPPED %s" % problem)
        out("dry run: %d report(s) in the spool, %d not yet in the journal, %d unreadable line(s); "
            "nothing was sent or written" % (len(reports), len(todo), len(problems)))
    finally:
        journal.close()
    return EXIT_OK


def send_pass(spool, journal, repo, token, poster=github_post_issue, labels=None, min_interval=5.0,
              max_posts=20, sleep=time.sleep, out=print):
    """One pass over the spool. Returns (posted, attention, wait): attention counts reports left
    failed/blocked/uncertain by this pass, wait > 0 asks the caller to pause before the next pass."""
    reports, problems = read_spool(spool)
    for problem in problems:
        out("SKIPPED %s" % problem)
    posted = attention = 0
    last_post = None
    for record in reports:
        entry = journal.get(record["id"])
        if entry and entry["state"] in FINAL_STATES:
            continue
        if posted + attention >= max_posts:
            break
        if last_post is not None:
            delay = min_interval - (time.monotonic() - last_post)
            if delay > 0:
                sleep(delay)
        title, body = compose_issue(record)
        journal.set(record["id"], "posting", attempt=True, detail="POST in progress")
        last_post = time.monotonic()
        outcome = poster(repo, token, title, body, labels)
        if outcome.kind == "created":
            journal.set(record["id"], "posted", issue=outcome.issue, url=outcome.url, detail="")
            posted += 1
            out("POSTED %s -> #%s" % (record["id"], outcome.issue))
        elif outcome.kind == "retry_later":
            # Definitely not created (refused before the request or rate limited).
            if entry:
                journal.set(record["id"], entry["state"], detail=outcome.detail)
            else:
                journal.delete(record["id"])
            out("PAUSED at %s: %s" % (record["id"], outcome.detail))
            return posted, attention, max(1, outcome.wait)
        elif outcome.kind == "blocked":
            journal.set(record["id"], "blocked", detail=outcome.detail)
            attention += 1
            out("BLOCKED %s: %s (fix the token/repository; retried on the next run)" % (record["id"], outcome.detail))
            return posted, attention, 0
        else:
            journal.set(record["id"], outcome.kind, detail=outcome.detail)
            attention += 1
            out("%s %s: %s" % (outcome.kind.upper(), record["id"], outcome.detail))
    return posted, attention, 0


def print_status(journal, out=print):
    counts = journal.counts()
    out("journal: " + (", ".join("%s %d" % kv for kv in sorted(counts.items())) or "empty"))
    for report_id, state, issue, url, attempts, detail in journal.rows(("uncertain", "blocked", "failed")):
        out("  %-24s %-9s attempts=%d %s" % (report_id, state, attempts, detail or ""))
    return EXIT_ATTENTION if any(counts.get(s) for s in ("uncertain", "blocked", "failed")) else EXIT_OK


def resolve_env(args):
    repo = args.repo or os.environ.get("DC_BUGREPORT_REPO", "")
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("DC_BUGREPORT_GITHUB_TOKEN") or ""
    return repo, token


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--spool", default=os.environ.get("DC_BUGREPORT_SPOOL"), help="the spool file (DC.BugReport.SpoolFile)")
    ap.add_argument("--journal", help="SQLite journal (default: <spool>.journal.sqlite3)")
    ap.add_argument("--send", action="store_true", help="create issues (default: dry run, nothing sent or written)")
    ap.add_argument("--repo", help="owner/name (default: $DC_BUGREPORT_REPO)")
    ap.add_argument("--label", action="append", default=[], help="label for every issue (repeatable)")
    ap.add_argument("--watch", type=int, default=0, metavar="SECONDS", help="with --send: keep polling")
    ap.add_argument("--min-interval", type=float, default=5.0, help="seconds between two posts (default 5)")
    ap.add_argument("--max-per-pass", type=int, default=20)
    ap.add_argument("--verbose", action="store_true", help="dry run: print the full issue bodies")
    ap.add_argument("--status", action="store_true", help="print the journal summary")
    ap.add_argument("--resolve", metavar="ID", help="settle an uncertain/blocked/failed entry by hand")
    ap.add_argument("--issue", type=int, help="with --resolve: the issue number you found for it")
    ap.add_argument("--abandon", action="store_true", help="with --resolve: never post it")
    ap.add_argument("--retry", metavar="ID", help="re-queue ONE uncertain entry after checking GitHub")
    args = ap.parse_args(argv)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")

    if not args.spool:
        ap.error("--spool (or DC_BUGREPORT_SPOOL) is required")
    journal_path = args.journal or args.spool + ".journal.sqlite3"

    if args.status:
        journal = Journal(journal_path, read_only=True)
        try:
            return print_status(journal)
        finally:
            journal.close()

    if not (args.send or args.resolve or args.retry):
        return dry_run(args.spool, journal_path, args.verbose)

    lock = SpoolLock(journal_path + ".lock")
    if not lock.acquire():
        print("another relay holds %s.lock; exiting" % journal_path, file=sys.stderr)
        return EXIT_LOCKED
    journal = Journal(journal_path)
    try:
        if args.resolve or args.retry:
            report_id = args.resolve or args.retry
            entry = journal.get(report_id)
            if not entry or entry["state"] not in ("uncertain", "blocked", "failed"):
                print("%s is not an uncertain/blocked/failed journal entry" % report_id, file=sys.stderr)
                return EXIT_USAGE
            if args.retry:
                journal.delete(report_id)
                print("re-queued %s; it is posted on the next --send run" % report_id)
            elif args.issue:
                journal.set(report_id, "posted", issue=args.issue, detail="resolved by hand")
                print("%s recorded as issue #%d" % (report_id, args.issue))
            elif args.abandon:
                journal.set(report_id, "abandoned", detail="abandoned by hand")
                print("%s abandoned" % report_id)
            else:
                print("--resolve needs --issue N or --abandon", file=sys.stderr)
                return EXIT_USAGE
            return EXIT_OK

        repo, token = resolve_env(args)
        if not REPO_RE.match(repo or ""):
            print("set DC_BUGREPORT_REPO (or --repo) to owner/name", file=sys.stderr)
            return EXIT_USAGE
        if not token:
            print("set GITHUB_TOKEN (or DC_BUGREPORT_GITHUB_TOKEN) to a token with issue write access",
                  file=sys.stderr)
            return EXIT_USAGE
        for report_id in journal.recover_interrupted():
            print("UNCERTAIN %s: interrupted while posting; check GitHub, then --resolve or --retry" % report_id)

        attention_total = 0
        while True:
            posted, attention, wait = send_pass(args.spool, journal, repo, token, labels=args.label or None,
                                                min_interval=args.min_interval, max_posts=args.max_per_pass)
            attention_total += attention
            if not args.watch:
                break
            time.sleep(max(args.watch, wait))
        return EXIT_ATTENTION if attention_total else EXIT_OK
    except KeyboardInterrupt:
        return EXIT_OK
    finally:
        journal.close()
        lock.release()


if __name__ == "__main__":
    sys.exit(main())
