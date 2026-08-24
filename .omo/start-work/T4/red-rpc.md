# T4 RPC/ACL/Init RED Evidence

## Commands And Results

- `bash -n Scripts/TestC8SmsForwardRpc.sh` -> `0`
- `node --check Scripts/fixtures/c8-sms-forward-rpc/analyze-facade.mjs` -> `0`
- `sh -n` for `probe-init.sh` and `invalid-init.sh` -> `0`
- `jq -e . Scripts/fixtures/c8-sms-forward-rpc/contract.json` -> `0`
- Owned `git diff --check` -> `0`
- `bash Scripts/TestC8SmsForwardRpc.sh` -> `1`, approximately `7323 ms`
- Summary: `pass=2 intended_fail=14 generic_fail=0 total=16`
- Production invariant snapshot: unchanged

## Post-Review Verification

- `bash -n Scripts/TestC8SmsForwardRpc.sh` and both init helper syntax checks -> `0`
- `node --check Scripts/fixtures/c8-sms-forward-rpc/analyze-facade.mjs` -> `0`
- `jq -e . Scripts/fixtures/c8-sms-forward-rpc/contract.json` -> `0`
- `git diff --check` -> `0`
- `bash Scripts/TestC8SmsForwardRpc.sh` -> `1`, the required production RED state
- Summary: `pass=2 intended_fail=19 generic_fail=0 total=21`
- Final line: `OK: production invariant snapshot unchanged`

## Analyzer Baseline

`OK: facade analyzer accepts direct safe returns and rejects unused/discarded safe flows`

The analyzer deliberately recognizes a canonical facade shape instead of arbitrary equivalent ucode. Each exact exported handler must directly return its literal method-specific safe-pipeline call, and that resolvable pipeline must contain exactly seven ordered statements for spec selection, request validation, fixed argv construction, exact backend execution, exit/stdout/stderr mapping, masking, and direct return. The unused-pipeline fixture bypasses that function; the discarded-result fixture calls it but then executes an unsafe alternate path and returns a raw request token. Both return nonzero. The generated positive variant directly returns the canonical pipeline from every handler and returns zero.

## Named Intended Failures

- `source/exact-export-and-unknown-method-rejection`
- `source/exact-request-schemas-executable-and-argv`
- `source/exact-result-exit-map-and-structural-masking`
- `acl/exact-narrow-overall-forwarding-grants`
- `init/exact-reload-trigger-and-argument-contract`
- `overlay/installed-facade-exact`
- `overlay/installed-acl-exact-and-sms-preserved`
- `overlay/installed-init-exact`
- `installer/reject-missing-facade`
- `installer/reject-semantic-fake-facade`
- `installer/reject-discarded-safe-result-facade`
- `installer/reject-broad-forwarding-acl`
- `installer/reject-cross-section-wildcard-acl`
- `installer/reject-invalid-reload-init`

## Named Passes

- `acl/preserve-unrelated-sms-read-send`
- `overlay/valid-install-exits-zero`

## Corruption Proofs

All copied-overlay installer probes are bounded to 30 seconds. Current production incorrectly returns `0` for each corruption:

- facade removed;
- complete marker and expected strings present, but exported handlers bypass the safe data flow;
- canonical safe pipeline called but its result discarded before unsafe execution and a raw token return;
- broad forwarding file keys plus ubus `*` and `c8.*` grants inserted;
- wildcard `c8.*` and `*` ubus grants inserted under another top-level ACL object;
- init replaced with a script that accepts unknown reload arguments and lacks the committed-apply trigger.

A valid copied overlay returns `0`, which remains the post-T5 success contract.

## Production Snapshot

