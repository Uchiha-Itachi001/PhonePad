import React from "react";
import {
  MousePointer,
  RotateCcw,
  CheckCircle2,
  Lock,
  Layers,
  Sparkles,
  Radio,
  Wifi,
  Power,
} from "lucide-react";
import { HostStatus, UpdateSettingsPayload } from "../types";

interface SettingsTabProps {
  status: HostStatus;
  onUpdateSettings: (payload: UpdateSettingsPayload) => void;
  onToggleService?: () => void;
}

export const SettingsTab: React.FC<SettingsTabProps> = ({
  status,
  onUpdateSettings,
  onToggleService,
}) => {
  const handleSensitivityChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = parseFloat(e.target.value);
    onUpdateSettings({ sensitivity: val });
  };

  const handleToggle = (key: keyof UpdateSettingsPayload, current: boolean) => {
    onUpdateSettings({ [key]: !current });
  };

  const resetDefaults = () => {
    onUpdateSettings({
      sensitivity: 1.25,
      naturalScroll: true,
      gesturesEnabled: true,
      tapToClick: true,
    });
  };

  return (
    <div className="settings-tab-content">
      <div className="settings-two-col-layout">
        {/* Left Column: Connection, Pairing & Engine */}
        <div className="settings-col">
          {/* Card 1: Host Service & Same Wi-Fi Link */}
          <div className="glass-bento-card settings-card-compact">
            <div className="bento-card-header">
              <div className="card-title-group">
                <Radio size={14} className="accent-icon" />
                <h4>Host Service</h4>
              </div>
              {onToggleService && (
                <button
                  className={`power-pill-toggle ${
                    status.isServiceEnabled ? "active" : "paused"
                  }`}
                  onClick={onToggleService}
                  title={
                    status.isServiceEnabled
                      ? "Pause Daemon Input"
                      : "Resume Daemon Input"
                  }
                >
                  <Power size={10} />
                  <span>{status.isServiceEnabled ? "ACTIVE" : "PAUSED"}</span>
                </button>
              )}
            </div>

            {/* Wi-Fi Direct Auto-Discovery Info */}
            <div className="wifi-sync-card">
              <div className="wifi-sync-row">
                <div className="feature-icon-badge">
                  <Wifi size={13} color="#10B981" />
                </div>
                <div className="wifi-sync-meta">
                  <span className="wifi-sync-title">Same Wi-Fi Auto-Discovery</span>
                  <span className="wifi-sync-sub mono">
                    {status.computerName || "Desktop Host"} (Port {status.port || 4242})
                  </span>
                </div>
                <CheckCircle2 size={14} color="#10B981" />
              </div>
              <p className="wifi-sync-desc">
                Both devices must be on the same Wi-Fi. The PhonePad mobile app discovers and connects to this PC automatically.
              </p>
            </div>
          </div>

          {/* Card 2: Engine Status & Fastpath */}
          <div className="glass-bento-card settings-card-compact">
            <div className="bento-card-header">
              <div className="card-title-group">
                <Layers size={14} className="accent-icon" />
                <h4>Fastpath Engine</h4>
              </div>
              <span className="engine-status-chip mono">120Hz Low-Latency</span>
            </div>

            <div className="engine-features-list">
              <div className="engine-feature-row">
                <div className="feature-icon-badge">
                  <Sparkles size={12} color="#06B6D4" />
                </div>
                <div className="feature-text">
                  <span className="feature-name">Sub-Pixel Q3 Digitizer</span>
                  <span className="feature-sub">0.125px fixed-point precision</span>
                </div>
                <CheckCircle2 size={14} color="#10B981" />
              </div>

              <div className="engine-feature-row">
                <div className="feature-icon-badge">
                  <Layers size={12} color="#3B82F6" />
                </div>
                <div className="feature-text">
                  <span className="feature-name">Direct Win32 SendInput</span>
                  <span className="feature-sub">Kernel-level queue bypass</span>
                </div>
                <CheckCircle2 size={14} color="#10B981" />
              </div>

              <div className="engine-feature-row">
                <div className="feature-icon-badge">
                  <Lock size={12} color="#F59E0B" />
                </div>
                <div className="feature-text">
                  <span className="feature-name">Exclusive Session Lock</span>
                  <span className="feature-sub">Blocks unauthorized concurrent links</span>
                </div>
                <CheckCircle2 size={14} color="#10B981" />
              </div>
            </div>
          </div>
        </div>

        {/* Right Column: Pointer & Touchpad Preferences */}
        <div className="settings-col">
          <div className="glass-bento-card settings-card-full">
            <div className="bento-card-header">
              <div className="card-title-group">
                <MousePointer size={14} className="accent-icon" />
                <h4>Touchpad Preferences</h4>
              </div>
              <button
                className="reset-btn"
                onClick={resetDefaults}
                title="Reset to default settings"
              >
                <RotateCcw size={10} />
                <span>Reset</span>
              </button>
            </div>

            <div className="settings-section">
              {/* Sensitivity Slider */}
              <div className="setting-slider-item">
                <div className="slider-header">
                  <span className="setting-title">Cursor Sensitivity</span>
                  <span className="slider-val mono">
                    {status.sensitivity.toFixed(2)}x
                  </span>
                </div>
                <input
                  type="range"
                  min="0.5"
                  max="3.0"
                  step="0.05"
                  value={status.sensitivity}
                  onChange={handleSensitivityChange}
                  className="custom-range"
                />
                <div className="slider-ticks">
                  <span>0.5x Slow</span>
                  <span>1.25x Normal</span>
                  <span>3.0x Fast</span>
                </div>
              </div>

              <div className="setting-divider" />

              {/* Tap to Click */}
              <div className="setting-toggle-row">
                <div className="toggle-info">
                  <span className="setting-title">Tap to Click</span>
                  <span className="setting-desc">
                    Single finger touch tap registers as Left Click
                  </span>
                </div>
                <button
                  className={`switch-pill ${status.tapToClick ? "on" : "off"}`}
                  onClick={() => handleToggle("tapToClick", status.tapToClick)}
                >
                  <div className="switch-knob" />
                </button>
              </div>

              {/* Natural Scrolling */}
              <div className="setting-toggle-row">
                <div className="toggle-info">
                  <span className="setting-title">Natural Scrolling</span>
                  <span className="setting-desc">
                    Content moves in the direction of two-finger swipe
                  </span>
                </div>
                <button
                  className={`switch-pill ${status.naturalScroll ? "on" : "off"}`}
                  onClick={() => handleToggle("naturalScroll", status.naturalScroll)}
                >
                  <div className="switch-knob" />
                </button>
              </div>

              {/* 3-Finger Gestures */}
              <div className="setting-toggle-row">
                <div className="toggle-info">
                  <span className="setting-title">3-Finger Gestures</span>
                  <span className="setting-desc">
                    Swipe for Alt+Tab, Desktop, and Task View
                  </span>
                </div>
                <button
                  className={`switch-pill ${
                    status.gesturesEnabled ? "on" : "off"
                  }`}
                  onClick={() =>
                    handleToggle("gesturesEnabled", status.gesturesEnabled)
                  }
                >
                  <div className="switch-knob" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
