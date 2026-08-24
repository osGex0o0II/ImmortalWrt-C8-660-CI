# C8-660 SMS 转发任务交接

交接时间：2026-07-18（Asia/Shanghai）

这份文档交接的是当前 Codex 任务，不代表短信转发重构已经完成。当前状态是：方案已审查通过，隔离工作树和基线已完成，T1 测试正在外部工作树中进行但尚未获得有效 RED 证据；生产后端、RPC、LuCI 和路由器正式修复都还没有完成。

## 1. 当前结论

已经确认的线上根因：

- 目标设备是 NRadio C8-660（`nradio,wt9103`），运行 ImmortalWrt `25.12-SNAPSHOT`，内核 `6.12.94`。
- 路由器地址是 `192.168.1.1`，SSH 流量从 `192.168.1.200` 绑定出去。root 凭据由用户在会话中提供过，但禁止把密码写入仓库、日志或本文件。
- `/usr/bin/c8-sms-forward` 原实现使用 `jq scan("[0-9]+")` 解析短信索引。
- 目标机默认 jq 没有 Oniguruma regex 支持。实际错误是：`jq was compiled without ONIGURUMA regex library. match/test/sub and related functions are not available.`
- `sms_tool recv` 在真实设备上可正常返回 4 条短信，返回根对象、消息数组和数字类型的 `index`；因此故障在转发脚本解析层，不是 SIM 无短信或 `sms_tool recv` 本身不可用。
- 现有实现的其他已确认缺陷：禁用状态的 `once` 返回值容易误导；没有跨进程扫描锁；`pending.json` 直接覆盖；`sent.keys` 追加不是崩溃安全；ACK、删除和重启恢复没有明确状态机；LuCI 使用 `fs.exec`，并且 Save/Apply 没有可靠经过 `uci.apply()`；禁用通道仍显示可点击 Test；移动宽度 390px 时浮动工具栏会覆盖内容。

安全复现曾证明：开启转发后执行一次仍返回解析失败；消息数量始终为 4；转发恢复为禁用；UCI 变化数回到 0；没有发送或删除短信。PushPlus 的网络探针曾返回 HTTP 200，Telegram 探针超时，但这不是本次 parser 根因。

## 2. 工作区和分支

主工作区：

`D:\Code\Git\ImmortalWrt-C8-660-CI`

- 当前分支：`main`
- HEAD：`f97b925d9808ee34b3660ae122df024ebaa31bdd`
- 主工作区保留用户原有的 11 个受跟踪修改，不能回滚、覆盖或重置：
  - `.github/workflows/c8-660-open.yml`
  - `.github/workflows/update-proxy-locks.yml`
  - `.gitignore`
  - `Config/GENERAL.txt`
  - `Config/OPEN.txt`
  - `README.md`
  - `Scripts/ApplyProxyLocks.sh`
  - `Scripts/Packages.sh`
  - `Scripts/PatchHomeProxyModern.sh`
  - `Scripts/Settings.sh`
  - `patches/filogic-c8-660.mk`
- 这些用户修改中已经包含包保留要求：TTYD/Web 终端、UPnP、WOL、ZeroTier 保留；tcpdump、socat、mtd-rw、SFTP、package-manager UI、partexp 等无关项继续排除。
- 主工作区还包含本任务的 `.omo/` 计划、Boulder 状态和 T0 证据，以及本文件；这些是任务管理文件，不是用户的固件功能改动。

外部实现工作树：

`D:\Code\Git\ImmortalWrt-C8-660-SMS-Refactor`

- 分支：`codex/sms-forward-refactor`
- HEAD：`f97b925d9808ee34b3660ae122df024ebaa31bdd`
- 已应用用户脏差异快照，基线时与主工作区的 11 个受跟踪修改完全一致。
- 当前额外存在 T1 测试差异：`Scripts/TestC8SmsForward.sh` 和 `Scripts/fixtures/c8-sms-forward/` 下 17 个 JSON fixture。
- 当前没有后端、RPC、ACL、init 或 LuCI 生产实现差异。
- 不要在主工作区直接继续写产品代码；所有实现继续在外部工作树进行，最后只把验证过的 SMS-only 差异带回主工作区。

快照：

