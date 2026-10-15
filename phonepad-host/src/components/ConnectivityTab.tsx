import React, { useState, useEffect } from "react";
import {
  Wifi,
  WifiOff,
  Activity,
} from "lucide-react";
import { HostStatus } from "../types";
import { StrandsCanvas } from "./StrandsCanvas";

interface ConnectivityTabProps {
  status: HostStatus;
  onToggleService?: () => void;
}

export type ConnectionState = "connected" | "connecting" | "disconnected";

export const ConnectivityTab: React.FC<ConnectivityTabProps> = ({
  status,
}) => {
  const [history, setHistory] = useState<number[]>(() => Array(32).fill(0));
  const [peakRate, setPeakRate] = useState<number>(0);

  // Sample actual packetsPerSec live data into waveform buffer
  useEffect(() => {
    const rate = status.packetsPerSec || 0;
    setHistory((prev) => [...prev.slice(1), rate]);
    setPeakRate((prev) => Math.max(prev, rate));
  }, [status.packetsPerSec]);

  // Periodic scrolling tick so waveform scrolls smoothly even when idle or at steady rate
  useEffect(() => {
    const timer = setInterval(() => {
      const rate = status.packetsPerSec || 0;
      setHistory((prev) => [...prev.slice(1), rate]);
    }, 200);
    return () => clearInterval(timer);
  }, [status.packetsPerSec]);

  // Derive connection state
  const isActuallyConnected =
    status.isConnected ||
    (status.isServiceEnabled &&
      (status.packetsPerSec > 0 ||
        (status.clientTransport !== "None" &&
          status.clientTransport !== "" &&
          status.clientTransport !== undefined)));

  const connectionState: ConnectionState = isActuallyConnected
    ? "connected"
    : status.isServiceEnabled
    ? "connecting"
    : "disconnected";

  const getStatusColor = () => {
    switch (connectionState) {
      case "connected":
        return "#10B981"; // Emerald Green
      case "connecting":
        return "#F59E0B"; // Amber Orange
      case "disconnected":
        return "#EF4444"; // Crimson Rose
    }
  };

  const getStatusText = () => {
    switch (connectionState) {
      case "connected":
        return "CONNECTED";
      case "connecting":
        return "READY TO PAIR";
      case "disconnected":
        return "PAUSED";
    }
  };

  const statusColor = getStatusColor();

  // SVG waveform path computation for real live data
  const W = 380;
  const H = 40;
  const maxRate = Math.max(120, ...history, 1);

  const points = history.map((val, idx) => {
    const x = (idx / (history.length - 1)) * W;
    const y = H - 3 - (val / maxRate) * (H - 6);
    return { x, y };
  });

  const linePath = points.reduce((acc, pt, idx) => {
    return idx === 0
      ? `M ${pt.x.toFixed(1)} ${pt.y.toFixed(1)}`
      : `${acc} L ${pt.x.toFixed(1)} ${pt.y.toFixed(1)}`;
  }, "");

  const areaPath = `${linePath} L ${W} ${H} L 0 ${H} Z`;
  const lastPoint = points[points.length - 1];

  return (
    <div className="connectivity-tab-content">
      {/* Top Device Bridge Hero Deck: Phone Illustration <-> Native WebGL2 Strands Canvas <-> Laptop Illustration */}
      <div className={`device-bridge-card state-${connectionState}`}>
        {/* Subtle Ambient Radial Lighting */}
        <div
          className="bridge-ambient-glow"
          style={{
            background: `radial-gradient(ellipse at 50% 50%, ${statusColor}24 0%, transparent 72%)`,
          }}
        />

        {/* Native WebGL2 Strands Canvas Component from strands.html (No dotted lines, No ripples) */}
        <StrandsCanvas
          status={connectionState}
          className="hero-strands-layer"
        />

        {/* Left: Mobile Phone Illustration Node (Not too big) */}
        <div className="bridge-node phone-node">
          <div
            className="node-illustration-capsule"
            style={{
              borderColor: isActuallyConnected
                ? "rgba(59, 130, 246, 0.45)"
                : "rgba(255, 255, 255, 0.12)",
              boxShadow: isActuallyConnected
                ? `0 0 24px rgba(59, 130, 246, 0.3)`
                : "0 8px 20px rgba(0, 0, 0, 0.35)",
            }}
          >
            <div
              className="node-icon-glow"
              style={{
                background: statusColor,
                opacity: isActuallyConnected ? 0.35 : 0.1,
              }}
            />
            {/* Phone Illustration Asset */}
            <img
              src="/assets/phone_cropped.png"
              alt="PhonePad Mobile"
              className="device-illustration-img phone-img"
            />
            <div
              className="node-status-dot"
              style={{
                backgroundColor: isActuallyConnected
                  ? "#10B981"
                  : status.isServiceEnabled
                  ? "#F59E0B"
                  : "#64748B",
                boxShadow: isActuallyConnected
                  ? "0 0 10px #10B981"
                  : status.isServiceEnabled
                  ? "0 0 8px #F59E0B"
                  : "none",
              }}
            />
          </div>

          <div className="node-meta">
            <span className="node-title">
              {isActuallyConnected &&
              status.clientName !== "None" &&
              status.clientName !== "Waiting for connection..."
                ? status.clientName
                : "PhonePad Mobile"}
            </span>
            <span
              className="node-sub-pill mono"
              style={{
                color: isActuallyConnected
                  ? "#10B981"
                  : status.isServiceEnabled
                  ? "#F59E0B"
                  : "#64748B",
              }}
            >
              {isActuallyConnected
                ? status.clientTransport !== "None" && status.clientTransport !== ""
                  ? status.clientTransport
                  : "Wi-Fi (TCP)"
                : "Waiting for Link"}
            </span>
          </div>
        </div>

        {/* Center: Circular Wi-Fi Beacon with Radiant Glow */}
        <div className={`center-beacon-badge state-${connectionState}`}>
          <div className="beacon-container-relative">
            {/* Ambient Animated Halo Glow */}
            <div
              className="beacon-halo-glow"
              style={{
                background: `radial-gradient(circle, ${statusColor}70 0%, transparent 70%)`,
              }}
            />

            {/* Main Circular Beacon Box */}
            <div
              className="beacon-circular-box"
              style={{
                borderColor: `${statusColor}ee`,
                boxShadow: `0 0 24px ${statusColor}66, inset 0 0 14px ${statusColor}44`,
              }}
            >
              {connectionState === "disconnected" ? (
                <WifiOff size={22} color={statusColor} />
              ) : (
                <Wifi
                  size={22}
                  color={statusColor}
                  className="animated-wifi-icon"
                />
              )}
            </div>
          </div>

          <div
            className="beacon-status-pill"
            style={{
              backgroundColor: `${statusColor}18`,
              borderColor: `${statusColor}50`,
              color: statusColor,
            }}
          >
            <span
              className="beacon-dot"
              style={{ backgroundColor: statusColor }}
            />
            <span>{getStatusText()}</span>
          </div>

          <span className="beacon-subtext">
            {isActuallyConnected
              ? "Zero-Delay Fastpath Active (120Hz)"
              : status.isServiceEnabled
              ? "Waiting for PhonePad app..."
              : "Service Paused"}
          </span>
        </div>

        {/* Right: Laptop Illustration Node (Not too big) */}
        <div className="bridge-node laptop-node">
          <div
            className="node-illustration-capsule"
            style={{
              borderColor: "rgba(255, 255, 255, 0.12)",
              boxShadow: "0 8px 20px rgba(0, 0, 0, 0.35)",
            }}
          >
            <div
              className="node-icon-glow"
              style={{
                background: statusColor,
                opacity: 0.15,
              }}
            />
            {/* Laptop Illustration Asset */}
            <img
              src="/assets/laptop_cropped.png"
              alt="Laptop Host"
              className="device-illustration-img laptop-img"
            />
            <div
              className="node-status-dot"
              style={{
                backgroundColor: statusColor,
                boxShadow: `0 0 10px ${statusColor}`,
              }}
            />
          </div>

          <div className="node-meta">
            <span className="node-title">
              {status.computerName || "Host PC"}
            </span>
            <span className="node-sub-pill mono">
              {status.localIp}:{status.port}
            </span>
          </div>
        </div>
      </div>

      {/* Bottom Deck: Separated Fastpath Engine Card & Real-Time Telemetry Graph Card */}
      <div className="telemetry-deck-row">
        {/* Left: Engine & Frequency Card (Strict Fixed Width) */}
        <div className="telemetry-engine-card">
          <div className="dock-hz-badge">
            <span className="dock-hz-val">
              {isActuallyConnected && status.packetsPerSec > 0
                ? status.packetsPerSec
                : 0}
            </span>
            <span className="dock-hz-unit">Hz</span>
          </div>
          <div className="dock-engine-meta">
            <span className="dock-engine-title">Fastpath</span>
            <span className="dock-engine-sub">Digitizer Stream</span>
          </div>
        </div>

        {/* Right: Live Real-Time Throughput Oscilloscope Graph Card */}
        <div className="telemetry-graph-card">
          {/* Header row with labels & real live numbers */}
          <div className="dock-graph-header">
            <div className="graph-title-strip">
              <Activity size={11} color={statusColor} />
              <span className="graph-heading">LIVE THROUGHPUT</span>
            </div>
            <div className="graph-data-pills">
              <span className="graph-pill">
                <span className="pill-dim">CURRENT:</span>{" "}
                <span className="pill-bold mono" style={{ color: statusColor }}>
                  {status.packetsPerSec} pkt/s
                </span>
              </span>
              <span className="graph-pill">
                <span className="pill-dim">PEAK:</span>{" "}
                <span className="pill-bold mono">{peakRate} pkt/s</span>
              </span>
              <span className="graph-pill">
                <span className="pill-dim">INTERVAL:</span>{" "}
                <span className="pill-bold mono">
                  {status.packetsPerSec > 0
                    ? (1000 / status.packetsPerSec).toFixed(1)
                    : "0.0"}{" "}
                  ms
                </span>
              </span>
              <span className="graph-pill">
                <span className="pill-dim">TOTAL:</span>{" "}
                <span className="pill-bold mono">
                  {status.totalPackets.toLocaleString()}
                </span>
              </span>
            </div>
          </div>

          {/* SVG Real-time Sparkline Graph */}
          <div className="dock-svg-canvas">
            <svg
              className="live-sparkline-svg"
              viewBox="0 0 380 40"
              preserveAspectRatio="none"
            >
              <defs>
                <linearGradient
                  id="graphGrad"
                  x1="0"
                  y1="0"
                  x2="0"
                  y2="1"
                >
                  <stop offset="0%" stopColor={statusColor} stopOpacity="0.4" />
                  <stop offset="70%" stopColor={statusColor} stopOpacity="0.08" />
                  <stop offset="100%" stopColor={statusColor} stopOpacity="0.0" />
                </linearGradient>
              </defs>

              {/* Baseline & guide lines */}
              <line
                x1="0"
                y1="20"
                x2="380"
                y2="20"
                stroke="rgba(255, 255, 255, 0.05)"
                strokeDasharray="2 3"
              />

              {/* Filled area under curve */}
              <path d={areaPath} fill="url(#graphGrad)" />

              {/* Waveform stroke line */}
              <path
                d={linePath}
                fill="none"
                stroke={statusColor}
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              />

              {/* Live leading point marker */}
              {isActuallyConnected && (
                <circle
                  cx={lastPoint.x}
                  cy={lastPoint.y}
                  r="3.5"
                  fill="#ffffff"
                  stroke={statusColor}
                  strokeWidth="1.5"
                />
              )}
            </svg>
          </div>
        </div>
      </div>
    </div>
  );
};
