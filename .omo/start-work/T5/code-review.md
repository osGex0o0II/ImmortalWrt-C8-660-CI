# T5 Code Quality Review

## Scope

- Goal: implement the production `c8.sms_forward` rpcd facade, narrow ACL, guarded init reload/trigger integration, and bounded overlay installer validation described by `.superpowers/sdd/task-5-brief.md`.
- Base: `f97b925d9808ee34b3660ae122df024ebaa31bdd`.
- Reviewed product files:
  - `patches/files/usr/share/rpcd/ucode/c8.sms_forward.uc`
  - `patches/files/usr/share/rpcd/acl.d/luci-app-c8modem.json`
  - `patches/files/etc/init.d/c8-sms-forward`
  - `Scripts/InstallC8Overlay.sh`
- Oracle consulted: `Scripts/TestC8SmsForwardRpc.sh` and `Scripts/fixtures/c8-sms-forward-rpc/{canonical-facade.uc,contract.json,analyze-facade.mjs,probe-init.sh}`.
- Evidence inspected: `D:/Code/Git/ImmortalWrt-C8-660-CI/.omo/start-work/T5/**`.

`omo ulw-loop status --json` was unavailable because `omo` is not installed/on PATH, so this report uses the caller-assigned evidence path.

## Findings

### Critical

None.

### Important

None.

### Minor

None.

## Review Notes

- The new facade is byte-for-byte identical to the approved canonical facade (SHA-256 `8e76a43d3e644e62370670b1ead77112cbc9bc0fd69614b59b33873879efd04a`). It exports exactly six methods, uses fixed contract-derived argv, rejects unknown fields/invalid channels before execution, maps explicit exits, and recursively masks `message`/`details` strings.
- ACL read/write method partitions exactly match the contract. Forwarding `file.exec` grants are removed while `/usr/bin/sms_tool *` and existing `file` ubus permissions remain.
- `reload_service` rejects arguments before side effects and performs one `stop` followed by one `start`; `service_triggers` registers one `sms_tool` trigger.
- Installer fixtures/analyzer/probe resolve from `SCRIPT_REPO_DIR`, while `GITHUB_WORKSPACE` controls the copied overlay. Verification calls are bounded and operate on the copied overlay.
- Evidence records RPC `36/36`, backend `46/46`, clean overlay installation, syntax/JSON/analyzer checks, and final invariants as passing. The LuCI exit `1` is the documented T6 RED caused by its stale expectation for the deliberately removed broad forwarding `file.exec` ACL, not a T5 defect.
- Target ucode compile/runtime validation was unavailable and is explicitly deferred to T9. This is a residual validation gap, not a finding against the canonical T5 implementation.

## Verdict

- `codeQualityStatus`: CLEAR
- `recommendation`: APPROVE
- `blockers`: None