- `C:\Users\Administrator\AppData\Local\Temp\c8-sms-user-worktree.patch`
- SHA256：`543ab772ad16f879dfdcabe3a5963ab3cc7c1aa5ba2dd47ea0799dc5818b4d05`
- 大小：71938 bytes
- 在主工作区回写并独立验证完成前不要删除。

## 3. 已完成的 T0 基线

T0 已由独立验证者 `APPROVE`，证据在：

- [worktree.md](.omo/start-work/T0/worktree.md)
- [evidence.md](.omo/start-work/T0/evidence.md)
- [read-send.sha256](.omo/start-work/T0/read-send.sha256)
- [verdict.md](.omo/start-work/T0/verdict.md)

关键事实：

- 两个原有基线测试都退出 0：`bash Scripts/TestC8SmsForward.sh` 和 `bash Scripts/TestC8SmsForwardLuCI.sh`。
- `sms-read.js` 基线 SHA256：`3d3cb0fb72df0c56c20e1c4618ddddba3eedd06f4cdd556258c53f19d6df3ab5`。
- `sms-send.js` 基线 SHA256：`7dc12ab2ec0fe3f539d975eed5ab20d8625435cf4118b584679e1f94b7002e30`。
- 目标机通过 `apk` 确认安装 `rpcd-mod-ucode-2026.06.04~28faf640-r1`，并有 `/usr/lib/rpcd/ucode.so`；因此可以使用 rpcd ucode 插件。
- 目标机可用：`jq 1.8.1`、`sms_tool`、`ucode`、`ubus`、`curl 8.19.0`、BusyBox `mkdir`/`mv`/`date`。
- `opkg` 在目标机不存在，目标机使用 `apk`。不要用 opkg 作为后续判断依据。
- T0 的 SSH known_hosts、askpass 和临时凭据文件已清理；T0 未调用 `sms_tool recv/delete/send`，未修改 UCI、服务或路由器文件。

## 4. T1 当前状态

T1 worker `019f6596-cd01-7340-999b-e79d8e38e5dc` 已写入部分测试后因用量限制退出：

`You've hit your usage limit. Upgrade to Pro ... or try again at Jul 22nd, 2026 8:56 AM.`

因此不能把 T1 标记完成。没有可靠的 `red-parser.md`，也没有独立 T1 verifier verdict。下一 Agent 必须先检查现有测试，不要假定它完整或正确。

已写入外部工作树的 fixture 包括：

- `live-numeric-index.json`
- `index-number.json`
- `index-numeric-string.json`
- `index-array.json`
- `index-comma-string.json`
- `index-embedded-invalid.json`
- `index-mixed-array-invalid.json`
- `index-null-invalid.json`
- `root-msg.json`
- `root-messages.json`
- `root-array.json`
- `malformed.json`
- `empty-input.json`
- `empty-inbox.json`
- `multipart-reverse.json`
- `multipart-gap.json`
- `multipart-duplicate.json`

`Scripts/TestC8SmsForward.sh` 已被扩展为使用临时 fake `sms_tool`、fake `curl`、可模拟无 regex 的 jq wrapper、fake sleep 和 fixture；它还设置了 `SMS_TOOL_BIN`，并记录 fake 调用。下一 Agent 要重点检查：

1. fake jq 是否真正覆盖了后端所有 regex 调用；
2. fake `sms_tool`/curl 是否会把测试请求误判为生产成功；
3. 每个场景是否有超时，避免测试挂死；
4. 失败是否是目标行为缺失，而不是 fixture、PATH、权限或脚本本身错误；
5. `c8-sms-forward` 生产文件 SHA 是否仍等于 T0 基线；
6. 运行结束是否删除 `/tmp/c8-sms-forward`、日志和临时 fake bin；
7. 补齐 lock、journal、ACK/delete、modem/SIM/port 和并发场景后，再写 T1 RED 证据。

## 5. 已批准的实现边界

不要安装 WeChatPush。只借鉴其通道抽象思路，唯一 SMS owner 仍是 `modem/sms` 和 `sms_tool`。

建议的纵向修复：

