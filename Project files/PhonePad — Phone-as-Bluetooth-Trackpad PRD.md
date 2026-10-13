# PhonePad — Product Requirements Document

**Author:** Pankoj Roy **Status:** Draft v1 **Stack:** Rust (host-side relay/input injection) + a lightweight phone app (Flutter or native) — connected over classic Bluetooth

## 1. Problem Statement

Laptop trackpads are often cramped, and a dedicated external trackpad/mouse is one more thing to carry and charge. Most people have an old phone sitting unused in a drawer — a touchscreen that's already better than most trackpads. Existing "phone as remote" apps (Remote Mouse, Unified Remote) solve this but are built on heavy frameworks (often Electron on the desktop side), so they feel laggy and unreliable for something that needs to feel instant, like a real trackpad.

## 2. Goal

Turn an old phone into a Bluetooth trackpad for a laptop, with input lag low enough that it feels like a real trackpad, not a remote-control app. Built in Rust specifically to avoid the bloat/lag of existing Electron-based competitors.

Success = using it blind (eyes on the laptop screen only), a user can't tell the input lag apart from a built-in trackpad.

## 3. Target Users

- Anyone without a trackpad/mouse on hand who has an old phone lying around
- Laptop users who dislike their built-in trackpad and don't want to buy external hardware
- Students/developers working on the move (matches wanting something light, no extra hardware)

## 4. Core Concept

1. Phone and laptop pair once over classic Bluetooth (not BLE — need a reliable continuous byte stream, not periodic low-power updates).
2. A Rust host app on the laptop opens an RFCOMM (Bluetooth Serial Port Profile) socket and listens for touch-delta packets.
3. The phone app is just a blank touch surface: it captures raw multi-touch events (position changes, finger count, tap timing) and streams them as small binary packets over the RFCOMM socket.
4. The Rust host parses each packet and immediately injects the equivalent OS-level input event (mouse move, click, scroll) using native APIs — no intermediate browser/Electron layer.
5. The host auto-reconnects if the Bluetooth link drops (phone locks, walks out of range, etc.).

## 5. Key Features

### Phase 1 — MVP

- Pair phone ↔ laptop over classic Bluetooth (RFCOMM)
- One-finger drag → cursor move (relative deltas, not absolute position)
- One-finger tap → left click
- Two-finger tap → right click
- Two-finger drag → scroll (vertical + horizontal)
- Configurable sensitivity/acceleration curve on the host side
- Auto-reconnect on dropped connection

### Phase 2 — Quality of life

- Three-finger swipe → app-switch / mission-control style gesture (OS-dependent)
- Tap-and-hold → click-and-drag
- Visual "connected" indicator + battery/signal status on both ends
- System tray app on host (start/stop, pick which paired phone is active)

### Phase 3 — Stretch goals

- Keyboard fallback: phone can also send basic key presses (media keys, arrow keys) for presentations
- Multiple-device support (switch which phone is the active trackpad)
- WiFi fallback transport if Bluetooth is unavailable/unstable (keeps the binary protocol, swaps the transport layer)

## 6. User Flow

1. User installs the host app on the laptop, phone app on the old phone
2. Pairs the two over the OS's normal Bluetooth pairing dialog
3. Opens the host app → it starts listening on an RFCOMM channel
4. Opens the phone app → it connects to the paired laptop automatically
5. Phone screen shows a blank touch surface → user drags/taps as on a normal trackpad → cursor on laptop responds in real time
6. If the phone locks or walks out of range, the host shows "disconnected" and auto-retries when the phone reappears

## 7. System Architecture

### 7.1 Components

