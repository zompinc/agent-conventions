---
name: zomp-jetkvm
description: Driving a remote machine through a JetKVM - the web UI (video, Paste text, Virtual Media), its SSH shell and storage, using it as a jump host into the target's network, and the keyboard, video and firmware quirks that waste time. Load this before operating any machine through a JetKVM, mounting a disk image on one, or flashing firmware or reinstalling an OS remotely through it.
---

# Remote machines through a JetKVM

These extend `AGENTS.md`, which stays in force. A JetKVM gives you HDMI video in, USB keyboard/mouse/storage out, and a small Linux box on the target's network. Treat it as remote hands, not as a shell on the target.

## Before acting on the target

- **Verify the machine you are acting on, in the same command that acts.** Anything destructive (firmware flash, disk wipe, OS reinstall, encryption change) starts with a check of model, current BIOS version and hostname, and aborts on mismatch:

  ```powershell
  $m=(Get-CimInstance Win32_ComputerSystem).Model; $b=(Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion
  "$env:COMPUTERNAME / $m / BIOS $b"
  if ($m -eq 'V3' -and $b -eq '1.05') { <destructive step> } else { 'WRONG MACHINE - aborted' }
  ```

  Never pick a target by guessing which unknown IP on the JetKVM's LAN is the machine on screen. Other machines on that LAN may accept the same SSH key; one answering is not evidence it is the right one.
- **Credentials stay with the user.** BitLocker recovery keys, passwords and PINs are typed by the user (on the device, or through the JetKVM themselves). Tell them how; do not send them as keystrokes.
- A firmware update usually triggers a BitLocker recovery prompt on the next boot. Check BitLocker from an *elevated* shell first (`manage-bde -status C:`); a non-elevated `Get-BitLockerVolume` misreports "no BitLocker volume". Suspend it (`manage-bde -protectors -disable C: -RebootCount 2`) or have the recovery key ready.

## Web UI

- **Click the video once** before sending keys or clicks; until it has focus nothing registers.
- **Mouse is reliable, keys are not.** Plain typed keys can lose Shift (`{` arrives as `[`, capitals as lowercase). Windows key, `Ctrl+Esc` and `Home` were observed not to arrive at all. Open Start with a mouse click on the taskbar (on tablets, click the collapsed taskbar handle first).
- **Use Paste text for anything with symbols or capitals.** It types the text as keystrokes in the selected layout, at roughly 20-30 characters per second.
  - **Do not close the dialog until the paste has finished.** Cancel/close aborts the rest of the paste, leaving a truncated command on the remote line.
  - **Do not press Ctrl+A in the paste box** to clear it: the keystroke can leak through to the target as a literal `a`. Triple-click the old text to select it, then type over it.
  - Setting the textarea value from page JavaScript does not register with the app; type into it.
  - The paste does not press Enter at the end; send `Return` separately after checking the line on screen.
- **Long scripts:** encode them instead of pasting multi-line text. `powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand <base64 of UTF-16LE script>` keeps quoting out of the keystroke path. Budget the paste time (5 KB is about 3 minutes).
- **Fix a mistyped long command without retyping it.** If cursor keys do not arrive, re-run it from history with a correction, for example `iex (Get-History | Where-Object CommandLine -like 'asudo*' | Select-Object -Last 1).CommandLine.Substring(1)`.
- **Elevation:** Windows `sudo` (inline mode) elevates a single command from a normal shell without a UAC dialog to click. A new tab in an elevated Windows Terminal is not guaranteed to be elevated; check the tab title.

## Virtual Media

- Mount images from **JetKVM Storage** (`/userdata/jetkvm/images/`). Choose **Disk** for a writable USB stick (FAT32 image with tools and payload), **CD/DVD** for ISOs. The target sees a new drive (Windows: AutoPlay toast with the volume label).
- Build FAT images on any Linux host: `truncate -s 64M x.img; mkfs.vfat -F 32 -n LABEL x.img; mcopy -i x.img <files> ::/`.
- Eject the media when done; it stays attached across reboots and can change boot order.

## SSH shell and storage

- With developer mode on, `ssh root@<jetkvm>` works (dropbear). There is **no sftp-server**, so `scp` fails; copy with `ssh root@<jetkvm> 'cat > /userdata/jetkvm/images/x.img' < x.img` and compare `md5sum` on both ends.
- `/userdata` persists across JetKVM updates. Extra services (for example Tailscale under `/userdata/tailscale`) start from scripts in `/userdata/init.d/`.
- **Jump host:** `ssh -J root@<jetkvm> user@<target-ip>` reaches machines on the JetKVM's LAN. `ip -4 route` and `/proc/net/arp` on the JetKVM show that LAN. See "Before acting on the target" before using a host found this way.

## Power and firmware screens

- A JetKVM powered from the target's USB dies when the target powers off or cold boots, so firmware hotkeys (Delete for setup, F7/F11 for the boot menu) can only be sent on warm restarts. Prefer a separate USB power source on a bench.
- **USB-C tablets and some laptops output no external video during firmware stages** (POST, BIOS setup, capsule flash, BitLocker recovery). The JetKVM shows "No HDMI signal" while the internal panel shows the screen. Have the user read the internal screen, and do not interpret "no signal" as a hang. A Num/Caps Lock indicator change in the JetKVM UI shows the firmware is alive.
- `shutdown /r /fw` (reboot into firmware setup) fails with error 203 on firmware that does not advertise boot-to-setup support; fall back to the setup hotkey on a warm restart.
- After a BIOS flash, re-check settings that default hostile to remote use: AC power loss behaviour, network stack/PXE, boot order.
