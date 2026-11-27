#!/usr/bin/env python3
"""Tests for dc_bugreport_relay.py (stdlib unittest, no network).

    python -m unittest test_dc_bugreport_relay      (from this directory)
"""
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dc_bugreport_relay as relay  # noqa: E402


def record(report_id="6740a1b2-1-0001", title="Quest giver missing", body="The NPC does not offer the quest.",
           **extra):
    rec = {
        "v": 1, "id": report_id, "ts": 1732190000,
        "core": {"hash": "afed058c25", "date": "2026-11-21"},
        "report": {"title": title, "body": body, "category": "quest"},
        "client": {"build": "3.3.5 (12340)", "fingerprint": "darkclient335-abc", "locale": "enUS",
                   "zoneText": "Dalaran"},
        "addons": [{"n": "DC-QOS", "v": "1.3.1"}],
        "errors": [{"m": "Core.lua:10: boom", "c": 2}],
        "context": {"map": 571, "mapName": "Northrend", "zone": 4395, "zoneName": "Dalaran", "area": 4560,
                    "areaName": "Krasus' Landing", "x": 5807.1, "y": 588.2, "z": 660.9, "o": 1.5,
                    "level": 80, "class": 8, "race": 1, "instance": False, "difficulty": 0},
        "private": {"account": 4242, "guid": "Player-SECRET-GUID"},
    }
    rec.update(extra)
    return rec


class FakePoster:
    def __init__(self, outcomes):
        self.outcomes = list(outcomes)
        self.calls = []

    def __call__(self, repo, token, title, body, labels):
        self.calls.append((repo, title, body, labels))
        kind = self.outcomes.pop(0) if self.outcomes else "created"
        if isinstance(kind, relay.Outcome):
            return kind
        if kind == "created":
            return relay.Outcome("created", issue=100 + len(self.calls), url="https://example/issue")
        return relay.Outcome(kind, detail=kind, wait=30 if kind == "retry_later" else 0)


class RelayTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.spool = os.path.join(self.dir.name, "bugreports.jsonl")
        self.journal_path = self.spool + ".journal.sqlite3"

    def tearDown(self):
        self.dir.cleanup()

    def write(self, records, tail=b""):
        with open(self.spool, "wb") as f:
            for rec in records:
                f.write(json.dumps(rec).encode("utf-8") + b"\n")
            f.write(tail)

    def run_pass(self, poster, **kwargs):
        journal = relay.Journal(self.journal_path)
        try:
            with redirect_stdout(io.StringIO()):
                return relay.send_pass(self.spool, journal, "owner/repo", "token", poster=poster,
                                       min_interval=0, sleep=lambda _: None, **kwargs), journal.counts()
        finally:
            journal.close()

    # -- spool ---------------------------------------------------------------

    def test_spool_skips_partial_and_invalid_lines(self):
        self.write([record(), {"v": 1, "id": "bad id", "report": {}}, record()],
                   tail=json.dumps(record("6740a1b2-2-0002")).encode()[:40])
        with open(self.spool, "ab") as f:
            f.write(b"")
        reports, problems = relay.read_spool(self.spool)
        self.assertEqual([r["id"] for r in reports], ["6740a1b2-1-0001"])
        self.assertEqual(len(problems), 2)  # bad id + duplicate id; the partial tail is not a problem yet
        self.assertTrue(any("duplicate" in p for p in problems))

    def test_missing_spool_is_empty(self):
        self.assertEqual(relay.read_spool(os.path.join(self.dir.name, "none.jsonl")), ([], []))

    # -- issue text ----------------------------------------------------------

    def test_issue_never_contains_private_data(self):
        title, body = relay.compose_issue(record())
        self.assertEqual(title, "[In-game] quest: Quest giver missing")
        for secret in ("4242", "Player-SECRET-GUID", "account", "guid"):
            self.assertNotIn(secret, body)
        self.assertIn("Dalaran (zone 4395)", body)
        self.assertIn("Krasus' Landing (area 4560)", body)
        self.assertIn("level 80 Human Mage", body)
        self.assertIn("darkclient335-abc", body)
        self.assertIn("DC-QOS 1.3.1", body)
        self.assertIn("Core.lua:10: boom", body)
        self.assertIn("6740a1b2-1-0001", body)

    def test_mentions_ips_and_wow_escapes(self):
        text = relay.clean_text("ping @octocat from 192.168.178.175 and fe80::1 at 12:30:45, "
                                "|cffff0000red|r |Hitem:6948:0|h[Hearthstone]|h a||b")
        self.assertNotIn("@octocat", text)
        self.assertIn("@​octocat", text)
        self.assertNotIn("192.168.178.175", text)
        self.assertNotIn("fe80::1", text)
        self.assertIn("12:30:45", text)
        self.assertIn("red [Hearthstone] a|b", text)
        self.assertNotIn("|c", text)

    def test_body_text_cannot_escape_its_code_block(self):
        _, body = relay.compose_issue(record(body="before\n```\n![img](http://x/p.png) <script>\n```\nafter"))
        first = body.split("\n", 1)[0]
        self.assertTrue(first.startswith("````"), first)
        self.assertIn("\n````\n", body)

    def test_title_mention_neutralised(self):
        title, _ = relay.compose_issue(record(title="@admin help"))
        self.assertNotIn("@admin", title)

    # -- delivery ------------------------------------------------------------

    def test_posts_once_and_is_idempotent(self):
        self.write([record(), record("6740a1b2-2-0002")])
        poster = FakePoster(["created", "created"])
        (posted, attention, wait), counts = self.run_pass(poster)
        self.assertEqual((posted, attention, wait), (2, 0, 0))
        self.assertEqual(counts, {"posted": 2})
        (posted, attention, wait), counts = self.run_pass(poster)
        self.assertEqual(posted, 0)
        self.assertEqual(len(poster.calls), 2)
        journal = relay.Journal(self.journal_path)
        self.assertEqual(journal.get("6740a1b2-1-0001")["issue"], 101)
        journal.close()

    def test_uncertain_is_never_resent(self):
        self.write([record()])
        poster = FakePoster(["uncertain"])
        (_, attention, _), counts = self.run_pass(poster)
        self.assertEqual(attention, 1)
        self.assertEqual(counts, {"uncertain": 1})
        self.run_pass(poster)
        self.assertEqual(len(poster.calls), 1)

    def test_failed_is_final_and_pass_continues(self):
        self.write([record(), record("6740a1b2-2-0002")])
        poster = FakePoster(["failed", "created"])
        (posted, attention, _), counts = self.run_pass(poster)
        self.assertEqual((posted, attention), (1, 1))
        self.assertEqual(counts, {"failed": 1, "posted": 1})

    def test_blocked_stops_and_recovers(self):
        self.write([record(), record("6740a1b2-2-0002")])
        poster = FakePoster(["blocked"])
        (posted, attention, _), counts = self.run_pass(poster)
        self.assertEqual((posted, attention), (0, 1))
        self.assertEqual(counts, {"blocked": 1})
        self.assertEqual(len(poster.calls), 1)
        poster.outcomes = ["created", "created"]
        (posted, _, _), counts = self.run_pass(poster)
        self.assertEqual(posted, 2)
        self.assertEqual(counts, {"posted": 2})

    def test_rate_limit_leaves_report_pending(self):
        self.write([record(), record("6740a1b2-2-0002")])
        poster = FakePoster(["retry_later"])
        (posted, attention, wait), counts = self.run_pass(poster)
        self.assertEqual((posted, attention, wait), (0, 0, 30))
        self.assertEqual(counts, {})
        poster.outcomes = ["created", "created"]
        (posted, _, _), _ = self.run_pass(poster)
        self.assertEqual(posted, 2)

    def test_interrupted_post_becomes_uncertain(self):
        self.write([record()])
        journal = relay.Journal(self.journal_path)
        journal.set("6740a1b2-1-0001", "posting", attempt=True)
        self.assertEqual(journal.recover_interrupted(), ["6740a1b2-1-0001"])
        journal.close()
        poster = FakePoster(["created"])
        (posted, _, _), counts = self.run_pass(poster)
        self.assertEqual(posted, 0)
        self.assertEqual(counts, {"uncertain": 1})
        self.assertEqual(poster.calls, [])

    def test_max_posts_per_pass(self):
        self.write([record("6740a1b2-%x-0001" % i) for i in range(1, 6)])
        (posted, _, _), _ = self.run_pass(FakePoster([]), max_posts=2)
        self.assertEqual(posted, 2)

    def test_http_classification(self):
        self.assertEqual(relay.classify_http_error(401, {}, b"{}").kind, "blocked")
        self.assertEqual(relay.classify_http_error(404, {}, b"{}").kind, "blocked")
        self.assertEqual(relay.classify_http_error(301, {}, b"").kind, "blocked")
        self.assertEqual(relay.classify_http_error(422, {}, b'{"message":"Validation Failed"}').kind, "failed")
        self.assertEqual(relay.classify_http_error(502, {}, b"").kind, "uncertain")
        limited = relay.classify_http_error(403, {"X-RateLimit-Remaining": "0"}, b'{"message":"API rate limit"}')
        self.assertEqual(limited.kind, "retry_later")
        self.assertEqual(relay.classify_http_error(429, {"Retry-After": "120"}, b"").wait, 120)
        self.assertEqual(relay.classify_http_error(403, {}, b'{"message":"Resource not accessible"}').kind,
                         "blocked")

    # -- CLI -----------------------------------------------------------------

    def test_dry_run_sends_and_writes_nothing(self):
        self.write([record()])
        out = io.StringIO()
        with redirect_stdout(out):
            rc = relay.main(["--spool", self.spool])
        self.assertEqual(rc, 0)
        self.assertIn("WOULD CREATE: [In-game] quest: Quest giver missing", out.getvalue())
        self.assertFalse(os.path.exists(self.journal_path))

    def test_send_requires_repo_and_token(self):
        self.write([record()])
        saved = {k: os.environ.pop(k, None) for k in ("GITHUB_TOKEN", "DC_BUGREPORT_GITHUB_TOKEN",
                                                      "DC_BUGREPORT_REPO")}
        try:
            err = io.StringIO()
            sys_stderr, sys.stderr = sys.stderr, err
            try:
                self.assertEqual(relay.main(["--spool", self.spool, "--send"]), relay.EXIT_USAGE)
                self.assertEqual(relay.main(["--spool", self.spool, "--send", "--repo", "owner/repo"]),
                                 relay.EXIT_USAGE)
            finally:
                sys.stderr = sys_stderr
            self.assertIn("GITHUB_TOKEN", err.getvalue())
        finally:
            for k, v in saved.items():
                if v is not None:
                    os.environ[k] = v

    def test_resolve_and_retry(self):
        self.write([record()])
        self.run_pass(FakePoster(["uncertain"]))
        with redirect_stdout(io.StringIO()):
            self.assertEqual(relay.main(["--spool", self.spool, "--resolve", "6740a1b2-1-0001", "--issue", "77"]), 0)
        journal = relay.Journal(self.journal_path)
        self.assertEqual(journal.get("6740a1b2-1-0001")["state"], "posted")
        self.assertEqual(journal.get("6740a1b2-1-0001")["issue"], 77)
        journal.set("6740a1b2-1-0001", "uncertain")
        journal.close()
        with redirect_stdout(io.StringIO()):
            self.assertEqual(relay.main(["--spool", self.spool, "--retry", "6740a1b2-1-0001"]), 0)
        poster = FakePoster(["created"])
        (posted, _, _), _ = self.run_pass(poster)
        self.assertEqual(posted, 1)

    def test_second_relay_is_locked_out(self):
        lock = relay.SpoolLock(self.journal_path + ".lock")
        self.assertTrue(lock.acquire())
        try:
            other = relay.SpoolLock(self.journal_path + ".lock")
            self.assertFalse(other.acquire())
        finally:
            lock.release()


if __name__ == "__main__":
    unittest.main()
