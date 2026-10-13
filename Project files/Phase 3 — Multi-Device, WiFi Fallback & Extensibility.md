# PhonePad — Phase 3: Multi-Device, WiFi Fallback & Extensibility

**Author:** Pankoj Roy  
**Target Milestone:** Ecosystem Maturity & Specialized Input Modes  
**Dependencies:** Phase 1 & 2 Completed  
**Stack:** Rust Host + Flutter Extensible Client  

---

## 1. Overview & Goals

Expand PhonePad beyond a standalone Bluetooth trackpad into an extensible, multi-device input peripheral suite:
1. Support multi-phone pairing with instant host-side switching.
2. Provide a low-latency local Wi-Fi (UDP/TCP) fallback transport when Bluetooth hardware is unavailable or suffers interference.
3. Add modular surface modes: Virtual Numpad & Presentation Remote.
4. Implement an AMOLED battery governor preserving degraded batteries on older phones.

---

## 2. Multi-Device Management

Support households and developer setups where multiple devices exist (e.g. Android phone + secondary Android tablet).

### 2.1 Device Handshake Identification
Upon initial socket connection, client sends an 8-byte Handshake Identification Frame:
- `Byte 0`: `0xAA` (Magic byte)
- `Byte 1`: Protocol Version (`0x02`)
- `Bytes 2..5`: Unique Device Hash (`u32` derived from device Android ID)
- `Bytes 6..7`: Device Form Factor & Name Token (`0x01` = Phone, `0x02` = Tablet)

### 2.2 Host-Side Device Switcher
The host tray and dashboard display all bonded devices. The user can toggle which device is active. The host cleanly signals inactive devices with a `0x10` (`SLEEP_STANDBY`) packet to idle the mobile display and save battery.

---

## 3. Local Wi-Fi Transport Fallback

When Bluetooth radio range is exceeded or RF interference degrades packet delivery, PhonePad gracefully migrates to local Wi-Fi without altering the input processing pipeline.

```
                    ┌──────────────────────────────────┐
                    │       Raw Touch Digitizer        │
                    │      (6-byte binary packet)      │
                    └─────────────────┬────────────────┘
                                      │
                   ┌──────────────────┴──────────────────┐
                   ▼                                     ▼
      ┌─────────────────────────┐           ┌─────────────────────────┐
      │ Classic Bluetooth SPP   │           │ Local Wi-Fi Fallback    │
      │ RFCOMM (Primary Link)   │           │ UDP / TCP Stream        │
      │ Range: ~10m             │           │ Low LAN Latency (<5ms)  │
      └─────────────────────────┘           └─────────────────────────┘
```

### 3.1 Network Discovery & Zero-Configuration
- **Protocol:** mDNS / DNS-SD using service type `_phonepad._tcp.local.` and `_phonepad._udp.local.`.
- **Zero Configuration:** Phone automatically discovers laptop host on local LAN within 500ms of opening app; no IP address entry required.
- **UDP Datagram Stream:** Motion packets sent via UDP with monotonic sequence numbers for ultra-low latency; state packets (clicks, modes) sent with TCP reliability.

---

## 4. Modular Mobile Surface Modes

PhonePad leverages Flutter's dynamic UI to transform the touch surface into specialized input tools.

### 4.1 Mode 1: Precision Trackpad (Default)
Full screen glass surface, edge boundary glow, multi-touch gestures, dynamic notch telemetry.

### 4.2 Mode 2: Virtual Number Pad (Compact Laptops)
For laptops lacking a physical number pad (MacBook, Dell XPS, ThinkPad X-series):
- AMOLED glass grid displaying standard 10-key numeric keypad (`0-9`, `+`, `-`, `*`, `/`, `Enter`, `Backspace`).
- Instant tactile haptic clicks on number presses.
- Directly injects virtual numpad scancodes into host OS (`VK_NUMPAD0`..`VK_NUMPAD9`).

### 4.3 Mode 3: Presentation & Media Remote
For lectures, meetings, and video playback:
- Large Next / Previous slide navigation paddles (`PageUp` / `PageDown`).
- Gyroscopic laser pointer: phone's internal IMU (accelerometer/gyroscope) steers mouse pointer on screen like a Wiimote or Spotlight remote.
- Media controls: Volume slider wheel (`OptionWheel`), Play/Pause, Mute.

---

## 5. AMOLED Power & Battery Governor

Because PhonePad is designed for older phones with aged lithium batteries, keeping the screen on and radio streaming can drain power quickly.

### 5.1 Power Saving Optimizations
1. **True Black (`#000000`) Foundation:** 95%+ of display pixels are powered completely off on OLED/AMOLED panels, saving up to 60% display energy.
2. **Proximity Wake & Auto-Dim:** If no touch occurs for 15 seconds, display drops to 10% minimal luminance with an ambient edge pulse. Touch contact immediately restores full responsiveness in 0ms without input drop.
3. **Low Battery Throttle:** If battery drops below 15%, background polling and telemetry intervals reduce from 1s to 5s.

---

## 6. Implementation Checklist

- [ ] **Handshake Device Protocol:** Support device identification tokens in Rust host.
- [ ] **mDNS Discovery Daemon:** Implement local service broadcast on host and mDNS listener in Flutter.
- [ ] **Dual Transport Layer:** Abstract transport behind a common `InputTransport` trait in Rust (`RfcommTransport` vs `UdpTransport`).
- [ ] **Virtual Numpad Surface:** Design and implement high-contrast haptic number pad widget.
- [ ] **Presentation Remote Mode:** Implement gyro-based cursor steering via phone IMU sensors.
- [ ] **AMOLED Battery Governor:** Implement screen auto-dim and low-power keep-alive state machine.