- `MISSING  patches/files/usr/share/rpcd/ucode/c8.sms_forward.uc`
- `38f7874e95c6bdbf4e6ec6fb5f59a3f19f2a0515a95077f75a8c6d6cc5e4bd82  patches/files/usr/share/rpcd/acl.d/luci-app-c8modem.json`
- `865207679ba7c809cfe25920a1b8a64019faf35269e2f3b07ee5c9d1cdc50283  patches/files/etc/init.d/c8-sms-forward`
- `a5d6af8a77c66ffe24c002c6bee4b55802f5bfffc6f60c4607ad9fb238d0e2c0  Scripts/InstallC8Overlay.sh`
- `9da9ebe2084b580ca53572ce9c732a091263a0888058500eec185318adc721f3  patches/files/usr/bin/c8-sms-forward`
- `d491a0b76a8e4d9cc72de9ceff89e9e5addd16fd1fe18abd3bf6162372deb7a9  patches/files/www/luci-static/resources/view/c8modem/sms-forward.js`

Manifest, binary diff, and scoped status snapshots matched before and after. No production path changed. Temporary roots, corruption copies, analyzer outputs, traces, and captured output were removed. No router/provider/network call occurred.

## Runtime Limitation

No host `ucode` executable was available. The harness automatically performs a bounded compile-only facade check when one is present; otherwise on-target rpcd/ucode runtime verification remains a T5/T9 concern.

## Post-Review Helper-Semantics TDD

Before analyzer changes, the new harness self-test exited `1` with `ERROR: facade analyzer accepted helper corruption=validator`; the production invariant cleanup still reported unchanged. Direct analyzer runs for generated `validator`, `argv`, `executor`, `mapper`, and `masker` corruptions each incorrectly returned `0` and printed `facade data flow accepted`.

After strengthening the analyzer, `canonical-facade.uc` returned `0`. Each corruption independently returned `1` with its exact rejected helper: `validate_request`, `build_argv`, `run_backend`, `map_backend_exit`, and `mask_result`. Unreachable and discarded-safe-result rejection remains covered.

The harness now also defines copied-overlay installer REDs for all five helper defects. After the Windows command runner recovered, root independently re-ran syntax, JSON, diff, full-suite, and production-snapshot verification. The post-review suite produced `pass=2 intended_fail=19 generic_fail=0 total=21`, with zero generic failures and an unchanged production snapshot.

## Reviewer-Blocker Recovery Evidence (2026-07-18)

Artifact: `D:/Code/Git/ImmortalWrt-C8-660-CI/.omo/start-work/T4/red-rpc.md`

### RED 1: Documented Executor Contract

Scenario: the interrupted canonical positive facade still used unbound `exec` while the partial analyzer required the documented import.

Invocation: `bash Scripts/TestC8SmsForwardRpc.sh`

Binary observable: exit `1`.

```text
ERROR: facade analyzer rejected canonical helper semantics: facade must import exactly { popen } from 'fs'
OK: production invariant snapshot unchanged
```

### RED 2: Decoy And Shadowing Tests Prove The Defect

Scenario: restore only the analyzer's pre-fix import/shadow/top-level selection guards, keep the new mutations, and analyze each generated source.

Invocation shape:

```sh
sed -f Scripts/fixtures/c8-sms-forward-rpc/fake-<case>.sed \
  Scripts/fixtures/c8-sms-forward-rpc/canonical-facade.uc |
node Scripts/fixtures/c8-sms-forward-rpc/analyze-facade.mjs \
  /dev/stdin Scripts/fixtures/c8-sms-forward-rpc/contract.json
```

Binary observable: canonical exit `0`; every defective case also incorrectly exited `0` and printed `facade data flow accepted`:

```text
DECEPTIVE_top-level-return_EXIT=0
DECEPTIVE_shadow-match_EXIT=0
DECEPTIVE_shadow-exec_EXIT=0
DECEPTIVE_shadow-type_EXIT=0
DECEPTIVE_shadow-length_EXIT=0
DECEPTIVE_shadow-push_EXIT=0
DECEPTIVE_shadow-string_EXIT=0
DECEPTIVE_shadow-die_EXIT=0
DECEPTIVE_shadow-popen_EXIT=0
```

The baseline full invocation exited `1` with `ERROR: facade analyzer accepted deceptive fixture=top-level-return` and `OK: production invariant snapshot unchanged`.

### GREEN: Focused Semantic Analyzer

Scenario: analyze the documented canonical facade, all helper corruptions, all deceptive return/shadow/alternate-executor corruptions, and both legacy unsafe-flow fixtures.

