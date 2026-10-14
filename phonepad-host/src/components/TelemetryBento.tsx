import React from "react";
import { Activity, Gauge, Cpu, Radio } from "lucide-react";

interface TelemetryBentoProps {
  packetsPerSec: number;
  totalPackets: number;
  isConnected: boolean;
  clientName: string;
  clientTransport: string;
}

export const TelemetryBento: React.FC<TelemetryBentoProps> = ({
  packetsPerSec,
  totalPackets,
  isConnected,
  clientName,
  clientTransport,
}) => {
  // Activity bar calculation: up to 144Hz
  const ppsPercent = Math.min(100, (packetsPerSec / 144) * 100);

  return (
    <div className="bento-grid">
      <div className="bento-tile">
        <div className="tile-label">
          <Activity size={13} color="#10b981" />
          <span>Packet Rate</span>
        </div>
        <div className="tile-value">{packetsPerSec} Hz</div>
        <div className="tile-sub" style={{ marginTop: "4px" }}>
          <div
            style={{
              width: "100%",
              height: "4px",
              background: "rgba(255,255,255,0.08)",
              borderRadius: "2px",
              overflow: "hidden",
            }}
          >
            <div
              style={{
                width: `${ppsPercent}%`,
                height: "100%",
                background: "#10b981",
                transition: "width 0.15s ease",
              }}
            />
          </div>
        </div>
      </div>

      <div className="bento-tile">
        <div className="tile-label">
          <Cpu size={13} color="#06b6d4" />
          <span>Total Packets</span>
        </div>
        <div className="tile-value">{totalPackets.toLocaleString()}</div>
        <div className="tile-sub">Sub-pixel Accumulator</div>
      </div>

      <div className="bento-tile">
        <div className="tile-label">
          <Gauge size={13} color="#10b981" />
          <span>Engine Latency</span>
        </div>
        <div className="tile-value">&lt; 1.8 ms</div>
        <div className="tile-sub">Zero-Copy Fastpath</div>
      </div>

      <div className="bento-tile">
        <div className="tile-label">
          <Radio size={13} color={isConnected ? "#10b981" : "#64748b"} />
          <span>Connected Link</span>
        </div>
        <div
          className="tile-value"
          style={{
            fontSize: "13px",
            whiteSpace: "nowrap",
            overflow: "hidden",
            textOverflow: "ellipsis",
            color: isConnected ? "#10b981" : "#94a3b8",
          }}
          title={clientName}
        >
          {isConnected ? clientName : "Waiting..."}
        </div>
        <div className="tile-sub">{isConnected ? clientTransport : "Idle"}</div>
      </div>
    </div>
  );
};