1. 后端保留 `/usr/bin/c8-sms-forward` 作为 CLI/服务编排入口，先不做过大的模块拆分。
2. 去掉 regex 解析，使用 regex-free jq 原语和显式索引类型验证；不要通过安装 `jq-full` 或 Oniguruma 绕过目标兼容性问题。
3. 使用 `mkdir` 锁，写入 owner/timestamp，并做保守 stale lock 恢复；不要假设目标一定有 `flock`。
4. 使用同目录临时文件加原子 `mv` 保存无短信正文的有界 journal。状态顺序：`PENDING -> ACKED -> DELETED`。重启遇到 `ACKED` 只能删除，不能重复发送。
5. CLI 退出码建议：0 成功，1 operational，2 invocation/config，3 busy，4 parse/schema，5 delivery failure，124 timeout；RPC 返回更细的 `error_code`。
6. 新增窄 rpcd ucode facade：`/usr/share/rpcd/ucode/c8.sms_forward.uc`，只暴露固定方法和固定后端子命令。目标已确认支持 rpcd ucode。
7. RPC 至少覆盖 `status`、`preflight`、`once`、`test_channel`、`log`、`clear_log`；返回 `{ ok, state, stage, error_code, message, details }`，不得返回密码、短信正文、完整 sender 或敏感 token。
8. ACL 只给该 RPC object/method 权限，移除 forwarding 相关的宽泛 `file.exec`；不要影响短信读取/发送页面正常权限。
9. LuCI 用 `rpc.declare`，forwarding 操作不能继续使用浏览器端 `fs.exec`。Save & Apply 必须是 save、`uci.apply()`/confirm、一次 reload 的顺序。
10. UI 把状态、阶段、错误原因和下一步用中文结构化显示；通道未启用/未 ready 时禁用危险 Test/Scan；修复 390x844 浮动工具栏遮挡。
11. `sms-read.js` 和 `sms-send.js` 默认不改，只跑行为回归并再次比较 SHA；只有出现由本次改动引入的真实问题才允许改。

官方契约参考：

- rpcd ucode loader：`https://git.openwrt.org/project/rpcd/plain/ucode.c`
- rpcd ucode example：`https://github.com/openwrt/rpcd/blob/master/examples/ucode/example-plugin.uc`

## 6. 后续执行顺序

按以下顺序继续，不能跳过 RED 或独立 verifier：

### T1：完成测试 RED

- 在外部工作树先检查并修完现有 `Scripts/TestC8SmsForward.sh` 和 fixtures。
- 只改测试及 fixture，不改生产后端。
- 运行测试，得到带命名失败的非零结果；如果当前实现因为 `jq`/fixture 问题挂死，先修测试 harness 并加边界时间。
- 写 `.omo/start-work/T1/red-parser.md`（或同目录合并 RED 证据），记录命令、退出码、命名失败、后端 SHA、fixture 清单和清理收据。
- 由另一个 agent 独立复跑并写 `.omo/start-work/T1/verdict.md`，必须 `APPROVE`。

### T2/T3：后端实现和验证

- T2 只能改 `patches/files/usr/bin/c8-sms-forward` 及必要 backend defaults。
- 先修 noregex parser，再修状态/退出码、硬预检、manual post-parse `NO_READY_CHANNEL`、mkdir lock、原子 journal、ACK-before-delete、ACKED 恢复、multipart/duplicate idempotency。
- 所有预检失败（错误配置、端口 busy/missing、modem/SIM 不可用）必须在读短信、发送、删除前返回；安全手动 once 允许先读取并解析真实收件箱，然后在通道门返回 `NO_READY_CHANNEL`，不发送、不 ACK、不删除。
- 两个 concurrent once 必须出现一条真实执行路径和一条 `BUSY`。
- T3 独立反证 parser coercion、lock bypass、ACK/delete replay，并检查 journal 无正文/密钥。

### T4/T5：RPC、ACL、init

- 先新增并让 `Scripts/TestC8SmsForwardRpc.sh` RED，再实现 `/usr/share/rpcd/ucode/c8.sms_forward.uc`、ACL、overlay 条目和 init/procd reload 连接。
- 禁止未知方法、未知字段、任意 shell 参数；验证 secret masking 和固定 backend 子命令。
- 绿后由独立 verifier 检查 rpcd method/ACL/reload 语义。

### T6/T7：LuCI

- 先让 `Scripts/TestC8SmsForwardLuCI.sh` 对 `rpc.declare`、无 forwarding `fs.exec`、`uci.apply()`、单次 reload、禁用按钮、中文错误和移动布局产生 RED。
- 再只改 `patches/files/www/luci-static/resources/view/c8modem/sms-forward.js` 及 view-local style。
- 必须跑 `node --check` 和真实页面 QA。使用页面：`http://192.168.1.1/cgi-bin/luci/admin/modem/sms/forward`。
- 需要浏览器技能做 desktop 与 390x844 截图、console/network 检查；截图保留到最终审查后再删。

