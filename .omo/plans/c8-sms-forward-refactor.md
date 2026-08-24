# C8-660 SMS Forwarding Refactor Execution Plan

## Scope And Constraints

- Tier: HEAVY. The change crosses shell parsing, modem/SIM state, concurrency and persistence, rpcd ACL, LuCI/UCI apply semantics, responsive UI, external provider behavior, and live-router rollback.
- Keep `modem/sms` as the only SMS owner. Do not install WeChatPush; borrow only its channel-adapter concepts.
- Preserve TTYD/Web terminal, UPnP, WOL, and ZeroTier. Keep tcpdump, socat, mtd-rw, SFTP, package-manager UI, and partexp excluded.
- Do not change `sms-read.js` or `sms-send.js` unless a failing regression proves a defect.
- Do not commit, push, or open a PR. Preserve all 11 pre-existing user modifications.
- All product edits and QA are delegated. The root orchestrator only manages `.omo` state, delegation, evidence, and verdicts.

## Workspace Bootstrap

- Create external worktree `D:/Code/Git/ImmortalWrt-C8-660-SMS-Refactor` on `codex/sms-forward-refactor` from `f97b925d9808ee34b3660ae122df024ebaa31bdd`.
- Apply `C:/Users/Administrator/AppData/Local/Temp/c8-sms-user-worktree.patch` (SHA256 `543ab772ad16f879dfdcabe3a5963ab3cc7c1aa5ba2dd47ea0799dc5818b4d05`, 71938 bytes) inside the external worktree.
- Verify the external worktree contains the same 11 pre-existing modified paths and no SMS refactor changes before RED begins.
- Register every local/router/browser temporary artifact and exact cleanup command in the ultrawork ledger.

## Architecture Decisions

- Keep `/usr/bin/c8-sms-forward` as the service CLI and orchestration boundary for this vertical slice. Avoid a broad module split until behavior is locked by tests.
- Use regex-free jq primitives and explicit index-shape validation. Do not add `jq-full` or Oniguruma.
- Use an atomic `mkdir` scan lock with owner timestamp metadata and conservative stale recovery; this avoids introducing or assuming a runtime `flock` dependency.
- Persist a bounded, body-free delivery journal with same-directory temporary write plus atomic `mv`. State order is `PENDING -> ACKED -> DELETED`; an `ACKED` restart deletes only and never resends.
- Add a narrow rpcd ucode facade at `/usr/share/rpcd/ucode/c8.sms_forward.uc`. It exposes declared methods and shells only to fixed backend subcommands. Use the target's existing rpcd ucode support as an explicit preflight; if absent, stop and revise rather than silently broadening ACL.
- RPC schema: `{ ok, state, stage, error_code, message, details }`; details never contain credentials, SMS body, sender, or full chat identifiers.
- LuCI uses `rpc.declare`, never browser `fs.exec` for forwarding actions. Save & Apply follows save, `uci.apply()` confirmation, then exactly one service reload.
- Scan/service actions use committed configuration. Per-channel credential tests may send a validated ephemeral payload only if the RPC method and secret handling are proven; otherwise they require committed configuration.
- Hard safety preflight failures (invalid config/input, missing or busy port, modem/SIM unavailable) occur before inbox read. For a manual safe `once`, channel readiness is a post-parse delivery gate: the inbox is parsed and normalized first, then `NO_READY_CHANNEL` returns before provider send, journal acknowledgement, or deletion. The daemon may short-circuit `NO_READY_CHANNEL` before polling.

## TODOs

- [ ] T0 Bootstrap isolated worktree and baseline evidence
  - Owner: bootstrap worker; files: no product files.
  - Verify branch/HEAD, patch hash, dirty-path parity, target reachability, rpcd ucode availability, installed shell/jq command set, baseline tests, and SHA256 baselines for `sms-read.js` and `sms-send.js`.
  - Evidence: commands, exit codes, dirty path list, and no-cleanup-needed baseline receipt.

- [ ] T1 Write backend RED tests
  - Owner: backend-test worker; owns `Scripts/TestC8SmsForward.sh` and new fixtures/helpers only.
  - Add exact live numeric-index fixture plus numeric string, array, comma-separated string, invalid mixed/embedded index, `{msg}`, `{messages}`, bare array, malformed JSON, empty inbox, multipart reverse/gap/duplicate, and stale-pending cases.
  - Add stable state/exit tests for disabled manual run, malformed config/input, timeout, nonzero/non-JSON `sms_tool`, missing/busy port, modem absent/resetting, SIM absent/PIN/not-ready, no-ready-channel, delivery failure, and busy lock.
  - Add concurrency/crash scenarios: two simultaneous `once` calls yield one modem/provider path plus one `BUSY`; stale lock recovery; atomic journal; ACK-before-delete; restart from `ACKED` deletes without resend; deletion order `10,2,1`.
  - RED passes only when failures are caused by the known missing behavior, not harness errors.

