import React from "react";
import { Radio, PauseCircle } from "lucide-react";

interface MasterSwitchProps {
  isServiceEnabled: boolean;
  onToggle: () => void;
}

export const MasterSwitch: React.FC<MasterSwitchProps> = ({
  isServiceEnabled,
  onToggle,
}) => {
  return (
    <div
      className={`master-card ${isServiceEnabled ? "active" : "paused"}`}
      onClick={onToggle}
      role="button"
      tabIndex={0}
      title="Toggle Trackpad Active / Paused"
    >
      <div className="master-info">
        <div
          className={`status-beacon ${
            isServiceEnabled ? "active" : "paused"
          }`}
        >
          {isServiceEnabled ? (
            <>
              <Radio size={18} />
              <div className="pulse-ring" />
            </>
          ) : (
            <PauseCircle size={18} />
          )}
        </div>
        <div className="master-text">
          <h3>
            {isServiceEnabled ? "PHONEPAD ACTIVE" : "PHONEPAD PAUSED"}
          </h3>
          <p>
            {isServiceEnabled
              ? "Accepting touch input from mobile"
              : "Touch input blocked on Windows"}
          </p>
        </div>
      </div>

      <div
        className={`toggle-switch ${isServiceEnabled ? "on" : "off"}`}
        aria-checked={isServiceEnabled}
        role="switch"
      >
        <div className="toggle-knob" />
      </div>
    </div>
  );
};
