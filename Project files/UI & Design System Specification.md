# PhonePad — UI & Design System Specification

**Author:** Pankoj Roy  
**Design Standard:** Antigravity UI Engine + `developer-bucket` Integration  
**User Preference DNA:** Dynamic Dark Squircle (`#070c14`), Emerald Glow (`#10b981`), Spring Physics  
**Platforms:** Flutter Mobile Client (Touch Surface) & Rust/Web Desktop Companion Dashboard  

---

## 1. Aesthetic Philosophy & Anti-Slop Foundation

PhonePad is an ultra-fast utility, not a generic SaaS website. The UI design rejects cookie-cutter AI templates (no purple gradient mush, no generic rounded cards, no stock icons). 

Instead, it enforces:
- **True Functional Minimalism:** A clean, distraction-free matte dark surface optimized for touch and low latency.
- **Organic Hardware Blending:** Bezel-blended concave ear transitions inspired by Apple hardware and `user-preference-dna.json`.
- **Kinetic Feedback:** Dynamic spring bounce physics (`cubic-bezier(0.34, 1.56, 0.64, 1)`) and edge proximity illumination.

---

## 2. Component Integration Matrix from `developer-bucket`

The PhonePad client and companion app directly adopt and specialize components from the local `developer-bucket`:

| UI Area | Selected Bucket Component | Component File Source | Functional Role in PhonePad |
|---|---|---|---|
| **Top Status & Telemetry** | `dynamic-notch-island` | `components/dynamic-notch-island.html` | Seamless notch pill displaying live Bluetooth link, host PC name, latency meter (14ms), and battery gauge. |
| **Quick Action Launcher** | `squircle-glass-fab` | `components/squircle-glass-fab.html` | Floating squircle glass FAB opening quick settings drawer with emerald radar ping aura. |
| **Edge Proximity Alert** | `border-glow` | `components/border-glow.html` | Ambient proximity border glow that intensifies as fingers approach screen edges so fingers don't slip off blindly. |
| **Sensitivity Tuning** | `elastic-slider` | `components/elastic-slider.html` | Physics-driven elastic slider for fine-tuning cursor acceleration and sensitivity curves. |
| **Surface Mode Selector** | `liquid-gooey-segmented-tabs` | `components/liquid-gooey-segmented-tabs.html` | Fluid morphing tab bar switching between Trackpad, Numpad, and Presentation modes. |
| **Desktop Host Companion** | `MagicBento` | `components/MagicBento.html` | High-contrast bento grid dashboard showing live RFCOMM packet rate, signal RSSI, and input diagnostics. |
| **Touch Ripple Indicator** | `target-cursor` / `splash-cursor` | `components/target-cursor.html` | Ultra-subtle kinetic touch dots appearing under active finger contact points. |

---

## 3. Detailed Component Architecture

### 3.1 Dynamic Notch Island (Top Telemetry Pill)
*Source Reference: `developer-bucket/components/dynamic-notch-island.html`*

The top of the phone screen features an interactive Dynamic Notch Island that sits flush with the physical front camera / bezel:

```
    ┌─────────────────────────[ Phone Bezel ]─────────────────────────┐
    │                                                                 │
    │   ╭─────────────────────────────────────────────────────────╮   │
    │   │  ● RFCOMM SPP   Pankoj's ThinkPad   12ms @ 120Hz   🔋 84%│   │
    │   ╰───────┬─────────────────────────────────────────┬───────╯   │
    │    (Left Ear)                                     (Right Ear)   │
    │                                                                 │
    │                        BLANK TOUCH SURFACE                      │
```

- **Seamless Bezel Ears:** Uses `.notch-ear--left` and `.notch-ear--right` with inverted concave SVG curves to merge into the phone's top frame seamlessly with zero sharp corners.
- **Spring Bounce States:**
  - *Compact Pill (Idle):* Shows green pulsing dot + `14ms` latency.
  - *Expanded Card (On Tap / Disconnect):* Expands with spring physics (`damping: 18, stiffness: 220`) showing Bluetooth RSSI, dropped packet counter, and disconnect button.

### 3.2 Border Glow (Edge Boundary Proximity)
*Source Reference: `developer-bucket/components/border-glow.html`*

Because trackpad users keep their eyes fixed on their laptop screen, fingers frequently drift off the phone glass without knowing.
- The `border-glow` component tracks touch coordinate $(x, y)$ proximity to the screen borders:
  $$\text{proximity} = \max\left(0, 1.0 - \frac{\text{dist\_to\_edge}}{\text{threshold}}\right)$$
- As a finger nears within 25px of any bezel, a soft emerald ambient glow (`rgba(16, 185, 129, 0.4)`) illuminates along that exact edge, providing peripheral vision warning.

### 3.3 Squircle Glass FAB (Quick Control Launcher)
*Source Reference: `developer-bucket/components/squircle-glass-fab.html`*

- Positioned at the bottom-right corner of the mobile screen.
- Styled with Apple continuous squircle curvature, backdrop blur (`backdrop-blur-2xl`), and emerald border stroke (`border-emerald-400/50`).
- Features a radar ping aura (`animate-ping`) when connection is active.
- Tapping opens a bottom glass sheet containing:
  - Cursor Sensitivity (`elastic-slider`).
  - Haptic Intensity Selector (Off / Light / Medium / Strong).
  - Screen Keep-Alive & AMOLED True Black toggle.

### 3.4 Desktop Host Companion Bento Dashboard
*Source Reference: `developer-bucket/components/MagicBento.html`*

When opened from the Windows system tray, the Host Companion displays a sleek dark bento grid:
- **Card 1 (Hero Connection Card):** Paired phone name, Bluetooth RFCOMM channel, link uptime, and signal strength meter.
- **Card 2 (Live Packet Stream):** Real-time graph plotting touch packet frequency (aiming for steady 120Hz).
- **Card 3 (Acceleration Curve Visualizer):** Interactive curve plot showing sub-pixel velocity exponent.
- **Card 4 (Gesture Cheat-Sheet):** Quick visual guide for 1-finger, 2-finger, and 3-finger operations.

---

## 4. Design Tokens & Color Palette

Adhering to the project's Dynamic User DNA:

```css
:root {
  /* Surfaces */
  --bg-primary: #070c14;
  --bg-secondary: #0b111c;
  --bg-surface-glass: rgba(11, 17, 28, 0.85);

  /* Accents */
  --accent-emerald: #10b981;
  --accent-teal: #14b8a6;
  --accent-cyan: #06b6d4;

  /* Glow & Shadows */
  --glow-emerald-soft: rgba(16, 185, 129, 0.25);
  --glow-emerald-active: rgba(16, 185, 129, 0.50);
  --shadow-fab: 0 0 30px rgba(16, 185, 129, 0.40);

  /* Curvature & Easing */
  --squircle-radius: 20px;
  --spring-bounce: cubic-bezier(0.34, 1.56, 0.64, 1);
  --spring-smooth: cubic-bezier(0.16, 1, 0.3, 1);

  /* Typography */
  --font-display: 'Plus Jakarta Sans', sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
}
```

---

## 5. Implementation Roadmap for UI Components

1. **Step 1:** Implement Flutter `PhonePadTouchSurface` with background `#070c14` and integrate `border-glow` edge proximity painter.
2. **Step 2:** Port `dynamic-notch-island` into Flutter as a top sliver widget with live Bluetooth state bindings.
3. **Step 3:** Implement `squircle-glass-fab` as an overlay toggle widget opening the sensitivity modal.
4. **Step 4:** Build the desktop companion dashboard using `MagicBento.html` served via lightweight local HTTP/Tauri window.