- [ ] T2 Implement backend compatibility and reliability slice
  - Depends on T1 RED. Owner: backend worker; owns `patches/files/usr/bin/c8-sms-forward` and backend-owned state defaults only.
  - Replace regex parsing, validate index shapes, normalize supported root shapes, and ensure malformed input cannot leave stale pending state.
  - Implement stable CLI classes: 0 success, 1 operational, 2 invocation/config, 3 busy, 4 parse/schema, 5 delivery failure, 124 timeout; emit semantic `error_code` in structured JSON.
  - Preflight failures must occur before modem read, external send, or SMS deletion.
  - Add `mkdir` lock and bounded atomic delivery journal. Never delete before durable provider acknowledgement. Preserve multipart and duplicate idempotency.
  - GREEN: all T1 tests pass and the original backend scenarios remain passing.

- [ ] T3 Independently verify backend DoneClaim
  - Owner: adversarial backend verifier; read-only except evidence artifacts.
  - Re-run RED-history evidence and GREEN suite, inject malformed/competing processes, inspect journal for body/secrets, and challenge three hypotheses: lock bypass, ACK/delete replay, parser coercion.
  - Verdict must be unconditional APPROVE before RPC/UI work uses the backend contract.

- [ ] T4 Write RPC/ACL/init RED tests
  - Owner: RPC-test worker; owns new `Scripts/TestC8SmsForwardRpc.sh` and RPC portions of overlay tests.
  - Require declared `status`, `preflight`, `once`, `test_channel`, `log`, and `clear_log` methods; narrow ACL; fixed backend commands; secret masking; structured errors; no browser-facing `file.exec` forwarding grant.
  - Require procd/UCI reload behavior that can be invoked exactly once after committed apply.

- [ ] T5 Implement narrow rpcd facade and service integration
  - Depends on T3 and T4 RED. Owner: RPC worker; owns new `/usr/share/rpcd/ucode/c8.sms_forward.uc`, forwarding ACL entries, init script reload trigger/command, and overlay installer entries.
  - Validate all arguments against finite schemas, map backend exit/state to RPC schema, mask secrets, and reject unknown methods/fields.
  - Remove only forwarding-related broad exec permissions; retain unrelated SMS read/send permissions required by their current pages.
  - GREEN: RPC/ACL/init tests and clean overlay install pass.

- [ ] T6 Write LuCI RED tests
  - Owner: LuCI-test worker; owns `Scripts/TestC8SmsForwardLuCI.sh` and UI test fixtures.
  - Require `rpc.declare`, absence of forwarding `fs.exec`, real `uci.apply()`/confirmation before one reload, zero RPC calls from disabled unsafe controls, structured Chinese states/errors, and mobile layout hooks.
  - Explicitly reject the existing defect-preserving assertions around `m.save()` plus immediate execution/restart.

- [ ] T7 Implement LuCI RPC client and responsive state UI
  - Depends on T5 contract and T6 RED. Owner: LuCI worker; owns `patches/files/www/luci-static/resources/view/c8modem/sms-forward.js` and view-local style only.
  - Render compact labeled Chinese state rows; map parser/network/provider errors to concise Chinese guidance and log/retry actions.
  - Disable or hide unsafe test/scan controls with a specific reason; use `否`/`未启用` wording.
  - Implement standard save/apply/confirm and exactly one reload. Prevent floating controls from covering channel content at 390x844.
  - GREEN: LuCI tests and `node --check` pass.

- [ ] T8 Add adjacent and package/build regressions
  - Depends on T3, T5, and T7. Owner: regression verifier; verification-only, owns only `.omo/start-work/T8/**` evidence artifacts and does not edit product or existing test files.
  - Verify SMS read uses readport and SMS send uses sendport; neither path is intercepted by forwarding RPC/lock.
  - Verify retained package set and excluded package set, clean overlay install, all C8 modem JS syntax, workflow YAML, shell syntax, and `git diff --check`.

- [ ] T9 Live C8-660 deployment and safe canary checkpoint
  - Depends on T3, T5, T7, and T8 approvals. Owner: hardware QA worker.
  - Back up every replaced router file and capture hashes, UCI delta, service state, inbox count, and forwarding state. Use isolated known-host file and redact credentials/content.
  - Deploy only the verified overlay files temporarily. Keep every channel disabled/unready. Preflight that the backend invokes `sms_tool` and `curl` through `PATH`; if absolute paths are found, stop and revise the instrumentation plan.
  - Prepend a QA-only `/tmp/c8-sms-qa/bin` to `PATH`: its `sms_tool` wrapper increments operation-specific counters, passes `recv` to the real binary, and refuses/records `delete`; its `curl` wrapper refuses/records every call. Execute one manual scan so real inbox JSON is parsed while all side effects are blocked and counted.
  - PASS: noregex parser sees all 4 existing messages, result is post-parse `NO_READY_CHANNEL`, `recv_attempts=1`, `send_attempts=0`, `delete_attempts=0`, inbox remains 4, and no UCI changes remain.
  - Exercise status/RPC/ACL safely. Do not run a real provider send. Leave the verified temporary deployment in place only for T10, with rollback bundle and known-host path registered.

