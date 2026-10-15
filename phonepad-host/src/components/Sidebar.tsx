import React from "react";
import { Radio, Sliders, Info, Power } from "lucide-react";
import { HostStatus } from "../types";
import { tauriBridge } from "../services/tauriBridge";

export type TabType = "connectivity" | "settings" | "about";

interface SidebarProps {
  activeTab: TabType;
  onTabChange: (tab: TabType) => void;
  status: HostStatus;
  onToggleService: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  activeTab,
  onTabChange,
  status,
  onToggleService,
}) => {
  const isActuallyConnected =
    status.isConnected ||
    (status.isServiceEnabled &&
      (status.packetsPerSec > 0 ||
        (status.clientTransport !== "None" &&
          status.clientTransport !== "" &&
          status.clientTransport !== undefined)));

  const statusColor = isActuallyConnected
    ? "#10B981"
    : status.isServiceEnabled
    ? "#F59E0B"
    : "#EF4444";

  const handleDragMouseDown = (e: React.MouseEvent) => {
    if (e.button === 0 && e.detail === 1 && !(e.target as HTMLElement).closest("button, a")) {
      tauriBridge.startDragging();
    }
  };

  const handleDoubleClick = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
  };

  return (
    <aside
      className="app-sidebar"
      onMouseDown={handleDragMouseDown}
      onDoubleClick={handleDoubleClick}
    >
      {/* Top: Brand Squircle Emblem */}
      <div
        className="sidebar-brand-mini"
        title="PhonePad Desktop Host v0.2"
      >
        <div className="brand-icon-box">
          <img
            src="/icon.png"
            alt="PhonePad"
            style={{
              width: "100%",
              height: "100%",
              objectFit: "cover",
              borderRadius: "6px",
            }}
          />
        </div>
      </div>

      {/* Middle: Vertical Navigation Rail */}
      <div className="sidebar-nav-col">
        <button
          className={`sidebar-icon-btn ${
            activeTab === "connectivity" ? "active" : ""
          }`}
          onClick={() => onTabChange("connectivity")}
          title="Device Connectivity & Pairing"
        >
          <Radio size={18} />
          <span
            className="sidebar-icon-status-dot"
            style={{
              backgroundColor: statusColor,
              boxShadow: `0 0 8px ${statusColor}`,
            }}
          />
        </button>

        <button
          className={`sidebar-icon-btn ${
            activeTab === "settings" ? "active" : ""
          }`}
          onClick={() => onTabChange("settings")}
          title="Pointer & Touchpad Settings"
        >
          <Sliders size={18} />
        </button>

        <button
          className={`sidebar-icon-btn ${
            activeTab === "about" ? "active" : ""
          }`}
          onClick={() => onTabChange("about")}
          title="About PhonePad"
        >
          <Info size={18} />
        </button>
      </div>

      {/* Bottom: Fastpath Daemon Service Power Toggle */}
      <div className="sidebar-bottom-col">
        <button
          className={`sidebar-power-btn ${
            status.isServiceEnabled ? "active" : "paused"
          }`}
          onClick={onToggleService}
          title={
            status.isServiceEnabled
              ? "Daemon Running (120Hz) — Click to pause"
              : "Daemon Paused — Click to resume"
          }
        >
          <Power size={15} />
        </button>
      </div>
    </aside>
  );
};
