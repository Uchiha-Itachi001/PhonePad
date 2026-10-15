import React from "react";
import {
  Zap,
  Cpu,
  Wifi,
  CheckCircle,
} from "lucide-react";

export const AboutTab: React.FC = () => {
  return (
    <div className="about-tab-content">
      <div className="about-hero-card">
        <div className="about-brand-row">
          <div className="about-brand-logo">
            <img
              src="/icon.png"
              alt="PhonePad Logo"
              style={{
                width: "100%",
                height: "100%",
                objectFit: "cover",
                borderRadius: "14px",
              }}
            />
          </div>
          <div className="about-brand-meta">
            <div className="meta-title-line">
              <h2>PhonePad Desktop Host</h2>
              <span className="version-pill">v0.2.0 Release</span>
            </div>
            <p className="about-tagline">
              Zero-latency phone-as-trackpad companion daemon with native Win32
              kernel injection and sub-pixel ballistics.
            </p>
          </div>
        </div>

        <div className="architecture-badges">
          <div className="arch-badge">
            <Cpu size={12} color="#06B6D4" />
            <span>Rust 1.98.0</span>
          </div>
          <div className="arch-badge">
            <Zap size={12} color="#3B82F6" />
            <span>Tokio Async</span>
          </div>
          <div className="arch-badge">
            <Wifi size={12} color="#F59E0B" />
            <span>TCP Fastpath &lt;1ms</span>
          </div>
          <div className="arch-badge">
            <Wifi size={12} color="#8B5CF6" />
            <span>Wi-Fi Auto-Link</span>
          </div>
        </div>
      </div>

      <div className="about-specs-grid">
        <div className="spec-card">
          <h4>Key Technologies</h4>
          <ul className="spec-list">
            <li>
              <CheckCircle size={12} color="#3B82F6" />
              <span>Direct Win32 SendInput bypasses user-mode latency</span>
            </li>
            <li>
              <CheckCircle size={12} color="#3B82F6" />
              <span>Q3 fixed-point sub-pixel touch digitizer (0.125px)</span>
            </li>
            <li>
              <CheckCircle size={12} color="#3B82F6" />
              <span>Zero-allocation binary protocol with TCP_NODELAY</span>
            </li>
            <li>
              <CheckCircle size={12} color="#3B82F6" />
              <span>Automatic LAN UDP Beacon discovery broadcast</span>
            </li>
          </ul>
        </div>

        <div className="spec-card">
          <h4>System Runtime</h4>
          <div className="system-spec-table">
            <div className="spec-row">
              <span className="spec-k">Target OS:</span>
              <span className="spec-v mono">Windows 10 / 11 (x64)</span>
            </div>
            <div className="spec-row">
              <span className="spec-k">Listening Port:</span>
              <span className="spec-v mono">4242 (TCP) / 4242 (UDP)</span>
            </div>
            <div className="spec-row">
              <span className="spec-k">Internal API:</span>
              <span className="spec-v mono">127.0.0.1:4243 (Loopback)</span>
            </div>
            <div className="spec-row">
              <span className="spec-k">Fastpath Rate:</span>
              <span className="spec-v mono">Up to 250Hz Streaming</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