- [ ] T10 Real LuCI functional/visual QA and router rollback
  - Depends on T9 checkpoint. Owners in sequence: browser/visual QA worker, adversarial security verifier, then hardware rollback worker.
  - Open `http://192.168.1.1/cgi-bin/luci/admin/modem/sms/forward` in the persistent browser QA session at desktop and 390x844. Verify structured Chinese status, disabled unsafe actions, actionable errors, no overlap/overflow, no console errors, and save/apply ordering in network actions without enabling a provider.
  - Verify ACL denial is actionable; arbitrary command/argument attempts are rejected; secrets and SMS contents do not appear in logs/responses.
  - Retain screenshots/action logs through the Final Verification Wave. Then restore original files/UCI/service, remove temp state/log/backups/wrappers, verify original hashes and inbox count, close browser tabs/session, and delete the isolated known-host file.

- [ ] T11 Produce and apply SMS-only integration patch
  - Depends on all approvals. Owner: integration worker.
  - Generate a patch limited to verified SMS implementation/tests/overlay files, excluding the 11 pre-existing user modifications.
  - Dry-run apply against `D:/Code/Git/ImmortalWrt-C8-660-C8-660-CI` is invalid; use the actual main workspace `D:/Code/Git/ImmortalWrt-C8-660-CI`.
  - Verify target files have not diverged since snapshot. Apply without commit/stage unless explicitly requested. Re-run scope and `git diff --check` via verifier.
  - Preserve external worktree until final receipt confirms the main workspace contains the same SMS-only diff.

## Final Verification Wave

1. Independent review lanes: goal/constraint compliance, code quality, security/ACL/secret handling, hands-on runtime QA, and scope/regression audit.
2. Runtime debugging audit must explicitly challenge at least: parser shape coercion, concurrent lock/journal replay, and save/apply/reload ordering.
3. Re-run backend, RPC, LuCI, adjacent read/send, overlay, JS syntax, YAML, package retention/exclusion, and diff-format checks from the main workspace after integration.
4. Confirm router rollback, browser/tab cleanup, temp known-host cleanup, `C:/Users/Administrator/AppData/Local/Temp/c8-sms-user-worktree.patch` cleanup only after no longer needed, and no unregistered artifacts.
5. Final reviewer must return unconditional APPROVE. Any REVISE/BLOCK reopens the cited task and its verifier.
6. Report changed files, exact verification outcomes, router invariants, branch/worktree path, no-commit status, and remaining provider limitation: providers without idempotency keys can only offer at-least-once delivery before acknowledgement is durably recorded.

## Per-Task QA Contracts

