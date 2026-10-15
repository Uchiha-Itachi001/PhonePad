import React, { useState, useEffect, useCallback } from "react";
import "./styles/tokens.css";
import "./styles/app.css";
import { HostStatus, UpdateSettingsPayload } from "./types";
import { tauriBridge } from "./services/tauriBridge";
import { Sidebar, TabType } from "./components/Sidebar";
import { Header } from "./components/Header";
import { ConnectivityTab } from "./components/ConnectivityTab";
import { SettingsTab } from "./components/SettingsTab";
import { AboutTab } from "./components/AboutTab";

export const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<TabType>("connectivity");
  const [status, setStatus] = useState<HostStatus>({
    isRunning: true,
    isServiceEnabled: true,
    isConnected: false,
    localIp: "127.0.0.1",
    port: 4242,
    computerName: "Host-PC",
    authPin: 4242,
    clientName: "Waiting for phone...",
    clientTransport: "None",
    packetsPerSec: 0,
    totalPackets: 0,
    sensitivity: 1.25,
    naturalScroll: true,
    gesturesEnabled: true,
    tapToClick: true,
    qrPayload: "",
  });

  // Initial fetch and 1-second auto-sync interval
  useEffect(() => {
    tauriBridge.getHostStatus().then((initial) => {
      setStatus(initial);
    });

    const interval = setInterval(() => {
      tauriBridge.getHostStatus().then((curr) => {
        setStatus((prev) => ({
          ...prev,
          ...curr,
        }));
      });
    }, 1000);

    // Real-time telemetry event subscription
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
      clearInterval(interval);
      unsubscribe();
    };
  }, []);

  const handleToggleService = useCallback(async () => {
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

  const isActuallyConnected =
    status.isConnected ||
    (status.isServiceEnabled &&
      (status.packetsPerSec > 0 ||
        (status.clientTransport !== "None" &&
          status.clientTransport !== "" &&
          status.clientTransport !== undefined)));

  return (
    <div className="window-frame horizontal-sidebar-layout">
      {/* Background ambient lighting */}
      <div
        className={`ambient-glow ${
          isActuallyConnected
            ? "connected"
            : status.isServiceEnabled
            ? "active"
            : "paused"
        }`}
      />

      {/* Left Sidebar Navigation */}
      <Sidebar
        activeTab={activeTab}
        onTabChange={setActiveTab}
        status={status}
        onToggleService={handleToggleService}
      />

      {/* Right Main Content Pane */}
      <div className="main-content-pane">
        {/* Top Titlebar */}
        <Header activeTab={activeTab} status={status} />

        {/* Tab Viewport */}
        <main className="content-container">
          {activeTab === "connectivity" && (
            <ConnectivityTab
              status={status}
              onToggleService={handleToggleService}
            />
          )}
          {activeTab === "settings" && (
            <SettingsTab
              status={status}
              onUpdateSettings={handleUpdateSettings}
              onToggleService={handleToggleService}
            />
          )}
          {activeTab === "about" && <AboutTab />}
        </main>
      </div>
    </div>
  );
};

export default App;
