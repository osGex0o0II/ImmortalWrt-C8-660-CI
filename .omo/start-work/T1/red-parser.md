# T1 Backend RED Evidence

- Product worktree: `D:/Code/Git/ImmortalWrt-C8-660-SMS-Refactor`
- RED worktree: `D:/Code/Git/ImmortalWrt-C8-660-CI`
- Backend SHA-256 before: `ec3fec03d0b99d2d33f1cd9ea347b193c616754842dcab2353094c09380816a7`
- Backend SHA-256 after: `ec3fec03d0b99d2d33f1cd9ea347b193c616754842dcab2353094c09380816a7`
- Backend `git diff --quiet -- patches/files/usr/bin/c8-sms-forward`: exit `1` before and exit `1` after because of the pre-existing unstaged T2 production diff; the captured diff bytes and `git status --short` (` M patches/files/usr/bin/c8-sms-forward`) were identical before/after.
- Test syntax: `bash -n Scripts/TestC8SmsForward.sh` -> exit `0`
- Diff check: `git diff --check -- Scripts/TestC8SmsForward.sh Scripts/fixtures/c8-sms-forward` -> exit `0`
- RED command: `bash Scripts/TestC8SmsForward.sh`
- RED result: exit `1` in approximately `68113 ms`
- Contract summary: `pass=43 intended_fail=3 generic_fail=0 total=46`
- Generic harness failures: `0`
- Runtime cleanup: `/tmp/c8-sms-forward` absent; `/tmp/c8-sms-forward.log` absent after exit

## Named RED Coverage

- `manual/success-is-zero-structured`: successful once structured result missing.
- `cli/invalid-invocation-is-class-2-structured`: invalid invocation returned class `1` and usage text instead of structured class `2`.
- `delivery/provider-body-rejection`: provider body rejection with transport exit `0` was accepted instead of class `5`.

All other 43 contracts passed, including parser coercion/root shapes, malformed/empty input, multipart and duplicate behavior, stale pending, structured manual/config/preflight/provider failures, timeout/nonzero/non-JSON `sms_tool`, busy/live/stale/concurrent locks, journal inventory/atomicity/bounds/redaction, ACK-before-delete, ACKED restart recovery, and delete ordering.

## Harness Quality Gates

- Fake jq rejects regex-family filters when `FAKE_JQ_NO_REGEX=1`.
- Fake `sms_tool` records separate recv/delete operations, supports bounded timeout and runtime failure fixtures, and never contacts a modem.
- Fake curl records calls and independently models transport nonzero, HTTP failure, and provider-body rejection without network access.
- Normal scenarios have an 8-second timeout; the journal-bound stress case has a 60-second timeout; concurrent children and runtime fixture self-checks are separately bounded.
- Harness setup/fake/outer-timeout failures are reported as generic `FAIL`; `INTENDED FAIL` is reserved for backend assertions.
- Journal checks inspect `journal.json` and every `journal.d/*.json` record for valid JSON, same-directory atomic temp+rename evidence, bounded record count, temporary-file cleanup, and protected body/sender/token absence.
- Structured details are recursively checked for protected sentinel containment in nested scalar strings, while common words are excluded from the sentinel list.
- No production backend chmod/write/stage/commit/push/reset/clean/revert was performed by T1.

## Fixture Inventory

Parser/root/multipart fixtures: `live-numeric-index.json`, `index-number.json`, `index-numeric-string.json`, `index-array.json`, `index-comma-string.json`, `index-embedded-invalid.json`, `index-mixed-array-invalid.json`, `index-null-invalid.json`, `root-msg.json`, `root-messages.json`, `root-array.json`, `malformed.json`, `empty-input.json`, `empty-inbox.json`, `multipart-reverse.json`, `multipart-gap.json`, `multipart-duplicate.json`, `multipart-duplicate-identical.json`.

Persistence/runtime fixtures: `delete-order.json`, `journal-sensitive.json`, `runtime/{delivery-failed.json,http-503.json,provider-rejected.json,port-busy.stderr,modem-absent.stderr,modem-resetting.stderr,sim-absent.stderr,sim-pin-required.stderr,sim-not-ready.stderr}`.

## Worktree Status

The full status retained unrelated user edits and the pre-existing T2 production edit. T1 added only the owned test/fixture paths and this evidence/report; no files were staged.

## Post-T2 GREEN

After T2 implemented structured success, invalid-invocation, and provider-response validation, the controller reran `bash Scripts/TestC8SmsForward.sh` in isolation. Result: exit `0`, `pass=46 intended_fail=0 generic_fail=0 total=46`, approximately `74848 ms`. Backend SHA/diff were unchanged during the suite, and `/tmp/c8-sms-forward` plus `/tmp/c8-sms-forward.log` were absent after cleanup.
