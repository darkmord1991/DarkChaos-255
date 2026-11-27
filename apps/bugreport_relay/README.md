# In-game bug reports to GitHub

Players open a report dialog with `/dcbug` (DC-QOS). The worldserver checks the report, rate limits it per
account and appends one JSON line to a local spool file. `dc_bugreport_relay.py`, a separate process, reads
that spool and creates one GitHub issue per report. The game server makes no HTTP call and never holds a
GitHub token. The design follows Ascension CoA's bug-report path (`docs/coa/github-bug-reports.md` in that
repository), re-implemented on the DC addon protocol.

Everything is off by default.

## Pieces

| Piece | Path |
|---|---|
| Dialog and payload | `Custom/Client addons needed/DC-QOS/Modules/BugReport.lua` (`/dcbug`, `/dcbugreport`) |
| Server receiver | `src/server/scripts/DC/LabTools/dc_bug_report.cpp` (+ `dc_bug_report_core.*`), module `BUGR` |
| Relay | `apps/bugreport_relay/dc_bugreport_relay.py` (Python 3.10+, standard library only) |
| Tests | `test_dc_bugreport_relay.py` here, `_tests/test_bugreport.lua` for the addon |

## What a report contains

The client sends the title, description, category, client build, DC fingerprint
(`GetWotLKExtensionsBuildFingerprint`, both the native client and the old client's DLL have it), native
capability mask, locale, zone text, the name and version of each loaded addon and, if ticked, up to five Lua
errors BugGrabber recorded this session. The server adds the map, zone and area (ids and names), the position,
level, class, race, instance and difficulty from the player object, plus the core revision.

The spool line also carries a `private` block (account id and character GUID) for administrators. The relay
never reads it. No account name, IP address or character name is written to the spool, and none reaches an
issue. The relay also redacts IPv4/IPv6 addresses and neutralises `@` mentions in everything the player typed,
and shows the description inside a code block, so a report cannot ping anyone, embed an image or inject HTML.

Server limits: title 3-120 bytes, description 10-4000 bytes, 5 errors of 700 bytes, 64 addons, upload at most
`DC.BugReport.MaxBytes`. One report per `DC.BugReport.CooldownSeconds` per account and at most
`DC.BugReport.MaxPerAccountPerDay` in a rolling 24 hours (in memory; a restart resets both).

## Setup

1. Server configuration (worldserver `darkchaos-custom.conf` or wherever the DC keys live), read at startup and
   on `.reload config`:

   ```ini
   DC.BugReport.Enable = 1
   DC.BugReport.SpoolFile = "/home/wowcore/azeroth-server/bugreports/bugreports.jsonl"
   DC.BugReport.CooldownSeconds = 120
   DC.BugReport.MaxPerAccountPerDay = 10
   DC.BugReport.MaxBytes = 8192
   DC.BugReport.SpoolMaxBytes = 52428800
   ```

   Create the spool folder first, on a local disk, readable and writable only by the worldserver and relay
   accounts. Do not serve it over the web. `AddSC_dc_bug_report()` must be called from the DC script loader.

2. A GitHub token that can create issues in the target repository and nothing else: a fine-grained personal
   access token (or a GitHub App installation token) limited to that one repository with
   **Issues: Read and write**. Players need no GitHub account.

3. Environment for the relay process (never in a file inside the repository):

   ```sh
   export GITHUB_TOKEN=...                       # or DC_BUGREPORT_GITHUB_TOKEN
   export DC_BUGREPORT_REPO=owner/name           # or --repo owner/name
   export DC_BUGREPORT_SPOOL=/path/to/bugreports.jsonl   # or --spool
   ```

4. Check what would be posted. A dry run is the default: it reads the spool and the journal, prints the
   issue titles (`--verbose` prints the bodies too) and sends and writes nothing.

   ```sh
   python3 -B apps/bugreport_relay/dc_bugreport_relay.py --spool "$DC_BUGREPORT_SPOOL" --verbose
   ```

5. Run it for real, supervised (systemd unit, Windows service or a scheduled task):

   ```sh
   python3 -B apps/bugreport_relay/dc_bugreport_relay.py --spool "$DC_BUGREPORT_SPOOL" --send --watch 60
   ```

   `--send` without `--watch` does one pass and exits. `--label <name>` (repeatable) adds labels, which the
   token needs push access for; `--min-interval` (default 5 s) spaces the posts; `--max-per-pass` (default 20)
   bounds one pass.

## Delivery and recovery

The journal is `<spool>.journal.sqlite3` (`--journal` overrides). Only one relay can work on a spool: a second
one exits with code 3 (`<journal>.lock`).

| State | Meaning | What happens next |
|---|---|---|
| (absent) | not posted yet | posted on the next pass |
| `posting` | committed just before the POST | a relay that finds one at start-up turns it into `uncertain` |
| `posted` | issue created, number and URL stored | never posted again |
| `failed` | GitHub refused the content (422) | final; fix by hand if needed |
| `blocked` | 401, 403 (not a rate limit), 404, 410 or a redirect: the issue was not created | the pass stops; retried on the next run once the token or repository is fixed |
| `uncertain` | timeout, 5xx, network error after sending, a 201 without an issue number, or an interrupted run | **never re-sent automatically**: GitHub has no idempotency key, so a resend can duplicate the issue |
| `abandoned` | settled by hand | never posted |

Rate limits (429, or 403 with `X-RateLimit-Remaining: 0` / `Retry-After`) and refused connections leave the
report unposted and end the pass; `--watch` waits at least the time GitHub asked for.

Settling an `uncertain` entry is a manual step. Search the repository for the report id (every issue body ends
with it), then:

```sh
python3 dc_bugreport_relay.py --spool ... --status                          # list what needs attention
python3 dc_bugreport_relay.py --spool ... --resolve <id> --issue 123        # it was created as #123
python3 dc_bugreport_relay.py --spool ... --retry <id>                      # it was not created: post again
python3 dc_bugreport_relay.py --spool ... --resolve <id> --abandon          # drop it
```

Keep the spool and the journal together and back them up. Do not delete the journal to clear an error: that
re-posts every report in the spool. Spool lines are only appended; the relay ignores a last line without its
newline (a write in progress), so it never reads half a report. To start a fresh spool, stop the worldserver's
writes (or rotate the file while no report is coming in), let the relay finish a pass, then archive the spool
and its journal together.

Exit codes: 0 done, 1 something needs attention (`failed`, `blocked` or `uncertain`), 2 usage or missing
configuration, 3 another relay holds the lock.

## Tests

```sh
cd apps/bugreport_relay && python3 -B -m unittest test_dc_bugreport_relay
cd "Custom/Client addons needed/_tests" && lua test_bugreport.lua
```

The relay tests cover spool parsing (partial last line, invalid and duplicate lines), the issue text (no
private data, mentions, IPs, WoW escapes, code-block escaping), every delivery state, the CLI dry run, the
manual repairs and the lock. They use a fake poster; no test talks to GitHub.
