$ErrorActionPreference = 'Stop'

$repo = 'D:\Code\Git\ImmortalWrt-C8-660-SMS-Refactor'
$e4 = 'D:\Code\Git\ImmortalWrt-C8-660-CI\.omo\start-work\T4'
$e5 = 'D:\Code\Git\ImmortalWrt-C8-660-CI\.omo\start-work\T5'
Set-Location -LiteralPath $repo

Write-Output '$ git diff --check'
& git diff --check
if ($LASTEXITCODE -ne 0) { throw "git diff --check exited $LASTEXITCODE" }
Write-Output 'git_diff_check_exit=0'

$currentStatus = @(& git status --short)
if ($LASTEXITCODE -ne 0) { throw "git status exited $LASTEXITCODE" }
$currentStatus | Set-Content -LiteralPath (Join-Path $e5 'cross-fix-worktree.status') -Encoding ascii
$baselineStatus = @(Get-Content -LiteralPath (Join-Path $e5 'worktree-final.status'))
if (Compare-Object -ReferenceObject $baselineStatus -DifferenceObject $currentStatus) {
	throw 'worktree status path set changed outside the established T4/T5 scope'
}
Write-Output 'worktree_status_path_set=unchanged'

$productPaths = @(
	'patches/files/usr/share/rpcd/ucode/c8.sms_forward.uc',
	'patches/files/usr/share/rpcd/acl.d/luci-app-c8modem.json',
	'patches/files/etc/init.d/c8-sms-forward',
	'Scripts/InstallC8Overlay.sh',
	'patches/files/usr/bin/c8-sms-forward',
	'patches/files/www/luci-static/resources/view/c8modem/sms-forward.js'
)
$productStatus = @(& git status --short -- @productPaths)
if ($LASTEXITCODE -ne 0) { throw "scoped git status exited $LASTEXITCODE" }
$actualProductPaths = @($productStatus | ForEach-Object { $_.Substring(3) } | Sort-Object)
$expectedProductPaths = @(
	'Scripts/InstallC8Overlay.sh',
	'patches/files/etc/init.d/c8-sms-forward',
	'patches/files/usr/bin/c8-sms-forward',
	'patches/files/usr/share/rpcd/acl.d/luci-app-c8modem.json',
	'patches/files/usr/share/rpcd/ucode/c8.sms_forward.uc'
) | Sort-Object
if (Compare-Object -ReferenceObject $expectedProductPaths -DifferenceObject $actualProductPaths) {
	throw 'production status differs from exact four T5 files plus pre-existing T2 backend'
}
$productStatus | Set-Content -LiteralPath (Join-Path $e5 'cross-fix-production.status') -Encoding ascii
Write-Output 'production_scope=exact_four_T5_files_plus_preexisting_T2_backend'

$fixturePaths = @(Get-ChildItem -LiteralPath (Join-Path $repo 'Scripts\fixtures\c8-sms-forward-rpc') -File |
	ForEach-Object { $_.FullName.Substring($repo.Length + 1).Replace('\', '/') })
$manifestPaths = @(
	'Scripts/TestC8SmsForwardRpc.sh',
	'.superpowers/sdd/task-4-report.md',
	'.superpowers/sdd/task-5-report.md'
) + $fixturePaths + $productPaths
$manifest = foreach ($rel in ($manifestPaths | Sort-Object -Unique)) {
	$full = Join-Path $repo $rel
	if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "missing scoped file: $rel" }
	$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $full).Hash.ToLowerInvariant()
	"$hash  $rel"
}
$manifest | Set-Content -LiteralPath (Join-Path $e5 'cross-fix-after.sha256') -Encoding ascii
$manifest | Set-Content -LiteralPath (Join-Path $e4 'cross-fix-after.sha256') -Encoding ascii

$before = @{}
Get-Content -LiteralPath (Join-Path $e5 'cross-fix-before.sha256') | ForEach-Object {
	if ($_ -match '^(\S+)\s{2}(.+)$') { $before[$matches[2]] = $matches[1] }
}
foreach ($rel in @(
	'patches/files/usr/share/rpcd/acl.d/luci-app-c8modem.json',
	'patches/files/etc/init.d/c8-sms-forward',
	'patches/files/usr/bin/c8-sms-forward',
	'patches/files/www/luci-static/resources/view/c8modem/sms-forward.js'
)) {
	$current = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo $rel)).Hash.ToLowerInvariant()
	if (-not $before.ContainsKey($rel) -or $before[$rel] -ne $current) { throw "cross-fix invariant changed: $rel" }
	Write-Output "unchanged_sha256=$current path=$rel"
}

$canonical = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo 'Scripts\fixtures\c8-sms-forward-rpc\canonical-facade.uc')).Hash
$production = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo 'patches\files\usr\share\rpcd\ucode\c8.sms_forward.uc')).Hash
if ($canonical -ne $production) { throw 'production facade differs from canonical fixture' }
Write-Output "canonical_product_sha256=$($canonical.ToLowerInvariant())"

foreach ($rel in @(
	'Scripts/fixtures/c8-sms-forward-rpc/canonical-facade.uc',
	'patches/files/usr/share/rpcd/ucode/c8.sms_forward.uc'
)) {
	if (Select-String -LiteralPath (Join-Path $repo $rel) -Pattern '\bdie\s*\(' -Quiet) {
		throw "reachable die remains: $rel"
	}
}
Write-Output 'reachable_die=absent'

if (-not (Select-String -LiteralPath (Join-Path $e5 'cross-fix-rpc-green.log') -SimpleMatch 'CONTRACT SUMMARY: pass=42 intended_fail=0 generic_fail=0 total=42' -Quiet)) {
	throw 'missing 42/42 RPC summary'
}
if ((Get-Content -LiteralPath (Join-Path $e5 'cross-fix-rpc-green.exit') -Raw).Trim() -ne 'exit=0') {
	throw 'RPC GREEN exit is not zero'
}
if (-not (Select-String -LiteralPath (Join-Path $e5 'backend-regression.log') -SimpleMatch 'CONTRACT SUMMARY: pass=46 intended_fail=0 generic_fail=0 total=46' -Quiet)) {
	throw 'missing recorded 46/46 backend summary'
}
if ((Get-Content -LiteralPath (Join-Path $e5 'backend-regression.exit') -Raw).Trim() -ne 'exit=0') {
	throw 'recorded backend exit is not zero'
}
Write-Output 'rpc_42_of_42=accepted'
Write-Output 'backend_46_of_46_and_hash=accepted'
Write-Output 'cross_fix_invariants=accepted'
