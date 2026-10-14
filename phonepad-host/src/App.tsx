import React, { useState, useEffect, useCallback } from "react";
import "./styles/tokens.css";
import "./styles/app.css";
import { HostStatus, UpdateSettingsPayload } from "./types";
import { tauriBridge } from "./services/tauriBridge";
import { Header } from "./components/Header";
import { MasterSwitch } from "./components/MasterSwitch";
import { PairingCard } from "./components/PairingCard";
import { TelemetryBento } from "./components/TelemetryBento";
import { SettingsDrawer } from "./components/SettingsDrawer";

export const App: React.FC = () => {
  const [status, setStatus] = useState<HostStatus>({
    isRunning: true,
    isServiceEnabled: true,
    isConnected: false,
    localIp: "127.0.0.1",
    port: 4242,
    computerName: "Host-PC",
    authPin: 4242,
    clientName: "Waiting for phone...",
    clientTransport: "Wi-Fi",
    packetsPerSec: 0,
    totalPackets: 0,
    sensitivity: 1.25,
    naturalScroll: true,
    gesturesEnabled: true,
    tapToClick: true,
    qrPayload: "",
  });

  // Initial fetch
  useEffect(() => {
    tauriBridge.getHostStatus().then((initial) => {
      setStatus(initial);
    });

    // Real-time telemetry subscription
    const unsubscribe = tauriBridge.onTelemetry((event) => {
      setStatus((prev) => ({
        ...prev,
        isConnected: event.isConnected,
        isServiceEnabled: event.isServiceEnabled,
        packetsPerSec: event.packetsPerSec,
        totalPackets: event.totalPackets,
        clientName: event.clientName,
        clientTransport: event.clientTransport,
      }));
    });

    return () => {
      unsubscribe();
    };
  }, []);

  const handleToggleService = useCallback(async () => {
    // Optimistic update
    setStatus((prev) => ({
      ...prev,
      isServiceEnabled: !prev.isServiceEnabled,
    }));
    const newServiceState = await tauriBridge.toggleService();
    setStatus((prev) => ({
      ...prev,
      isServiceEnabled: newServiceState,
    }));
  }, []);

  const handleUpdateSettings = useCallback(
    async (payload: UpdateSettingsPayload) => {
      setStatus((prev) => ({
        ...prev,
        ...payload,
      }));
      await tauriBridge.updateSettings(payload);
    },
    []
  );

  return (
    <div className="window-frame">
      <div
        className={`ambient-glow ${
          status.isServiceEnabled ? "active" : "paused"
        }`}
      />
      <Header />

      <main className="content-scroll">
        <MasterSwitch
          isServiceEnabled={status.isServiceEnabled}
          onToggle={handleToggleService}
        />

        <PairingCard
          localIp={status.localIp}
          port={status.port}
          computerName={status.computerName}
          authPin={status.authPin}
          qrPayload={status.qrPayload}
        />

        <TelemetryBento
          packetsPerSec={status.packetsPerSec}
          totalPackets={status.totalPackets}
          isConnected={status.isConnected}
          clientName={status.clientName}
          clientTransport={status.clientTransport}
        />

        <SettingsDrawer
          sensitivity={status.sensitivity}
          naturalScroll={status.naturalScroll}
          gesturesEnabled={status.gesturesEnabled}
          tapToClick={status.tapToClick}
          onUpdate={handleUpdateSettings}
        />
      </main>

      <footer className="app-footer">
        <div className="client-status-pill">
          <div
            className={`status-dot ${
              status.isConnected ? "connected" : "disconnected"
            }`}
          />
          <span>
            {status.isConnected
              ? `Connected: ${status.clientName}`
              : "Waiting for PhonePad connection..."}
          </span>
        </div>
        <span>120Hz Fastpath</span>
      </footer>
    </div>
  );
};

export default App;
