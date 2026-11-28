---
name: zomp-rust
description: Zomp conventions for Rust - comments for a .NET reader, pinning the toolchain in rust-toolchain.toml, lints in Cargo.toml (clippy pedantic, warnings as errors), the version from git through nerdbank-gitversioning in build.rs with worktree-safe rerun paths, library conventions (MIT OR Apache-2.0, semver in Cargo.toml, log and defmt features), dependencies and tests. Load this before creating a Rust crate or workspace, and before toolchain, lint, versioning, dependency, licensing or CI decisions in a Rust repository.
---

# Zomp Rust conventions

These extend the global conventions in `AGENTS.md`, which stay in force. ESP32 toolchains, flashing and logging are in `zomp-esp32-bench`.

## Comments

The owner reads C# fluently and Rust less so. Where a Rust idiom has a .NET analog, name it once, where it first appears: a `build.rs` is an MSBuild target that runs before the build, a trait object is an interface reference, `?` is an early return of the error. Never explain what the code already says.

## Toolchain and edition

- Every repository has a `rust-toolchain.toml` with an exact `channel` (`"1.100.0"`, not `"stable"`), plus the `components` (`rustfmt`, `clippy`) and `targets` it builds for. CI installs from that file, so local and CI builds use the same compiler.
- For Xtensa ESP32 chips the channel is a versioned Espressif toolchain such as `"esp-1.100.0"`, installed as `zomp-esp32-bench` describes. The floating `esp` channel is whatever was installed last on that machine.
- New crates use edition 2024. A library declares `rust-version`, the oldest Rust it builds with; check it with `cargo +<version> check` before lowering it.

## Lints

Lints live in `Cargo.toml`, not as `#![allow]` in the source (in a workspace, under `[workspace.lints]`, with `lints.workspace = true` in each member):

```toml
[lints.rust]
unsafe_code = "forbid"   # "deny" in a driver crate, with a local allow at each unsafe block
missing_docs = "warn"

[lints.clippy]
all = { level = "warn", priority = -1 }
pedantic = { level = "warn", priority = -1 }
```

- Every exception carries a comment saying why: in `Cargo.toml` for a crate-wide one, otherwise `#[expect(lint, reason = "...")]` at the item. `expect` warns once the exception is no longer needed, and `allow` does not.
- Never quiet a build with a crate-wide allow of `dead_code` or `unused_*`. Delete the code, or gate it behind the feature that uses it.
- Every `unsafe` block has a `// SAFETY:` comment saying why it is sound.
- CI and the pre-commit hook run `cargo fmt --check`; CI also runs `cargo clippy --all-targets -- -D warnings` and `cargo test`. For each feature set and target the crate supports, run clippy at least once. A library also runs `cargo doc --no-deps` with `RUSTDOCFLAGS=-D warnings`.

## Versioning

**Binaries and firmware** get their version from git, the same way as on .NET: a `version.json` at the root, read in `build.rs` by the `nerdbank-gitversioning` crate. The crate is in beta, so pin its exact version with `=`. `build.rs` passes the version to the code as `cargo:rustc-env=<NAME>_VERSION`, and `Cargo.toml` keeps `version = "0.0.0"`, which nothing reads. If the oracle fails, fall back to `git describe --tags --always --dirty` and print a `cargo:warning` that says why.

Find the files that should trigger a rerun by asking git, not with `.git/HEAD`. In a worktree, `.git` is a file, so `cargo:rerun-if-changed=.git/HEAD` never fires, and the stamped version goes stale after a commit:

```rust
for path in ["HEAD", "logs/HEAD", "index"] {
    if let Some(p) = git(&["rev-parse", "--git-path", path]) {
        println!("cargo:rerun-if-changed={p}");
    }
}
```

Show the version where it can be read without the source: `--version` for a tool, and a boot log line for firmware, at a level that release builds keep. Add it to any status reply or device attribute the firmware already has.

**Libraries** keep semver in `Cargo.toml`, which `cargo publish` and every dependent read. Bump it in the PR that changes the API, following the global rules on breaking changes.

## Libraries

- License `MIT OR Apache-2.0`, with `LICENSE-MIT` and `LICENSE-APACHE` at the root, as the Rust ecosystem does. Client code follows the client's terms.
- A `no_std` library logs through optional `log` and `defmt` features and forces neither. It allocates only behind an `alloc` feature.
- Set `publish = false` until the crate is meant for crates.io.

## Dependencies

- Write requirements to the minor version (`"0.29"`, `"1.2"`), not `"0"` or `"*"`. Commit `Cargo.lock` in every repository, libraries included.
- In an application, each dependency carries a comment saying what it is for. Everything added is someone else's code on the user's machine.
- Errors: a library returns its own error enum (`thiserror` where it helps, including in `no_std`), and a binary uses `anyhow`, with context that names the file, input or device at fault.

## Tests

- Unit tests sit beside the code in a `#[cfg(test)] mod tests`, the Rust convention rather than the .NET one. Integration tests go under `tests/`.
- Code that talks to hardware gets a host-side path through the same traits (a simulator, a peer over a virtual serial port), so CI can test it without the device.
- What only a person at the device can check goes in `docs/manual-tests.md`.
