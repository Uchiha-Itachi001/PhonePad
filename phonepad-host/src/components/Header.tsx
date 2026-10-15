import React from "react";
import { Minus, X } from "lucide-react";
import { tauriBridge } from "../services/tauriBridge";
import { HostStatus } from "../types";
import { TabType } from "./Sidebar";

interface HeaderProps {
  activeTab: TabType;
  status: HostStatus;
}

export const Header: React.FC<HeaderProps> = ({ activeTab, status }) => {
  const getTabTitle = () => {
    switch (activeTab) {
      case "connectivity":
        return "Device Connectivity & Fastpath Bridge";
      case "settings":
        return "Pointer & Gesture Settings";
      case "about":
        return "About PhonePad Desktop Host";
    }
  };

  const isActuallyConnected =
    status.isConnected ||
    (status.isServiceEnabled &&
      (status.packetsPerSec > 0 ||
        (status.clientTransport !== "None" &&
          status.clientTransport !== "" &&
          status.clientTransport !== undefined)));

  const handleDragMouseDown = (e: React.MouseEvent) => {
    if (e.button === 0 && e.detail === 1 && !(e.target as HTMLElement).closest("button, .win-btn")) {
      tauriBridge.startDragging();
    }
  };

  const handleDoubleClick = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
  };

  return (
    <header
      className="main-titlebar"
      onMouseDown={handleDragMouseDown}
      onDoubleClick={handleDoubleClick}
    >
      <div className="titlebar-left">
        <span className="titlebar-section-title">
          {getTabTitle()}
        </span>
      </div>

      <div className="titlebar-right">
        <div
          className={`titlebar-status-chip ${
            isActuallyConnected
              ? "connected"
              : status.isServiceEnabled
              ? "listening"
              : "paused"
          }`}
        >
          <span className="chip-dot" />
          <span className="chip-text">
            {isActuallyConnected
              ? "Link Active"
              : status.isServiceEnabled
              ? "Listening"
              : "Paused"}
          </span>
        </div>

        <div className="window-controls">
          <button
            className="win-btn"
            title="Minimize to System Tray"
            onClick={() => tauriBridge.minimizeWindow()}
          >
            <Minus size={14} />
          </button>
          <button
            className="win-btn close"
            title="Close / Exit PhonePad"
            onClick={() => tauriBridge.exitApp()}
          >
            <X size={14} />
          </button>
        </div>
      </div>
    </header>
  );
};