- **Phone app:** No real input-processing logic needed — just captures raw multi-touch events (via the OS's native touch APIs) and ships them out as fast as possible. Deliberately kept dumb/thin so all the "smart" work (gesture recognition, acceleration curves) lives in one place: the Rust host.
- **Host app (Rust):** The core of the project. Owns the Bluetooth socket, the binary protocol parser, gesture interpretation, and OS input injection. Runs as a lightweight background/tray process.
- **Transport:** Classic Bluetooth RFCOMM (Serial Port Profile) — chosen over true Bluetooth HID because registering as an HID peripheral from a normal phone app isn't reliably possible across iOS/Android without special permissions; RFCOMM only needs standard pairing, then behaves like a raw serial byte stream.

### 7.2 Protocol Design

A tiny fixed binary format, not JSON — Bluetooth already has \~20–40ms inherent latency, so no serialization overhead should be added on top:

- 1 byte: packet type (Move, Tap, TwoFingerTap, Scroll, DragStart, DragEnd, Heartbeat)
- 2 × i16: dx, dy (relative deltas, not absolute coordinates — relative motion is what makes it feel like a real trackpad instead of a remote cursor)
- 1 byte: finger count / modifier flags
- Total: \~6 bytes per packet, sent at up to 120Hz during active motion, nothing sent while idle

### 7.3 Input Injection (host, per OS)

- **Windows:** SendInput via the windows-rs crate
- **Linux:** uinput via the uinput crate (or a thin virtual input device)
- **macOS:** CGEventPost via the core-graphics crate (rougher Rust support — treated as Phase 2 target, not MVP)
- Cross-platform abstraction option: the enigo crate wraps all three, trading a little control for much less platform-specific code — good for MVP, can be swapped for direct bindings later if enigo's latency isn't tight enough

### 7.4 Gesture Handling

All gesture interpretation (what counts as a tap vs. a drag, double-tap timing, two-finger vs. one-finger) happens **host-side**, not on the phone. The phone only reports raw finger positions and timing; this keeps the phone app trivial and lets gesture tuning happen without updating the phone app.

### 7.5 Reliability

- tokio async runtime on the host so reading the Bluetooth socket never blocks input injection (a stalled read should never freeze the cursor)
- Heartbeat packets so the host can detect a silently-dead connection (vs. the phone just being idle) and start reconnect attempts
- Reconnect loop with backoff; resume automatically once the phone's Bluetooth radio is back in range

## 8. Tech Stack Detail

| Layer | Choice | Why |
| --- | --- | --- |
| Host app | Rust | No GC pauses, tiny memory footprint, predictable low latency — the whole point vs. Electron-based competitors |
| Bluetooth (host) | bluer (Linux/BlueZ) or platform Bluetooth APIs | RFCOMM socket access from Rust |
| Async runtime | tokio | Non-blocking socket I/O alongside input injection |
| Input injection | enigo (MVP), direct windows-rs/uinput/core-graphics bindings later if needed | Cross-platform first, optimize per-OS later |
| Phone app | Flutter (matches your existing mobile stack) or native Android/iOS | Just needs reliable raw multi-touch capture plus a classic Bluetooth socket API |
| Phone-host link | Classic Bluetooth RFCOMM (SPP) | Reliable continuous stream; avoids needing true HID peripheral mode |

## 9. Non-Functional Requirements

- **Latency target:** under \~30ms end-to-end (touch event → cursor movement on screen), so it reads as instant
- **Reliability:** auto-reconnect within \~2s of the phone coming back in range, no manual re-pairing needed per session
- **Resource use:** host process should be light enough to run idle in the background without noticeable battery/CPU impact
- **Platform support (MVP):** Windows + Linux hosts first (best Rust input-injection crate support); macOS as a follow-up
- **Phone OS support:** Android first (classic Bluetooth RFCOMM is straightforward); iOS's restrictions on classic Bluetooth (MFi program requirements) make it a harder follow-up, not MVP

## 10. Edge Cases & Risks

- **iOS classic Bluetooth restrictions:** Apple requires MFi certification for most classic Bluetooth accessory communication from third-party apps — likely blocks an easy iOS phone app; Android-first is the realistic MVP path
- **Bluetooth range/interference:** typical classic BT range (\~10m) and household WiFi interference can cause drops — reconnect logic must be fast and silent, not require the user to re-pair
- **Multiple paired devices:** if more than one phone is paired, host needs a clear way to pick which one is "active" (Phase 2 feature, but worth flagging now so the protocol supports a device ID from day one)
- **Touch surface size mismatch:** a small old phone screen means less physical room for large cursor movements — sensitivity/acceleration curve needs to be tuned, not just 1:1 mapped
- **Battery drain on the phone:** keeping the screen on plus Bluetooth active continuously will drain an old phone's (likely degraded) battery faster than expected — worth a low-battery warning

## 11. Success Metrics

- Measured end-to-end input latency (ms) — target <30ms
- Reconnect time after a dropped link — target <2s
- Subjective "feels like a real trackpad" test with a few users doing normal tasks (browsing, scrolling, clicking) blind

## 12. Out of Scope (v1)

- True Bluetooth HID peripheral mode (phone registering as an actual mouse at the protocol level)
- iOS phone app (Android-only for MVP, due to MFi restrictions)
- WiFi transport fallback (Phase 3 stretch at earliest)
- Keyboard/media-key support (Phase 3 stretch)
- Pressure-sensitive or stylus input

## 13. Assumptions Made

- Classic Bluetooth RFCOMM (SPP) is used instead of BLE, since a trackpad needs a continuous reliable byte stream rather than periodic low-power updates
- All gesture logic lives host-side (in Rust) so the phone app can stay minimal and dumb, which also keeps gesture tuning centralized in one codebase
- MVP targets Android phones and Windows/Linux laptops, since both have the most straightforward Rust/OS support for this project's needs
