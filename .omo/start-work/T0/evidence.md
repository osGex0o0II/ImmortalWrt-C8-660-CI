# T0B Baseline and Read-Only Capability Evidence

- Date: 2026-07-15
- Product worktree: `D:/Code/Git/ImmortalWrt-C8-660-SMS-Refactor`
- Evidence worktree: `D:/Code/Git/ImmortalWrt-C8-660-CI`
- Product HEAD: `f97b925d9808ee34b3660ae122df024ebaa31bdd`
- Shell: Git Bash
- SSH client: `C:/Windows/System32/OpenSSH/ssh.exe` (`OpenSSH_for_Windows_9.5p2, LibreSSL 3.8.2`)
- Router SSH topology: source bind `192.168.1.200`, destination `root@192.168.1.1`
- Safety boundary: no `sms_tool recv`, `sms_tool delete`, `sms_tool send`, UCI, service, or remote file-changing command was run. No SMS body or credential is recorded.

## Backend Baseline

Exact command, run from the product worktree:

```bash
bash Scripts/TestC8SmsForward.sh
```

Sanitized combined stdout/stderr:

```text
OK: status JSON exposes SMS timeout and channels
OK: disabled scan returned 0
OK: missing channel scan returned 1
OK: sms_tool timeout scan returned 1
OK: successful scan returned 0
OK: C8 SMS forwarding self-test passed
```

Exit code: `0`.

## LuCI Baseline

Exact command, run from the product worktree:

```bash
bash Scripts/TestC8SmsForwardLuCI.sh
```

Sanitized combined stdout/stderr:

```text
OK: C8 SMS forwarding LuCI JS parses
OK: SMS forwarding menu
OK: SMS forwarding menu target
OK: action click guard
OK: proxy URL validator
OK: HTTP URL validator
OK: channel name validator
OK: sms_tool timeout option
OK: primary channel selector
OK: backup channel selector
OK: per-channel test action
OK: actions save current form before backend calls
OK: log clear action
OK: Save & Apply service restart
OK: forward service restart
OK: ACL "/usr/bin/c8-sms-forward \*"
OK: ACL "/etc/init.d/c8-sms-forward \*"
OK: no broad ACL "/bin/sh
OK: no broad ACL "/bin/sendat 2 \*"
OK: no broad ACL "/usr/bin/cellscan.sh \*"
OK: no broad ACL "/usr/bin/iwinfo \*"
OK: no broad ACL "/usr/share/modem/rm520n.sh"
OK: C8 SMS forwarding LuCI self-test passed
```

Exit code: `0`.

## Read/Send Hashes

Exact command, run from the product worktree:

```bash
sha256sum patches/files/www/luci-static/resources/view/c8modem/sms-read.js patches/files/www/luci-static/resources/view/c8modem/sms-send.js
```

Exact output:

```text
3d3cb0fb72df0c56c20e1c4618ddddba3eedd06f4cdd556258c53f19d6df3ab5 *patches/files/www/luci-static/resources/view/c8modem/sms-read.js
7dc12ab2ec0fe3f539d975eed5ab20d8625435cf4118b584679e1f94b7002e30 *patches/files/www/luci-static/resources/view/c8modem/sms-send.js
```

Exit code: `0`. The same two lines are stored in `D:/Code/Git/ImmortalWrt-C8-660-CI/.omo/start-work/T0/read-send.sha256`.

## Router Probe Command

Windows OpenSSH was invoked from Git Bash with an isolated `%TEMP%/c8-t0b-*-known-hosts-*` file, `StrictHostKeyChecking=accept-new`, a one-use temporary askpass executable, source bind `192.168.1.200`, and destination `root@192.168.1.1`. The credential value is intentionally replaced below.

```bash
SSH_ASKPASS='<temporary helper; credential redacted>' \
SSH_ASKPASS_REQUIRE=force DISPLAY=codex-t0b \
/c/Windows/System32/OpenSSH/ssh.exe -T \
  -b 192.168.1.200 \
  -o BatchMode=no \
  -o PreferredAuthentications='<credential auth method redacted>,keyboard-interactive' \
  -o PubkeyAuthentication=no \
  -o NumberOfPasswordPrompts=1 \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile='<isolated temporary known_hosts>' \
  -o LogLevel=ERROR \
  root@192.168.1.1 'sh -s'
```

The first remote session ran these exact read-only commands:

