---
name: zomp-android-adb
description: Driving an Android phone over adb for device testing - wireless debugging, keeping the screen usable, tapping through Settings with uiautomator, pairing and unpairing Bluetooth devices without root, reading bond and link state, and capturing logcat. Load this before using adb to control a phone, pair or unpair a Bluetooth device on it, or read its logs during a hardware test.
---

# Android over adb

These extend `AGENTS.md`, which stays in force.

## Connecting

- **Always pass `-s <serial>`.** With wireless debugging the same phone is usually listed twice (`<ip>:<port>` and an mDNS `adb-<serial>._adb-tls-connect._tcp` entry), and a bare `adb` then fails with "more than one device".
- **Wireless debugging dies when the phone changes Wi-Fi network**, for example when a test makes it join a device's access point. The device shows `offline`; the user has to reconnect, and the port usually changes. Expect it, and read the result from the other end (the device's own log) instead of waiting on adb.
- **In Git Bash, `export MSYS_NO_PATHCONV=1`** before any command with a device path. Otherwise `/sdcard/ui.xml` becomes `C:/Program Files/Git/sdcard/ui.xml` on the phone side.

## Keeping the screen usable

- Taps cannot get past a PIN lock screen. Check with `adb shell dumpsys window | grep isKeyguardShowing`; if it is `true`, ask the user to unlock.
- `adb shell svc power stayon true` keeps the screen on only while the phone is charging (`dumpsys battery`). Otherwise raise `settings put system screen_off_timeout <ms>`.
- **Record every setting you change and put it back** when the test is done (`settings get` first). Tell the user what you changed if you leave it changed.

## Tapping through the UI

1. `adb shell uiautomator dump /sdcard/ui.xml` and `adb pull` it. Each `<node>` has `text`, `content-desc`, `resource-id` and `bounds="[x0,y0][x1,y1]"`; tap the centre with `adb shell input tap X Y`.
1. Dump again after every tap. Screens and dialogs change, and stale coordinates tap the wrong thing.
1. Scroll with `input swipe`; a long list needs a find-or-scroll loop. Dialog buttons have ids `button1` (confirm) and `button2` (cancel).

Script it (a small Python helper that dumps, finds by text or description, and taps) once a sequence is repeated.

## Bluetooth

- Open settings with `adb shell am start -a android.settings.BLUETOOTH_SETTINGS`. On Samsung the screen lists paired devices, then **Available devices**; tap **Scan** to rescan, or a new device never appears.
- **Pair:** tap the device's title under Available devices, then **Pair** in the dialog.
- **Unpair:** tap the gear (`content-desc` `<name>, Device settings`), then **Unpair**, then **Unpair** again in the confirmation dialog.
- **There is no shell command to remove one bond without root.** `cmd bluetooth_manager factoryReset` exists and wipes every bond on the phone; never use it.
- When the peer device has lost its link key (reflashed, reset), the phone's old bond fails with an authentication or connection error. Unpair and pair again.
- Two devices can show the same name (one address, old and new firmware). Unpair by checking the address in `dumpsys bluetooth_manager`.

## Reading state

- `adb shell dumpsys bluetooth_manager` lists each known device with `ACL BR/EDR:Y|N` and its encryption status: the quickest check that a link is up. It also keeps devices that are no longer bonded, so use logcat to confirm a bond change: `removeBond`, `BOND_BONDED => BOND_NONE`.
- Link drops show in logcat as `btif_dm_acl_evt ... ACL link down ... reason:HCI_ERR_<reason>`; the reason is the HCI error code the controller gave.
- `adb logcat -c` before a test, then `adb logcat -v time > file` in the background, so the capture holds only the test. Apps log their own milestones under their tags (Android Auto logs connection steps under `GH.ConnLoggerV2`).
