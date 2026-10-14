import React from "react";
import { Minus, X, Smartphone } from "lucide-react";
import { tauriBridge } from "../services/tauriBridge";

export const Header: React.FC = () => {
  return (
    <header className="app-header" data-tauri-drag-region>
      <div className="drag-handle" data-tauri-drag-region>
        <div className="brand-badge" data-tauri-drag-region>
          <div className="brand-icon-box">
            <Smartphone size={14} />
          </div>
          <span className="brand-title" data-tauri-drag-region>
            PhonePad Host
          </span>
          <span className="brand-version" data-tauri-drag-region>
            v0.2.0
          </span>
        </div>
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
    </header>
  );
};