```sh
opkg list-installed rpcd-mod-ucode
opkg files rpcd-mod-ucode
if [ -x /usr/libexec/rpcd/ucode ]; then ls -l /usr/libexec/rpcd/ucode; elif [ -x /usr/lib/rpcd/ucode ]; then ls -l /usr/lib/rpcd/ucode; else echo 'rpcd ucode executable not found'; exit 1; fi
busybox 2>&1 | sed -n '1p'
command -v jq
jq --version
printf '%s\n' '{"probe":21}' | jq -c '{probe: (.probe * 2)}'
command -v sms_tool
sms_tool --version
sms_tool --help
command -v ucode
ucode -v
ucode -e 'print(6 * 7)'
command -v ubus
ubus -V
ubus -S list | wc -l
command -v curl
curl --version
curl -sS file:///etc/openwrt_release | wc -c
command -v mkdir
mkdir --help
command -v mv
mv --help
command -v date
date --help
date -u '+%Y-%m-%dT%H:%M:%SZ'
```

The target uses `apk`, so a second isolated read-only session ran these exact commands to prove package ownership and versions:

```sh
command -v apk && apk --version
apk info -e rpcd-mod-ucode && apk info rpcd-mod-ucode
apk info -W /usr/lib/rpcd/ucode.so
ls -l /usr/lib/rpcd/ucode.so && test -r /usr/lib/rpcd/ucode.so
apk info -W /usr/bin/sms_tool
apk info -W /usr/bin/ucode
apk info -W /bin/ubus
```

## Router Probe Output

Sanitized exact output from the capability checks follows. Package-cache warnings are omitted because they contain no capability result; their commands still exited `0`.

```text
=== rpcd ucode package via legacy manager ===
$ opkg list-installed rpcd-mod-ucode
sh: opkg: not found
__REMOTE_EXIT_CODE__=127

=== rpcd ucode package files via legacy manager ===
$ opkg files rpcd-mod-ucode
sh: opkg: not found
__REMOTE_EXIT_CODE__=127

=== legacy rpcd ucode executable paths ===
$ if [ -x /usr/libexec/rpcd/ucode ]; then ls -l /usr/libexec/rpcd/ucode; elif [ -x /usr/lib/rpcd/ucode ]; then ls -l /usr/lib/rpcd/ucode; else echo 'rpcd ucode executable not found'; exit 1; fi
rpcd ucode executable not found
__REMOTE_EXIT_CODE__=1

=== jq availability/version/behavior ===
$ command -v jq
/usr/bin/jq
__REMOTE_EXIT_CODE__=0
$ jq --version
jq-1.8.1
__REMOTE_EXIT_CODE__=0
$ printf '%s\n' '{"probe":21}' | jq -c '{probe: (.probe * 2)}'
{"probe":42}
__REMOTE_EXIT_CODE__=0

=== sms_tool availability/version query/help behavior ===
$ command -v sms_tool
/usr/bin/sms_tool
__REMOTE_EXIT_CODE__=0
$ sms_tool --version
sms_tool: unrecognized option: -
usage: [options] send phoneNumber message
       [options] recv
       [options] delete msg_index | all
       [options] status
       [options] ussd code
       [options] at command
__REMOTE_EXIT_CODE__=2
$ sms_tool --help
sms_tool: unrecognized option: -
usage: [options] send phoneNumber message
       [options] recv
       [options] delete msg_index | all
       [options] status
       [options] ussd code
       [options] at command
__REMOTE_EXIT_CODE__=2

=== ucode availability/version query/behavior ===
$ command -v ucode
/usr/bin/ucode
__REMOTE_EXIT_CODE__=0
$ ucode -v
ucode: unrecognized option: v
ucode: unrecognized option: v
Require either -e/-p expression or source file
__REMOTE_EXIT_CODE__=1
$ ucode -e 'print(6 * 7)'
42
__REMOTE_EXIT_CODE__=0

=== ubus availability/version query/read-only behavior ===
$ command -v ubus
/bin/ubus
__REMOTE_EXIT_CODE__=0
$ ubus -V
ubus: unrecognized option: V
Usage: ubus [<options>] <command> [arguments...]
__REMOTE_EXIT_CODE__=1
$ ubus -S list | wc -l
48
__REMOTE_EXIT_CODE__=0

=== curl availability/version/read-only local-file behavior ===
$ command -v curl
/usr/bin/curl
__REMOTE_EXIT_CODE__=0
$ curl --version
curl 8.19.0 (aarch64-openwrt-linux-gnu) libcurl/8.19.0 OpenSSL/3.5.7 zlib/1.3.1 nghttp2/1.66.0
Release-Date: 2026-03-11
Protocols: file ftp ftps http https mqtt mqtts tftp
Features: alt-svc AsynchDNS HSTS HTTP2 HTTPS-proxy IPv6 Largefile libz SSL threadsafe TLS-SRP UnixSockets
__REMOTE_EXIT_CODE__=0
$ curl -sS file:///etc/openwrt_release | wc -c
240
__REMOTE_EXIT_CODE__=0

=== mkdir availability/help behavior ===
$ command -v mkdir
/bin/mkdir
__REMOTE_EXIT_CODE__=0
$ mkdir --help
BusyBox v1.37.0 (2026-07-02 01:40:04 UTC) multi-call binary.
Usage: mkdir [-m MODE] [-p] DIRECTORY...
Create DIRECTORY
__REMOTE_EXIT_CODE__=0

=== mv availability/help behavior ===
$ command -v mv
/bin/mv
__REMOTE_EXIT_CODE__=0
$ mv --help
BusyBox v1.37.0 (2026-07-02 01:40:04 UTC) multi-call binary.
Usage: mv [-finT] SOURCE DEST
or: mv [-fin] SOURCE... { -t DIRECTORY | DIRECTORY }
Rename SOURCE to DEST, or move SOURCEs to DIRECTORY
__REMOTE_EXIT_CODE__=0

=== date availability/help/UTC behavior ===
$ command -v date
/bin/date
__REMOTE_EXIT_CODE__=0
$ date --help
BusyBox v1.37.0 (2026-07-02 01:40:04 UTC) multi-call binary.
Usage: date [OPTIONS] [+FMT] [[-s] TIME]
Display time (using +FMT), or set time
__REMOTE_EXIT_CODE__=0
$ date -u '+%Y-%m-%dT%H:%M:%SZ'
2026-07-15T11:13:08Z
__REMOTE_EXIT_CODE__=0

=== apk availability/version ===
$ command -v apk && apk --version
/usr/bin/apk
apk-tools 3.0.5, compiled for aarch64.
__REMOTE_EXIT_CODE__=0

=== rpcd ucode installed package ===
$ apk info -e rpcd-mod-ucode && apk info rpcd-mod-ucode
rpcd-mod-ucode
rpcd-mod-ucode-2026.06.04~28faf640-r1 description:
Allows implementing plugins using ucode scripts.
rpcd-mod-ucode-2026.06.04~28faf640-r1 installed size:
20 KiB
__REMOTE_EXIT_CODE__=0

=== rpcd ucode module owner/file ===
$ apk info -W /usr/lib/rpcd/ucode.so
/usr/lib/rpcd/ucode.so is owned by rpcd-mod-ucode-2026.06.04~28faf640-r1
__REMOTE_EXIT_CODE__=0
$ ls -l /usr/lib/rpcd/ucode.so && test -r /usr/lib/rpcd/ucode.so
-rwxr-xr-x    1 root     root         20586 Jul  2 09:40 /usr/lib/rpcd/ucode.so
__REMOTE_EXIT_CODE__=0

=== package versions for CLIs without version flags ===
$ apk info -W /usr/bin/sms_tool
/usr/bin/sms_tool is owned by sms-tool-2025.08.23~491ffdb0-r1
__REMOTE_EXIT_CODE__=0
$ apk info -W /usr/bin/ucode
/usr/bin/ucode is owned by ucode-2026.01.16~85922056-r1
__REMOTE_EXIT_CODE__=0
$ apk info -W /bin/ubus
/bin/ubus is owned by ubus-2026.06.28~24864e78-r2
__REMOTE_EXIT_CODE__=0
```