- T0: use Git Bash `git worktree add`, `sha256sum`, `git apply --check`, `git apply`, `git status --short`, and read-only SSH probes. Run `sha256sum patches/files/www/luci-static/resources/view/c8modem/sms-read.js patches/files/www/luci-static/resources/view/c8modem/sms-send.js > .omo/start-work/T0/read-send.sha256`. Expect the recorded snapshot SHA, exactly 11 baseline dirty paths, rpcd ucode support, baseline exit codes, and two read/send hash lines captured under `.omo/start-work/T0/`. Cleanup: remove only T0 known-host/temp probe files; retain the registered worktree and snapshot.
- T1: run `bash Scripts/TestC8SmsForward.sh` from the external worktree after adding fixtures. Expect nonzero with named failures for regex/index/state/lock/journal scenarios and no harness syntax error. Save stdout/stderr and fixture inventory under `.omo/start-work/T1/`. Cleanup: remove only generated runtime directories.
- T2: run the exact T1 command plus `sh -n patches/files/usr/bin/c8-sms-forward`. Expect all named scenarios and syntax check exit 0; save backend state/journal redactions under `.omo/start-work/T2/`. Cleanup: remove test locks, journals, fake modem/provider binaries, and message fixtures created outside the repository.
- T3: independently run T1/T2 commands, two concurrent `once` processes, stale-lock injection, and ACKED replay injection. Expect one `BUSY`, one modem/provider path, no body in journal, no resend from ACKED, and APPROVE in `.omo/start-work/T3/verdict.md`. Cleanup: remove verifier runtime state.
- T4: run `bash Scripts/TestC8SmsForwardRpc.sh` and `tmp=$(mktemp -d); bash Scripts/InstallC8Overlay.sh "$tmp"; rc=$?; rm -rf "$tmp"; exit $rc`. Expect RED for missing object/methods/narrow ACL/reload contract, not missing harness tools. Evidence under `.omo/start-work/T4/`. Cleanup: delete temp root.
- T5: run the exact T4 commands plus `ucode -c patches/files/usr/share/rpcd/ucode/c8.sms_forward.uc` when host ucode is available; otherwise validate syntax on the router in T9 before activation. Expect RPC schema/method/ACL/overlay checks exit 0. Evidence under `.omo/start-work/T5/`. Cleanup: delete temp root and local RPC fixtures.
- T6: run `bash Scripts/TestC8SmsForwardLuCI.sh`. Expect RED naming `rpc.declare`, `uci.apply`, single reload, disabled-control behavior, Chinese state mapping, and mobile hook requirements. Evidence under `.omo/start-work/T6/`. Cleanup: remove generated DOM/mock files only.
- T7: run the exact T6 command and `node --check patches/files/www/luci-static/resources/view/c8modem/sms-forward.js`. Expect exit 0. Save mock RPC/action-order output under `.omo/start-work/T7/`. Cleanup: remove generated mocks.
- T8: run `bash Scripts/TestC8SmsForward.sh`, `bash Scripts/TestC8SmsForwardRpc.sh`, and `bash Scripts/TestC8SmsForwardLuCI.sh`; compare `sha256sum -c .omo/start-work/T0/read-send.sha256`; run a registered clean `Scripts/InstallC8Overlay.sh` temp root; run `for f in patches/files/www/luci-static/resources/view/c8modem/*.js; do node --check "$f"; done`; run `python -c "import glob,yaml; [yaml.safe_load(open(p,encoding='utf-8')) for p in glob.glob('.github/workflows/*.y*ml')]; print('YAML_OK')"`; run `sh -n` on `patches/files/usr/bin/c8-sms-forward`, `patches/files/usr/bin/cellscan.sh`, `patches/files/etc/init.d/c8-sms-forward`, and every `Scripts/*.sh`; run the retained/excluded package grep contract and `git diff --check`. Expect all exit 0, `YAML_OK`, and unchanged read/send hashes. Evidence under `.omo/start-work/T8/`. Cleanup: delete temp overlay root.
- T9: use Windows OpenSSH bound to `192.168.1.200` with an isolated known-host file. Record router file hashes/UCI/service/inbox, install backups and `/tmp/c8-sms-qa/bin` wrappers, then run `PATH=/tmp/c8-sms-qa/bin:$PATH SMS_TOOL_BIN=/tmp/c8-sms-qa/bin/sms_tool /usr/bin/c8-sms-forward once`. Expect parser count 4, `NO_READY_CHANNEL`, `recv_attempts=1`, `send_attempts=0`, `delete_attempts=0`, inbox 4. Redacted checkpoint transcript and rollback manifest go in `.omo/start-work/T9/`; keep the temporary deployment only until T10.
- T10: use the persistent browser QA session at `http://192.168.1.1/cgi-bin/luci/admin/modem/sms/forward` at desktop and 390x844. Execute status, disabled-action, ACL-denial, and save/apply action-order scenarios; inspect console/network. Expect no unsafe RPC calls, no overlap/overflow/errors, and one reload after apply. Store screenshots/action log under `.omo/start-work/T10/` and retain them through final review. Then resume the hardware rollback worker to restore files/UCI/service, verify hashes/inbox, remove wrappers/backups/state/log/known-host file, and record the cleanup receipt.
- T11: use `git diff --binary` with an explicit SMS allowlist to create the integration patch, `git apply --check` in the main workspace, verify target file hashes have not diverged, then `git apply` via the integration worker. Expect only allowlisted SMS paths added to the existing 11 modified paths and no commit/stage. Evidence and patch hash under `.omo/start-work/T11/`; retain patch/worktree until final verification, then remove only registered temp patch/snapshot.
- Final wave: invoke `multi_agent_v1__spawn_agent` as five independent lanes with the plan, allowlisted diff, and evidence index: `oracle` for goal/constraint compliance, `oracle` for code quality, `oracle` for security/ACL/secrets, `unspecified-high` for hands-on runtime QA, and `unspecified-high` for scope/regression audit. Separately task the runtime-QA lane to challenge parser coercion, concurrent lock/journal replay, and save/apply/reload ordering. Re-run the exact T8 command set from the main workspace. Expect every command exit 0 and every lane's terminal verdict to be unconditional APPROVE; retain artifacts under `.omo/start-work/final/` until conclusions are ledgered, then remove screenshots and registered QA-only evidence copies.
