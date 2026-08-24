$ErrorActionPreference = 'Stop'

$evidence = 'D:\Code\Git\ImmortalWrt-C8-660-CI\.omo\start-work\T5'
$report = 'D:\Code\Git\ImmortalWrt-C8-660-SMS-Refactor\.superpowers\sdd\task-5-report.md'
$required = @(
	'rpc-red.log', 'rpc-red.exit',
	'rpc-green.log', 'rpc-green.exit',
	'backend-regression.log', 'backend-regression.exit',
	'luci-regression.log', 'luci-regression.exit',
	'syntax-json-analyzer.log', 'syntax-json-analyzer.exit',
	'clean-overlay-install.log', 'clean-overlay-install.exit',
	'final-invariants.log', 'final-invariants.exit',
	'production-before.sha256', 'production-after.sha256',
	'production-after.status', 'production-after.paths',
	'code-review.md'
)

foreach ($name in $required) {
	$item = Get-Item -LiteralPath (Join-Path $evidence $name)
	if ($item.Length -le 0) {
		throw "empty evidence artifact: $name"
	}
}
$reportItem = Get-Item -LiteralPath $report
if ($reportItem.Length -le 0) {
	throw 'empty T5 report'
}

$expectedExits = @{
	'rpc-red.exit' = 'exit=1'
	'rpc-green.exit' = 'exit=0'
	'backend-regression.exit' = 'exit=0'
	'luci-regression.exit' = 'exit=1'
	'syntax-json-analyzer.exit' = 'exit=0'
	'clean-overlay-install.exit' = 'exit=0'
	'final-invariants.exit' = 'exit=0'
}
foreach ($entry in $expectedExits.GetEnumerator()) {
	$actual = (Get-Content -LiteralPath (Join-Path $evidence $entry.Key) -Raw).Trim()
	if ($actual -ne $entry.Value) {
		throw "unexpected $($entry.Key): $actual"
	}
}

$patterns = @{
	'rpc-red.log' = 'CONTRACT SUMMARY: pass=2 intended_fail=34 generic_fail=0 total=36'
	'rpc-green.log' = 'CONTRACT SUMMARY: pass=36 intended_fail=0 generic_fail=0 total=36'
	'backend-regression.log' = 'CONTRACT SUMMARY: pass=46 intended_fail=0 generic_fail=0 total=46'
	'luci-regression.log' = 'ERROR: missing ACL "/usr/bin/c8-sms-forward \*"'
	'syntax-json-analyzer.log' = 'ucode=absent; target compile/runtime validation deferred to T9'
	'clean-overlay-install.log' = 'installed_facade_analyzer=accepted'
	'final-invariants.log' = 'final_invariants=accepted'
	'code-review.md' = '`recommendation`: APPROVE'
}
foreach ($entry in $patterns.GetEnumerator()) {
	if (-not (Select-String -LiteralPath (Join-Path $evidence $entry.Key) -SimpleMatch $entry.Value -Quiet)) {
		throw "missing expected observable in $($entry.Key): $($entry.Value)"
	}
}
if (-not (Select-String -LiteralPath $report -SimpleMatch 'Status: DONE_WITH_CONCERNS' -Quiet)) {
	throw 'T5 report lacks terminal status'
}
if (Test-Path -LiteralPath 'D:\Code\Git\ImmortalWrt-C8-660-CI\.omo\evidence\T5-code-review.md') {
	throw 'review artifact remains outside assigned T5 evidence directory'
}

Write-Output "artifacts_nonempty=$($required.Count + 1)"
Write-Output 'exit_observables=accepted'
Write-Output 'summary_observables=accepted'
Write-Output 'evidence_scope=accepted'
Write-Output 'evidence_audit=accepted'
