$ErrorActionPreference = 'Stop'

$e4 = 'D:\Code\Git\ImmortalWrt-C8-660-CI\.omo\start-work\T4'
$e5 = 'D:\Code\Git\ImmortalWrt-C8-660-CI\.omo\start-work\T5'
$reports = @(
	'D:\Code\Git\ImmortalWrt-C8-660-SMS-Refactor\.superpowers\sdd\task-4-report.md',
	'D:\Code\Git\ImmortalWrt-C8-660-SMS-Refactor\.superpowers\sdd\task-5-report.md'
)

$shared = @(
	'cross-fix-red.log', 'cross-fix-red.exit',
	'cross-fix-rpc-red.log', 'cross-fix-rpc-red.exit',
	'cross-fix-mask-red.log', 'cross-fix-mask-red.exit',
	'cross-fix-mask-composition.log', 'cross-fix-mask-composition.exit',
	'cross-fix-rpc-green.log', 'cross-fix-rpc-green.exit',
	'cross-fix-static.log', 'cross-fix-static.exit',
	'cross-fix-clean-install.log', 'cross-fix-clean-install.exit',
	'cross-fix-invariants.log', 'cross-fix-invariants.exit',
	'cross-fix-before.sha256', 'cross-fix-after.sha256'
)
foreach ($root in @($e4, $e5)) {
	foreach ($name in $shared) {
		$item = Get-Item -LiteralPath (Join-Path $root $name)
		if ($item.Length -le 0) { throw "empty shared evidence: $root\$name" }
	}
}
foreach ($path in $reports + @(
	(Join-Path $e5 'backend-regression.log'),
	(Join-Path $e5 'backend-regression.exit'),
	(Join-Path $e5 'luci-regression.log'),
	(Join-Path $e5 'luci-regression.exit'),
	(Join-Path $e5 'cross-fix-code-review.md')
)) {
	$item = Get-Item -LiteralPath $path
	if ($item.Length -le 0) { throw "empty terminal artifact: $path" }
}

$expectedExits = @{
	'cross-fix-red.exit' = 'exit=1'
	'cross-fix-rpc-red.exit' = 'exit=1'
	'cross-fix-mask-red.exit' = 'exit=1'
	'cross-fix-mask-composition.exit' = 'exit=0'
	'cross-fix-rpc-green.exit' = 'exit=0'
	'cross-fix-static.exit' = 'exit=0'
	'cross-fix-clean-install.exit' = 'exit=0'
	'cross-fix-invariants.exit' = 'exit=0'
}
foreach ($root in @($e4, $e5)) {
	foreach ($entry in $expectedExits.GetEnumerator()) {
		$actual = (Get-Content -LiteralPath (Join-Path $root $entry.Key) -Raw).Trim()
		if ($actual -ne $entry.Value) { throw "unexpected exit $root\$($entry.Key): $actual" }
	}
}

$patterns = @{
	'cross-fix-red.log' = 'RED_SUMMARY: observed=5 expected=5'
	'cross-fix-rpc-red.log' = 'ERROR: facade analyzer accepted deceptive fixture=direct-wrapper'
	'cross-fix-mask-red.log' = 'ERROR: facade analyzer accepted deceptive fixture=mask-fixed-failure'
	'cross-fix-mask-composition.log' = 'composition_assertion=accepted'
	'cross-fix-rpc-green.log' = 'CONTRACT SUMMARY: pass=42 intended_fail=0 generic_fail=0 total=42'
	'cross-fix-static.log' = 'ucode=absent; target compile/runtime validation deferred to T9'
	'cross-fix-clean-install.log' = 'installed_facade_analyzer=accepted'
	'cross-fix-invariants.log' = 'cross_fix_invariants=accepted'
}
foreach ($root in @($e4, $e5)) {
	foreach ($entry in $patterns.GetEnumerator()) {
		if (-not (Select-String -LiteralPath (Join-Path $root $entry.Key) -SimpleMatch $entry.Value -Quiet)) {
			throw "missing observable in $root\$($entry.Key): $($entry.Value)"
		}
	}
}

if ((Get-Content -LiteralPath (Join-Path $e5 'backend-regression.exit') -Raw).Trim() -ne 'exit=0' -or
	-not (Select-String -LiteralPath (Join-Path $e5 'backend-regression.log') -SimpleMatch 'CONTRACT SUMMARY: pass=46 intended_fail=0 generic_fail=0 total=46' -Quiet)) {
	throw 'recorded backend evidence is not 46/46 exit zero'
}
if ((Get-Content -LiteralPath (Join-Path $e5 'luci-regression.exit') -Raw).Trim() -ne 'exit=1' -or
	-not (Select-String -LiteralPath (Join-Path $e5 'luci-regression.log') -SimpleMatch 'ERROR: missing ACL "/usr/bin/c8-sms-forward \*"' -Quiet)) {
	throw 'planned T6 LuCI RED evidence changed'
}
if (-not (Select-String -LiteralPath $reports[0] -SimpleMatch 'Status: DONE' -Quiet) -or
	-not (Select-String -LiteralPath $reports[1] -SimpleMatch 'Status: DONE_WITH_CONCERNS' -Quiet)) {
	throw 'terminal report status missing'
}
if (-not (Select-String -LiteralPath (Join-Path $e5 'cross-fix-code-review.md') -SimpleMatch 'remediation_status: VERIFIED' -Quiet)) {
	throw 'independent review blocker remediation is not verified'
}

Write-Output 'shared_artifacts_nonempty=accepted'
Write-Output 'red_green_exits=accepted'
Write-Output 'rpc_42_backend_46=accepted'
Write-Output 'planned_luci_t6_red=accepted'
Write-Output 'reports_and_review_remediation=accepted'
Write-Output 'cross_fix_evidence_audit=accepted'