Invocation: direct `node analyze-facade.mjs` commands, with each `.sed` mutation piped from `canonical-facade.uc` as above.

Binary observable:

```text
facade data flow accepted
CANONICAL_EXIT=0
HELPER_validator_EXIT=1
HELPER_argv_EXIT=1
HELPER_executor_EXIT=1
HELPER_mapper_EXIT=1
HELPER_masker_EXIT=1
DECEPTIVE_top-level-return_EXIT=1
DECEPTIVE_shadow-match_EXIT=1
DECEPTIVE_shadow-exec_EXIT=1
DECEPTIVE_shadow-type_EXIT=1
DECEPTIVE_shadow-length_EXIT=1
DECEPTIVE_shadow-push_EXIT=1
DECEPTIVE_shadow-string_EXIT=1
DECEPTIVE_shadow-die_EXIT=1
DECEPTIVE_shadow-popen_EXIT=1
UNUSED_SAFE_EXIT=1
DISCARDED_SAFE_EXIT=1
```

### Final Full Scenario

Scenario: bounded source/ACL/init/overlay/installer suite against unchanged production files.

Invocation: `bash Scripts/TestC8SmsForwardRpc.sh`

Binary observable: exit `1`, required production RED; all named cases classified and no harness failures.

```text
CONTRACT SUMMARY: pass=2 intended_fail=28 generic_fail=0 total=30
EXPECTED RED: RPC/ACL/init/installer production contract is not implemented
OK: production invariant snapshot unchanged
FULL_SUITE_EXIT=1
```

Supporting invocations and observables:

```text
bash -n Scripts/TestC8SmsForwardRpc.sh                                -> 0
node --check Scripts/fixtures/c8-sms-forward-rpc/analyze-facade.mjs  -> 0
sh -n probe-init.sh && sh -n invalid-init.sh                         -> 0
jq -e . contract.json                                                -> 0
14 sed mutation fixtures                                             -> 0 failures
git diff --check                                                     -> 0
```

No router, provider, or network call occurred. The full scenario's before/after manifest, binary diff, and scoped status comparisons produced the captured `production invariant snapshot unchanged` observable.

## Authoritative Re-review Evidence (2026-07-18)

This section supersedes earlier final-count sections. Artifact: `D:/Code/Git/ImmortalWrt-C8-660-CI/.omo/start-work/T4/red-rpc.md`.

### RED: Post-declaration And Delegated-executor Bypasses

Scenario: add the four mutation fixtures while leaving the analyzer unchanged.

Invocation shape:

```sh
sed -f Scripts/fixtures/c8-sms-forward-rpc/fake-<case>.sed \
  Scripts/fixtures/c8-sms-forward-rpc/canonical-facade.uc |
node Scripts/fixtures/c8-sms-forward-rpc/analyze-facade.mjs \
  /dev/stdin Scripts/fixtures/c8-sms-forward-rpc/contract.json
```

Binary observable: every unsafe source was incorrectly accepted.

```text
facade data flow accepted
DECEPTIVE_post-method-mutation_EXIT=0
facade data flow accepted
DECEPTIVE_post-contract-mutation_EXIT=0
facade data flow accepted
DECEPTIVE_reassign-match_EXIT=0
facade data flow accepted
DECEPTIVE_popen-alias-side-effect_EXIT=0
```

Full RED invocation: `bash Scripts/TestC8SmsForwardRpc.sh`.

```text
ERROR: facade analyzer accepted deceptive fixture=post-method-mutation
OK: production invariant snapshot unchanged
FULL_RED_EXIT=1
```

### GREEN: Complete Top-level Statement Proof

Scenario: parse every actual top-level statement, allow only the exact import, four static constants, named functions, and final return, and reject all other side effects or delegated executor references.

Direct focused binary observables:

```text
facade data flow accepted
CANONICAL_EXIT=0
DECEPTIVE_post-method-mutation_EXIT=1
  unexpected top-level side-effect statement: methods.status.call = unsafe_handler
DECEPTIVE_post-contract-mutation_EXIT=1
  unexpected top-level side-effect statement: RPC_CONTRACT.methods.status.argv[1] = 'unsafe'
DECEPTIVE_reassign-match_EXIT=1
  unexpected top-level side-effect statement: match = function(value, pattern)
DECEPTIVE_popen-alias-side-effect_EXIT=1
  facade must contain exactly one popen execution call
```

