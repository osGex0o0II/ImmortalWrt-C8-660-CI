# T4/T5 Cross-Contract Review Remediation

## Independent Review

Initial verdict: `BLOCK`

Accepted findings before the blocker:

- rpcd wrapper/default/no-method-metadata implementation was correct;
- exact order-insensitive ACL preservation was correct;
- prior fixed program/argv, mutation, alias, ACL partition, and init defenses remained correct.

Blocking finding:

- `UNMAPPED_EXIT` returned a fixed safe failure from `map_backend_exit()`, but the pipeline then sent it through `mask_result()`, replacing its declared message with `[redacted]`.

## TDD Remediation

Test first:

- Added `fake-mask-fixed-failure.sed`, which restores the blocked composition.
- Before the fix, `bash Scripts/TestC8SmsForwardRpc.sh` exited `1` with `ERROR: facade analyzer accepted deceptive fixture=mask-fixed-failure` and an unchanged production snapshot.

Implementation:

- `map_backend_exit()` now receives masking policy.
- An unmapped exit returns `failure_result('UNMAPPED_EXIT', ...)` directly.
- Only a known backend-derived mapped result is passed to `mask_result()`.
- The pipeline returns the composed map result without applying a second mask.
- Analyzer data-flow checks require this exact branch composition.

Verification:

- Direct canonical analyzer: exit `0`, `facade data flow accepted`.
- Direct `fake-mask-fixed-failure` analyzer: exit `1`, `semantic helper parameters differ: map_backend_exit`.
- Expanded suite: exit `0`, `pass=42 intended_fail=0 generic_fail=0 total=42`.
- Clean install, installed analyzer, static checks, and production invariant snapshot: exit `0`.

Artifacts:

- `cross-fix-mask-red.log`, `.exit`
- `cross-fix-mask-composition.log`, `.exit`
- `cross-fix-rpc-green.log`, `.exit`

`remediation_status: VERIFIED`

`recommendation: READY_FOR_REREVIEW`
