# ⚓ Harbor

A modern, open-source **SSH & SFTP client for iOS** — a cleaner, friendlier take
on apps like Termius, with no account, no paywall and no telemetry. Built in
SwiftUI with a pure-Swift SSH stack.

> **Status: early scaffold (v0.1).** The architecture, UI and CI are in place and
> the project is designed to compile on a macOS runner (see *Building*). It has
> not yet been run on a device — the first macOS build is expected to need a
> shake-out pass, especially around the SSH backend. Contributions welcome.

## Why Harbor

| | Harbor | Typical mobile clients |
|---|---|---|
| Price | Free, MIT, no account | Freemium, sync/SFTP often behind Pro |
| SFTP transfers | **Live progress bar, speed & ETA per file** | Usually a spinner |
| Terminal | SwiftTerm (full xterm-256color), quick-key bar | Varies |
| Reconnection | Keepalive + exponential-backoff auto-reconnect | Varies |
| Background status | Live Activity (Lock Screen + Dynamic Island) | Varies |
| Privacy | Secrets in the Keychain, data stays on device | Cloud sync by default |

## Features

- **Hosts** — grouped, searchable, colour-coded, with recents and swipe actions.
- **Terminal** — SwiftTerm-powered, multiple concurrent sessions, adjustable
  font size, and a quick-key bar (`esc`, `tab`, `ctrl`, arrows, `^C`/`^D`/`^Z`).
- **SFTP browser** — navigate, upload (Files app picker), create folders, delete,
  and **download with a real progress bar, transfer rate and ETA**.
- **SSH keys** — import OpenSSH private keys (optionally passphrase-protected),
  stored only in the device Keychain.
- **Snippets** — save commands and fire them into any session; optional
  run-on-connect snippet per host.
- **Port forwarding** — local, remote and dynamic (SOCKS) rule management.
- **Trust on first use** — host keys are pinned and changes are detected.
- **Live Activity** — an active session shows on the Lock Screen and Dynamic
  Island with status, forward count and running transfers.

## Architecture

```
Harbor/
  App/         App entry, session manager, root tab navigation
  Models/      Host, SSHKey, Snippet, PortForward, KnownHost, ConnectionStatus
  Store/       AppStore (JSON) + Keychain (secrets)
  SSH/         SSHTransport protocol, Citadel backend, SSHSession (lifecycle,
               keepalive, reconnect), SFTP with progress, Live Activity controller
  Terminal/    SwiftTerm ↔ SwiftUI bridge
  Features/    Hosts, Session, SFTP, Keys, Snippets, PortForward, Settings
  Design/      Theme + reusable components
HarborActivity/  Live Activity widget extension
Shared/          Activity attributes shared by app + extension
```

The SSH layer sits behind the `SSHTransport` / `SFTPClient` protocols, so the
backend can be swapped without touching the UI. The default backend is
[**Citadel**](https://github.com/orlandos-nl/Citadel) (pure-Swift over
[SwiftNIO SSH](https://github.com/apple/swift-nio-ssh)); the terminal uses
[**SwiftTerm**](https://github.com/migueldeicaza/SwiftTerm).

### A note on "always-on" background connections

iOS does **not** allow a normal SSH (TCP) session to stay open indefinitely while
the app is closed — no client, Termius included, truly does this. Harbor gets as
close as the platform allows:

- **Keepalive + auto-reconnect** recover from brief drops, Wi-Fi/cellular
  hand-offs and device sleep automatically.
- A **Live Activity** keeps the session visible and extends background runtime.

The proper fix for *roaming, never-drop* sessions is **Mosh** (UDP, survives IP
changes and sleep). Bundling `libmosh` for iOS is involved, so it's on the
roadmap rather than in v1.

## Building

Harbor uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the repo stays
free of a hand-maintained `.xcodeproj`.

```bash
brew install xcodegen
xcodegen generate         # writes Harbor.xcodeproj
open Harbor.xcodeproj     # build & run on an iOS 17+ simulator or device
```

Swift package dependencies (Citadel, SwiftTerm) resolve automatically on first
build.

## Continuous integration

`.github/workflows/ios.yml` builds an **unsigned IPA** on every push and pull
request using a macOS runner. It generates the project, resolves packages,
archives with code signing disabled, wraps `Harbor.app` in a `Payload/` folder
and zips it to `Harbor-unsigned.ipa`, uploaded as a build artifact.

An unsigned IPA will **not** install on a stock device as-is — re-sign it (e.g.
with your own certificate, AltStore or Sideloadly) first. Signed TestFlight
builds would need signing secrets, which this public repo intentionally does not
contain.

## Security & privacy

- Passwords, key passphrases and private keys live in the **iOS Keychain**
  (`kSecAttrAccessibleAfterFirstUnlock`), never in the on-disk JSON or in any
  export.
- No accounts, no analytics, no network calls except the SSH connections you
  make.
- This repository contains **no secrets**. Signing material is git-ignored.

## Roadmap

- [ ] On-device Ed25519/RSA key generation with OpenSSH export
- [ ] Mosh backend for roaming, drop-proof sessions
- [ ] Runtime start/stop of port-forward tunnels with per-tunnel status
- [ ] SFTP file preview (text, images) and in-place editing
- [ ] iCloud Keychain / encrypted export for moving hosts between devices
- [ ] iPad-optimised split layout and hardware-keyboard shortcuts

## License

MIT — see [LICENSE](LICENSE).

## Credits

Built on the shoulders of [Citadel](https://github.com/orlandos-nl/Citadel),
[SwiftNIO SSH](https://github.com/apple/swift-nio-ssh) and
[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm).
