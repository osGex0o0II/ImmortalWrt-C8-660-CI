$ErrorActionPreference = 'Stop'

$repo = 'D:\Code\Git\ImmortalWrt-C8-660-SMS-Refactor'
$evidence = 'D:\Code\Git\ImmortalWrt-C8-660-CI\.omo\start-work\T5'
Set-Location -LiteralPath $repo

$productionPaths = @(
	'patches/files/usr/share/rpcd/ucode/c8.sms_forward.uc',
	'patches/files/usr/share/rpcd/acl.d/luci-app-c8modem.json',
	'patches/files/etc/init.d/c8-sms-forward',
	'Scripts/InstallC8Overlay.sh',
	'patches/files/usr/bin/c8-sms-forward',
	'patches/files/www/luci-static/resources/view/c8modem/sms-forward.js'
)

Write-Output '$ git diff --check'
& git diff --check
if ($LASTEXITCODE -ne 0) {
	throw "git diff --check exited $LASTEXITCODE"
}
Write-Output 'git_diff_check_exit=0'

$afterManifest = foreach ($rel in $productionPaths) {
	$full = Join-Path $repo $rel
	if (Test-Path -LiteralPath $full -PathType Leaf) {
		$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $full).Hash.ToLowerInvariant()
		"$hash  $rel"
	} else {
		"MISSING  $rel"
	}
}
$afterManifest | Set-Content -LiteralPath (Join-Path $evidence 'production-after.sha256') -Encoding ascii

$productionStatus = @(& git status --short -- @productionPaths)
if ($LASTEXITCODE -ne 0) {
	throw "scoped git status exited $LASTEXITCODE"
}
$productionStatus | Set-Content -LiteralPath (Join-Path $evidence 'production-after.status') -Encoding ascii

$worktreeStatus = @(& git status --short)
if ($LASTEXITCODE -ne 0) {
	throw "worktree git status exited $LASTEXITCODE"
}
$worktreeStatus | Set-Content -LiteralPath (Join-Path $evidence 'worktree-final.status') -Encoding ascii

$diffStat = @(& git diff --stat -- @productionPaths)
if ($LASTEXITCODE -ne 0) {
	throw "scoped git diff --stat exited $LASTEXITCODE"
}
$diffStat | Set-Content -LiteralPath (Join-Path $evidence 'production-final.diffstat') -Encoding ascii

$actualPaths = @($productionStatus | ForEach-Object { $_.Substring(3) } | Sort-Object)
$expectedPaths = @(
	'Scripts/InstallC8Overlay.sh',
	'patches/files/etc/init.d/c8-sms-forward',
	'patches/files/usr/bin/c8-sms-forward',
	'patches/files/usr/share/rpcd/acl.d/luci-app-c8modem.json',
	'patches/files/usr/share/rpcd/ucode/c8.sms_forward.uc'
) | Sort-Object
$actualPaths | Set-Content -LiteralPath (Join-Path $evidence 'production-after.paths') -Encoding ascii
$expectedPaths | Set-Content -LiteralPath (Join-Path $evidence 'production-expected.paths') -Encoding ascii
if (Compare-Object -ReferenceObject $expectedPaths -DifferenceObject $actualPaths) {
	throw 'production scope differs from the exact T5 plus pre-existing T2 set'
}
Write-Output 'production_scope=exact_four_T5_files_plus_preexisting_T2_backend'

$beforeHashes = @{}
Get-Content -LiteralPath (Join-Path $evidence 'production-before.sha256') | ForEach-Object {
	if ($_ -match '^(\S+)\s{2}(.+)$') {
		$beforeHashes[$matches[2]] = $matches[1]
	}
}
$afterHashes = @{}
$afterManifest | ForEach-Object {
	if ($_ -match '^(\S+)\s{2}(.+)$') {
		$afterHashes[$matches[2]] = $matches[1]
	}
}

foreach ($rel in @(
	'patches/files/usr/bin/c8-sms-forward',
	'patches/files/www/luci-static/resources/view/c8modem/sms-forward.js'
)) {
	if (-not $beforeHashes.ContainsKey($rel) -or $beforeHashes[$rel] -ne $afterHashes[$rel]) {
		throw "invariant hash changed: $rel"
	}
	Write-Output "unchanged_sha256=$($afterHashes[$rel]) path=$rel"
}

Write-Output 'final_invariants=accepted'
