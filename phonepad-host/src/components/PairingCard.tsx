import React, { useState } from "react";
import { QRCodeSVG } from "qrcode.react";
import { QrCode, Copy, Check, Wifi } from "lucide-react";

interface PairingCardProps {
  localIp: string;
  port: number;
  computerName: string;
  authPin: number;
  qrPayload: string;
}

export const PairingCard: React.FC<PairingCardProps> = ({
  localIp,
  port,
  computerName,
  authPin,
  qrPayload,
}) => {
  const [copied, setCopied] = useState(false);

  const copyIp = () => {
    navigator.clipboard.writeText(`${localIp}:${port}`);
    setCopied(true);
    setTimeout(() => setCopied(false), 1800);
  };

  const pinDigits = String(authPin).padStart(4, "0").split("");

  return (
    <div className="pairing-section">
      <div className="pairing-header">
        <span className="section-title">
          <QrCode size={13} /> Instant Wi-Fi Pairing
        </span>
        <button
          className="win-btn"
          style={{ width: "auto", padding: "2px 6px", fontSize: "11px", gap: "4px" }}
          onClick={copyIp}
          title="Copy IP:Port to clipboard"
        >
          {copied ? <Check size={12} color="#3b82f6" /> : <Copy size={12} />}
          <span>{copied ? "Copied" : "Copy IP"}</span>
        </button>
      </div>

      <div className="qr-box-container">
        <div className="qr-canvas-wrapper" title="Scan with PhonePad app or phone camera">
          <QRCodeSVG
            value={qrPayload || `phonepad://connect?ip=${localIp}&port=${port}&name=${computerName}&pin=${authPin}`}
            size={102}
            bgColor="#ffffff"
            fgColor="#070c14"
            level="M"
          />
        </div>

        <div className="pairing-meta">
          <div className="meta-row">
            <span className="meta-label">Local Wi-Fi IP</span>
            <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
              <Wifi size={12} color="#3b82f6" />
              <span className="meta-value">
                {localIp}:{port}
              </span>
            </div>
          </div>

          <div className="meta-row">
            <span className="meta-label">Zero-Trust PIN</span>
            <div className="pin-deck">
              {pinDigits.map((digit, idx) => (
                <div key={idx} className="pin-digit">
                  {digit}
                </div>
              ))}
            </div>
          </div>

          <div className="meta-row">
            <span className="meta-label">Host Device</span>
            <span className="meta-value" style={{ color: "#94a3b8", fontSize: "11px" }}>
              {computerName}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};
