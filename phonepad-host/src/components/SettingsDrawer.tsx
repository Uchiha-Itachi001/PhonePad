import React from "react";
import { Sliders } from "lucide-react";
import { UpdateSettingsPayload } from "../types";

interface SettingsDrawerProps {
  sensitivity: number;
  naturalScroll: boolean;
  gesturesEnabled: boolean;
  tapToClick: boolean;
  onUpdate: (payload: UpdateSettingsPayload) => void;
}

export const SettingsDrawer: React.FC<SettingsDrawerProps> = ({
  sensitivity,
  naturalScroll,
  gesturesEnabled,
  tapToClick,
  onUpdate,
}) => {
  return (
    <div className="settings-section">
      <div className="pairing-header">
        <span className="section-title">
          <Sliders size={13} /> Input Calibration
        </span>
      </div>

      <div className="slider-group">
        <div className="slider-label-row">
          <span className="slider-name">Cursor Sensitivity</span>
          <span className="slider-val">{sensitivity.toFixed(2)}x</span>
        </div>
        <input
          type="range"
          min="0.5"
          max="3.0"
          step="0.05"
          value={sensitivity}
          className="custom-range"
          onChange={(e) =>
            onUpdate({ sensitivity: parseFloat(e.target.value) })
          }
        />
      </div>

      <div className="toggle-row">
        <div className="toggle-row-label">
          <span className="toggle-title">Natural Scrolling</span>
          <span className="toggle-desc">Inverted touch scrolling</span>
        </div>
        <div
          className={`small-toggle ${naturalScroll ? "on" : "off"}`}
          onClick={() => onUpdate({ naturalScroll: !naturalScroll })}
          role="switch"
          aria-checked={naturalScroll}
        >
          <div className="small-knob" />
        </div>
      </div>

      <div className="toggle-row">
        <div className="toggle-row-label">
          <span className="toggle-title">Multi-Finger Gestures</span>
          <span className="toggle-desc">2-finger scroll, 3-finger swipe</span>
        </div>
        <div
          className={`small-toggle ${gesturesEnabled ? "on" : "off"}`}
          onClick={() => onUpdate({ gesturesEnabled: !gesturesEnabled })}
          role="switch"
          aria-checked={gesturesEnabled}
        >
          <div className="small-knob" />
        </div>
      </div>

      <div className="toggle-row">
        <div className="toggle-row-label">
          <span className="toggle-title">Tap to Click</span>
          <span className="toggle-desc">Primary & secondary tap triggers</span>
        </div>
        <div
          className={`small-toggle ${tapToClick ? "on" : "off"}`}
          onClick={() => onUpdate({ tapToClick: !tapToClick })}
          role="switch"
          aria-checked={tapToClick}
        >
          <div className="small-knob" />
        </div>
      </div>
    </div>
  );
};