All five helper corruptions, all thirteen deceptive corruptions, and both legacy unsafe-flow fixtures exited nonzero independently.

### Authoritative Full Scenario

Scenario: bounded source/ACL/init/overlay/installer suite against the unchanged production tree.

Invocation: `bash Scripts/TestC8SmsForwardRpc.sh`.

Binary observable: required production RED exit `1`, all 34 cases classified, zero generic failures.

```text
CONTRACT SUMMARY: pass=2 intended_fail=32 generic_fail=0 total=34
EXPECTED RED: RPC/ACL/init/installer production contract is not implemented
OK: production invariant snapshot unchanged
FULL_SUITE_EXIT=1
```

Supporting final observables:

```text
BASH_N=0
NODE_CHECK=0
SH_FIXTURES=0
JSON_FIXTURE=0
SED_COUNT=18
SED_FAILURES=0
GIT_DIFF_CHECK=0
OWNED_FILES=27
TEXT_ISSUES=0
```

The full suite captured matching before/after production manifests, binary diffs, and scoped status. The only scoped production status remains the pre-existing T2 backend edit; T4 made no production edit. No router, provider, or network call occurred.

## Final Multi-declarator Re-review Evidence (2026-07-18)

This section is the final authoritative receipt and supersedes prior final-count sections. Artifact: `D:/Code/Git/ImmortalWrt-C8-660-CI/.omo/start-work/T4/red-rpc.md`.

### RED

Scenario: append a second declarator to an otherwise allowed static object declaration, performing a mutation in its initializer.

Invocation shape:

```sh
sed -f Scripts/fixtures/c8-sms-forward-rpc/fake-<case>.sed \
  Scripts/fixtures/c8-sms-forward-rpc/canonical-facade.uc |
node Scripts/fixtures/c8-sms-forward-rpc/analyze-facade.mjs \
  /dev/stdin Scripts/fixtures/c8-sms-forward-rpc/contract.json
```

Binary observable: both mutations were incorrectly accepted by the unchanged analyzer.

```text
facade data flow accepted
DECEPTIVE_multi-method-declarator_EXIT=0
facade data flow accepted
DECEPTIVE_multi-contract-declarator_EXIT=0
```

Full RED invocation: `bash Scripts/TestC8SmsForwardRpc.sh`.

```text
ERROR: facade analyzer accepted deceptive fixture=multi-method-declarator
OK: production invariant snapshot unchanged
FULL_RED_EXIT=1
```

### GREEN

Scenario: require each allowed static object to be the entire declaration and use that exact extracted object for subsequent semantic inspection.

```text
facade data flow accepted
CANONICAL_EXIT=0
DECEPTIVE_multi-method-declarator_EXIT=1
  top-level methods declaration contains another declarator or suffix
DECEPTIVE_multi-contract-declarator_EXIT=1
  top-level RPC_CONTRACT declaration contains another declarator or suffix
```

All five helper corruptions, all fifteen deceptive corruptions, and both legacy unsafe-flow fixtures exited nonzero independently.

### Final Authoritative Full Scenario

Invocation: `bash Scripts/TestC8SmsForwardRpc.sh`.

```text
CONTRACT SUMMARY: pass=2 intended_fail=34 generic_fail=0 total=36
EXPECTED RED: RPC/ACL/init/installer production contract is not implemented
OK: production invariant snapshot unchanged
FULL_SUITE_EXIT=1
```

Supporting final observables:

```text
BASH_N=0
NODE_CHECK=0
SH_FIXTURES=0
JSON_FIXTURE=0
SED_COUNT=20
SED_FAILURES=0
GIT_DIFF_CHECK=0
OWNED_FILES=29
TEXT_ISSUES=0
```

The full suite captured matching before/after production manifests, binary diffs, and scoped status. The only scoped production status remains the pre-existing T2 backend edit; T4 made no production edit. No router, provider, or network call occurred.
