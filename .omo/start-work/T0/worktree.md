# T0A Worktree Evidence

- Main: `D:/Code/Git/ImmortalWrt-C8-660-CI`
- External: `D:/Code/Git/ImmortalWrt-C8-660-SMS-Refactor`
- Branch: `codex/sms-forward-refactor`
- HEAD: `f97b925d9808ee34b3660ae122df024ebaa31bdd`
- Snapshot: `C:/Users/Administrator/AppData/Local/Temp/c8-sms-user-worktree.patch`
- Snapshot SHA256: `543ab772ad16f879dfdcabe3a5963ab3cc7c1aa5ba2dd47ea0799dc5818b4d05`

`git worktree add`, `git apply --check`, and `git apply` completed. The compound command returned 1 only because its first parity expression included the newly untracked main-workspace `.omo/` directory. A follow-up comparison using `git status --short --untracked-files=no` proved exact parity of these 11 tracked paths in both worktrees:

```text
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
```

No SMS refactor product file is modified in the external worktree. No file is staged or committed.