Both successful SSH sessions exited `0`.

## Isolated Host-Key Evidence and Cleanup

Windows `ssh-keygen.exe -lf <isolated-known-hosts>` returned:

```text
256 SHA256:T389sVoW7UX8KTEC2V4L+sjLGL4KYdcvCh545/K17i0 192.168.1.1 (ED25519)
```

`ssh-keygen.exe` exit code: `0` for both successful sessions.

Each session then ran the equivalent of:

```bash
rm -f "$ASKPASS" "$KNOWN_HOSTS"
test ! -e "$ASKPASS" && test ! -e "$KNOWN_HOSTS"
```

Exact cleanup receipts:

```text
CLEANUP_RECEIPT: removed temporary askpass and isolated known_hosts; verified absent
CLEANUP_RECEIPT: removed apk-probe askpass and isolated known_hosts; verified absent
```

## Baseline Conclusion

- Both baseline test scripts exited `0`.
- Both immutable JavaScript hashes were recorded.
- `rpcd-mod-ucode-2026.06.04~28faf640-r1` is installed and owns readable `/usr/lib/rpcd/ucode.so`, positively proving rpcd ucode plugin support.
- `jq`, `sms_tool`, `ucode`, `ubus`, `curl`, `mkdir`, `mv`, and `date` are available; versions and safe behavior are recorded above.
- The probe made no requested-forbidden router calls and left no temporary credential or isolated known-host artifact.
