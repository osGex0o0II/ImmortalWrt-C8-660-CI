# T0 Independent Read-Only Verification

- Date: 2026-07-15
- External worktree: `D:/Code/Git/ImmortalWrt-C8-660-SMS-Refactor`
- Evidence worktree: `D:/Code/Git/ImmortalWrt-C8-660-CI`
- Scope: branch/HEAD, tracked-path parity, index state, SMS-refactor scope, immutable read/send hashes, and internal capability/cleanup consistency.
- Safety: no router command was issued; no product file was edited; nothing was staged, committed, or pushed. This verdict file is the only verifier write.

## 1. Branch and HEAD

Command, from the external worktree:

```powershell
$ErrorActionPreference='Stop'
$branch = git branch --show-current
$head = git rev-parse HEAD
$main = git rev-parse main
$counts = git rev-list --left-right --count main...HEAD
"BRANCH=$branch"
"HEAD=$head"
"MAIN=$main"
"MAIN_HEAD_COUNTS=$counts"
```

Result (exit `0`):

```text
BRANCH=codex/sms-forward-refactor
HEAD=f97b925d9808ee34b3660ae122df024ebaa31bdd
MAIN=f97b925d9808ee34b3660ae122df024ebaa31bdd
MAIN_HEAD_COUNTS=0    0
```

The external branch is the required branch, is at the recorded HEAD, and has no commit divergence from `main`.

## 2. External Status

Command, from the external worktree:

```powershell
$tracked = @(git diff --name-only)
$staged = @(git diff --cached --name-only)
$untracked = @(git ls-files --others --exclude-standard)
"TRACKED_UNSTAGED_COUNT=$($tracked.Count)"
$tracked
"STAGED_COUNT=$($staged.Count)"
$staged
"UNTRACKED_NONIGNORED_COUNT=$($untracked.Count)"
$untracked
```

Result (exit `0`):

```text
TRACKED_UNSTAGED_COUNT=11
.github/workflows/c8-660-open.yml
.github/workflows/update-proxy-locks.yml
.gitignore
Config/GENERAL.txt
Config/OPEN.txt
README.md
Scripts/ApplyProxyLocks.sh
Scripts/Packages.sh
Scripts/PatchHomeProxyModern.sh
Scripts/Settings.sh
patches/filogic-c8-660.mk
STAGED_COUNT=0
UNTRACKED_NONIGNORED_COUNT=0
```

There are exactly 11 unstaged tracked paths, no staged paths, and no nonignored untracked paths in the external worktree.

## 3. Exact Main-Worktree Parity

Command:

```powershell
$ci='D:\Code\Git\ImmortalWrt-C8-660-CI'
$ext='D:\Code\Git\ImmortalWrt-C8-660-SMS-Refactor'
$ciPaths=@(git -C $ci diff --name-only | Sort-Object)
$extPaths=@(git -C $ext diff --name-only | Sort-Object)
"CI_TRACKED_UNSTAGED_COUNT=$($ciPaths.Count)"
"EXT_TRACKED_UNSTAGED_COUNT=$($extPaths.Count)"
$pathDelta=@(Compare-Object $ciPaths $extPaths)
"PATH_DELTA_COUNT=$($pathDelta.Count)"
$pathDelta
foreach($p in $extPaths){
  $ciHash=(git -C $ci hash-object -- $p)
  $extHash=(git -C $ext hash-object -- $p)
  $match=($ciHash -eq $extHash)
  "PATH=$p CI_HASH=$ciHash EXT_HASH=$extHash MATCH=$match"
}
```

Result (exit `0`; Git also emitted only an LF-to-CRLF advisory for `.gitignore`):

```text
CI_TRACKED_UNSTAGED_COUNT=11
EXT_TRACKED_UNSTAGED_COUNT=11
PATH_DELTA_COUNT=0
PATH=.github/workflows/c8-660-open.yml CI_HASH=8e1b2a2108163aae76c63c5fc0c8c9f5c2411aca EXT_HASH=8e1b2a2108163aae76c63c5fc0c8c9f5c2411aca MATCH=True
PATH=.github/workflows/update-proxy-locks.yml CI_HASH=19595aaa9bcfe0d515b5c694fd0c634c98d605aa EXT_HASH=19595aaa9bcfe0d515b5c694fd0c634c98d605aa MATCH=True
PATH=.gitignore CI_HASH=34ec5602fb7d0cec9ecb781556da2e5636d9dff1 EXT_HASH=34ec5602fb7d0cec9ecb781556da2e5636d9dff1 MATCH=True
PATH=Config/GENERAL.txt CI_HASH=c040136d977b361079a24659d3fc91123f5404d3 EXT_HASH=c040136d977b361079a24659d3fc91123f5404d3 MATCH=True
PATH=Config/OPEN.txt CI_HASH=0e5399c7da35f3274b560e806bda37889f67a9a8 EXT_HASH=0e5399c7da35f3274b560e806bda37889f67a9a8 MATCH=True
PATH=patches/filogic-c8-660.mk CI_HASH=45ef37cc313cdf729f07fe6e0e1ffb1bc8ce4632 EXT_HASH=45ef37cc313cdf729f07fe6e0e1ffb1bc8ce4632 MATCH=True
PATH=README.md CI_HASH=0b58309e57cad8b3411345906027c5cc0eb35376 EXT_HASH=0b58309e57cad8b3411345906027c5cc0eb35376 MATCH=True
PATH=Scripts/ApplyProxyLocks.sh CI_HASH=f98d8ee71aea052eaf3118cb865407415a235422 EXT_HASH=f98d8ee71aea052eaf3118cb865407415a235422 MATCH=True
PATH=Scripts/Packages.sh CI_HASH=585f3c5e10fc7f8997c62b96c315e12789e2dbff EXT_HASH=585f3c5e10fc7f8997c62b96c315e12789e2dbff MATCH=True
PATH=Scripts/PatchHomeProxyModern.sh CI_HASH=957b6ca1dbbf2a657fc7ef52d58940891cbf7a58 EXT_HASH=957b6ca1dbbf2a657fc7ef52d58940891cbf7a58 MATCH=True
PATH=Scripts/Settings.sh CI_HASH=d51134bbe9568db5b39e5ae2079c8984c03e875b EXT_HASH=d51134bbe9568db5b39e5ae2079c8984c03e875b MATCH=True
```

