---
name: zomp-esp32-bench
description: ESP32 work on a bench machine - Xtensa Rust toolchains side by side, building ESP-IDF projects in its container image, flashing when auto-reset is unreliable, capturing UART logs, why logging can break radio links, and Bluetooth Classic on the original ESP32 through esp-radio. Load this before flashing, building or debugging ESP32 firmware, installing an Xtensa toolchain, or running an ESP-IDF example.
---

# ESP32 bench work

These extend `AGENTS.md`, which stays in force.

## Toolchains

- **Install a newer Xtensa toolchain under its own name:** `espup install --name esp-<version> --toolchain-version <version>.0 --targets esp32`. Plain `espup install` replaces `esp`, which other firmware on the machine may be pinned to. Build with `cargo +esp-<version>`; esp-hal's xtask takes `--toolchain esp-<version>`.
- esp-hal's `main` branch often needs a newer Rust than the latest release. "rustc X is not supported by the following packages" means the toolchain, not the code.

## ESP-IDF without installing it

Use Espressif's image, `espressif/idf:<tag>` (podman or docker). Copy the example out of `$IDF_PATH/examples`, append any config to `sdkconfig.defaults`, then `idf.py set-target <chip>`, `idf.py build`, `idf.py merge-bin`, and flash `build/merged-binary.bin` at `0x0` with esptool from the host. The image is also the quickest way to read ESP-IDF's sources for a tag. Its activation banner goes to stdout, so filter it before trusting the line numbers in captured output.

## Flashing

- **Know the board's USB bridge:** Silicon Labs `10C4:EA60` (CP210x), WCH `1A86`, FTDI `0403`, Espressif USB-Serial/JTAG `303A`. A board that drops out of Device Manager or `lsusb` while powered has a loose cable or connector, which also shows up as random connect failures.
- **Auto-reset into the bootloader is unreliable on many dev boards.** "Wrong boot mode detected (0x13)" or "Failed to connect" means the reset sequence lost the race, not that the chip is dead. Retry in a loop, and drop to `--baud 115200`. If it still fails, ask the user to hold BOOT, tap EN, then release BOOT.
- Run esptool from a virtualenv in scratch space rather than the system Python.

## Serial logs

- **Output nobody is reading is lost.** Before resetting the board for a test, start a background logger that appends the port to a file, and read the file.
- Only one process can hold the port. Stop the logger before flashing, and wait a second, or the flash fails to connect.
- Toggling RTS resets most boards. A logger that opens the port with RTS asserted resets the chip.

## Logging breaks radio timing

esp-println and esp-log write each line to the UART inside a critical section, with interrupts disabled for the whole line: about 10 ms for a 120-character line at 115200 baud. Bluetooth Classic links on the original ESP32 time out (HCI reason `0x08`) when lines are logged while the link comes up. BLE tolerates it better. On firmware with an active radio, keep the level at `warn` (`ESP_LOG` in `.cargo/config.toml`) and log only after the timing-critical part, or use a buffered logger.

## Bluetooth Classic on the original ESP32

- Only the original ESP32 has BR/EDR. The S2, S3 and C-series do not.
- esp-radio's `BleConnector` on the ESP32 carries BR/EDR as it is: the BLE-only controller configuration is not enforced, and inquiry, paging, SSP pairing, encryption and RFCOMM all work. No patch is needed. What breaks links is interrupt latency (above).
- Use esp-hal from git `main`. esp-radio 1.0.0-beta.1 fails to link the BR/EDR ROM callbacks (`ld_iscan_evt_start_cbk` and similar).
- To test a host stack against the real controller from a PC, ESP-IDF's `controller_hci_uart` example puts the controller on UART1 (TX 5, RX 18, RTS 19, CTS 23, 921600 baud, RTS/CTS) behind a 3.3 V USB-UART adapter. That controller rejects Host_Buffer_Size.