### T8：回归

- 验证 `sms-read.js` 使用 readport、`sms-send.js` 使用 sendport，SHA 与 T0 一致。
- 运行 backend/RPC/LuCI tests、clean overlay install、所有 `patches/files/www/luci-static/resources/view/c8modem/*.js` 的 `node --check`、workflow YAML parse、所有 shell `sh -n`、`git diff --check`。
- 再确认 TTYD、UPnP、WOL、ZeroTier 保留，tcpdump/socat/mtd-rw/SFTP/package-manager/partexp 仍排除。

### T9/T10：真实路由器安全 canary 和回滚

- 只在本地所有测试通过并完成独立审查后部署临时 overlay。
- 先备份被替换文件、记录 SHA/UCI/service/inbox/forwarding 状态。每次 SSH 用隔离 known_hosts，不要使用 Windows `NUL` 作为 known-host 文件。
- 通道保持 disabled/unready。预检后端是否支持 `SMS_TOOL_BIN` 和 PATH wrapper；当前旧后端默认 `SMS_TOOL_BIN=/usr/bin/sms_tool`，所以 canary 必须显式设置：`SMS_TOOL_BIN=/tmp/c8-sms-qa/bin/sms_tool`。
- fake `sms_tool` 的 `recv` 可透传真实 `/usr/bin/sms_tool` 并计数；delete 必须拒绝并计数。fake curl 必须拒绝并计数。命令预期：解析 4 条、`NO_READY_CHANNEL`、`recv_attempts=1`、`send_attempts=0`、`delete_attempts=0`、收件箱仍为 4。
- T9 留下临时部署给 T10 做 LuCI QA；T10 完成后恢复文件/UCI/service，删除 wrappers/state/log/backups/known_hosts，验证原 SHA 和 inbox，再关浏览器。
- 不得进行真实 provider 外发。

### T11：SMS-only 回写主工作区

- 用 allowlist 生成 SMS-only patch，排除主工作区原 11 项用户修改。
- 在主工作区先 `git apply --check`，确认目标文件自快照以来没有被用户改动，再由独立 integration worker 应用。
- 不 commit、不 stage、不 push。完成后保留外部工作树到最终验证结束。

## 7. 当前任务管理文件

- 执行计划：[.omo/plans/c8-sms-forward-refactor.md](.omo/plans/c8-sms-forward-refactor.md)
- Boulder：[.omo/boulder.json](.omo/boulder.json)，当前 `current_task` 是 `T1`。
- T0 证据目录：[.omo/start-work/T0](.omo/start-work/T0)
- 超级工作账本位于：`C:\Users\Administrator\AppData\Local\Temp\ulw-20260715-iYmBiz.md`。这是临时账本，不要当作产品文件。
- 主工作区中已有 `.omo/ulw-loop/...` 运行状态目录，不要删除或回滚；交接完成前只读即可。

## 8. 禁止事项

- 不要 `git reset --hard`、`git checkout --`、清理用户 11 项修改或删除 `.omo` 证据。
- 不要安装 WeChatPush，不要把 WeChatPush 作为 SMS owner。
- 不要把路由器密码、SMS body、token、完整 sender、provider secret 写入任何仓库文件或日志。
- 不要启用真实 provider、不要真的删除现有 4 条短信、不要在没有备份和回滚清单时覆盖路由器文件。
- 不要在 T1 RED 前修改生产后端；不要在 T3/T5/T7/T8 的独立验证之前推进下一层。
- 不要自动 commit、push 或创建 PR。

## 9. 交接完成定义

下一 Agent 只有在以下全部满足后才能说“完成”：后端 parser/lock/journal/ACK 状态测试绿；窄 RPC/ACL 和真实 save/apply 绿；LuCI desktop/390px 真实页面通过；SMS read/send 回归和包/overlay/build 检查绿；C8-660 canary 明确 4 条解析、0 发送、0 删除且回滚恢复；SMS-only 差异安全回写主工作区；五路独立最终审查无条件 `APPROVE`；主工作区无 commit/stage；所有临时凭据、known_hosts、router backup/wrapper、浏览器页和 QA 临时物均有清理收据。