The path sets and every corresponding worktree blob are identical. The main worktree additionally reports only untracked `.omo/` evidence state. Because both worktrees share the same HEAD and all 11 tracked modifications have exact content parity, there is no SMS-refactor product change in the external worktree.

## 4. Read/Send SHA-256 Manifest

Command:

```powershell
$manifest='D:\Code\Git\ImmortalWrt-C8-660-CI\.omo\start-work\T0\read-send.sha256'
$root='D:\Code\Git\ImmortalWrt-C8-660-SMS-Refactor'
Get-Content $manifest | ForEach-Object {
  if($_ -notmatch '^([0-9a-f]{64}) \*(.+)$'){ throw "Malformed manifest line: $_" }
  $expected=$Matches[1]; $relative=$Matches[2]
  $actual=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $root $relative)).Hash.ToLowerInvariant()
  "PATH=$relative EXPECTED=$expected ACTUAL=$actual MATCH=$($expected -eq $actual)"
}
```

Result (exit `0`):

```text
PATH=patches/files/www/luci-static/resources/view/c8modem/sms-read.js EXPECTED=3d3cb0fb72df0c56c20e1c4618ddddba3eedd06f4cdd556258c53f19d6df3ab5 ACTUAL=3d3cb0fb72df0c56c20e1c4618ddddba3eedd06f4cdd556258c53f19d6df3ab5 MATCH=True
PATH=patches/files/www/luci-static/resources/view/c8modem/sms-send.js EXPECTED=7dc12ab2ec0fe3f539d975eed5ab20d8625435cf4118b584679e1f94b7002e30 ACTUAL=7dc12ab2ec0fe3f539d975eed5ab20d8625435cf4118b584679e1f94b7002e30 MATCH=True
```

## 5. Evidence Capability and Cleanup Consistency

Command against `evidence.md`:

```powershell
$p='.omo\start-work\T0\evidence.md'
$lines=Get-Content $p
$success=@($lines | Select-String '^Both successful SSH sessions exited `0`\.$')
$receipts=@($lines | Select-String '^CLEANUP_RECEIPT:')
$forbidden=@($lines | Select-String '^sms_tool (recv|delete|send)(\s|$)')
$busyboxProbe=@($lines | Select-String '^busybox 2>&1')
$busyboxEvidence=@($lines | Select-String '^BusyBox v1\.37\.0')
$rpcdInstalled=@($lines | Select-String '^rpcd-mod-ucode-2026\.06\.04~28faf640-r1 description:$')
$rpcdOwner=@($lines | Select-String '^/usr/lib/rpcd/ucode\.so is owned by rpcd-mod-ucode-2026\.06\.04~28faf640-r1$')
"SUCCESS_SUMMARY_LINES=$($success.Count)"
"CLEANUP_RECEIPTS=$($receipts.Count)"
"FORBIDDEN_REMOTE_COMMAND_LINES=$($forbidden.Count)"
"BUSYBOX_PROBE_LINES=$($busyboxProbe.Count)"
"BUSYBOX_VERSION_EVIDENCE_LINES=$($busyboxEvidence.Count)"
"RPCD_INSTALLED_EVIDENCE_LINES=$($rpcdInstalled.Count)"
"RPCD_OWNER_EVIDENCE_LINES=$($rpcdOwner.Count)"
$receipts.Line
```

Result (exit `0`):

```text
SUCCESS_SUMMARY_LINES=1
CLEANUP_RECEIPTS=2
FORBIDDEN_REMOTE_COMMAND_LINES=0
BUSYBOX_PROBE_LINES=1
BUSYBOX_VERSION_EVIDENCE_LINES=3
RPCD_INSTALLED_EVIDENCE_LINES=1
RPCD_OWNER_EVIDENCE_LINES=1
CLEANUP_RECEIPT: removed temporary askpass and isolated known_hosts; verified absent
CLEANUP_RECEIPT: removed apk-probe askpass and isolated known_hosts; verified absent
```

Internal review result:

- The evidence records two successful isolated SSH sessions and exactly two corresponding cleanup receipts.
- No forbidden `sms_tool recv`, `sms_tool delete`, or `sms_tool send` command line appears in the recorded remote command blocks.
- `rpcd-mod-ucode` installation and ownership/readability of `/usr/lib/rpcd/ucode.so` are mutually consistent.
- The standalone BusyBox probe is listed, and BusyBox `v1.37.0` is independently present in the recorded `mkdir`, `mv`, and `date` help output. The capability conclusion does not rely on an unsupported version claim.
- The claimed CLI availability/behavior and package ownership lines agree with the baseline conclusion; no capability or cleanup contradiction was found.

## Verdict

APPROVE
