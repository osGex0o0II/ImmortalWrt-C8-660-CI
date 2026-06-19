# Closed 24.10 Archive

This directory keeps the retired closed-driver 24.10 experiment for reference.
It is intentionally outside `.github/workflows/`, so GitHub Actions will not
show it as an active workflow.

The maintained closed-driver line is:

- `.github/workflows/c8-660-closed-21.02.yml`
- `Config/CLOSED.txt`
- `Config/GENERAL-CLOSED.txt`

## Why Archived

The 24.10 line uses `padavanonly/immortalwrt-mt798x-24.10` with kernel 6.6.
It has more unknowns than the 21.02 line:

- C8-660 device support must be injected instead of being built into the tree.
- WARP/HNAT is enabled by default, but the closed 21.02 investigation already
  showed WARP/kernel header compatibility is fragile.
- It has no recent successful build sample in this repository.

Keep 21.02 as the experimental/legacy closed-driver target because it is closer
to the original V12 / SDK 5.4 baseline.
