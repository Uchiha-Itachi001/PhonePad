import { HostStatus, TelemetryEvent, UpdateSettingsPayload } from "../types";

// Check if running inside Tauri webview
const isTauri = typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;

export const tauriBridge = {
  getHostStatus: async (): Promise<HostStatus> => {
    if (isTauri) {
      try {
        const { invoke } = await import("@tauri-apps/api/core");
        return await invoke<HostStatus>("get_host_status");
      } catch (err) {
        console.warn("Tauri IPC get_host_status error, falling back to HTTP:", err);
      }
    }
    // HTTP Fallback
    try {
      const res = await fetch("http://127.0.0.1:4243/api/status");
      if (res.ok) {
        const data = await res.json();
        const qrPayload = `phonepad://connect?ip=${data.localIp}&port=${data.port}&name=${data.computerName}&pin=${data.authPin}`;
        return { ...data, qrPayload };
      }
    } catch {
      // Offline fallback stub
    }
    return {
      isRunning: true,
      isServiceEnabled: true,
      isConnected: false,
      localIp: "127.0.0.1",
      port: 4242,
      computerName: "Desktop-PC",
      authPin: 4242,
      clientName: "Waiting for phone...",
      clientTransport: "Wi-Fi",
      packetsPerSec: 0,
      totalPackets: 0,
      sensitivity: 1.25,
      naturalScroll: true,
      gesturesEnabled: true,
      tapToClick: true,
      qrPayload: "phonepad://connect?ip=127.0.0.1&port=4242&name=Desktop-PC&pin=4242",
    };
  },

  toggleService: async (): Promise<boolean> => {
    if (isTauri) {
      try {
        const { invoke } = await import("@tauri-apps/api/core");
        return await invoke<boolean>("toggle_service");
      } catch (err) {
        console.warn("Tauri IPC toggle_service error:", err);
      }
    }
    try {
      const res = await fetch("http://127.0.0.1:4243/api/service/toggle", { method: "POST" });
      if (res.ok) {
        const data = await res.json();
        return Boolean(data.isServiceEnabled);
      }
    } catch {
      // ignore
    }
    return true;
  },

  setServiceEnabled: async (enabled: boolean): Promise<boolean> => {
    if (isTauri) {
      try {
        const { invoke } = await import("@tauri-apps/api/core");
        return await invoke<boolean>("set_service_enabled", { enabled });
      } catch (err) {
        console.warn("Tauri IPC set_service_enabled error:", err);
      }
    }
    return enabled;
  },

  updateSettings: async (settings: UpdateSettingsPayload): Promise<boolean> => {
    if (isTauri) {
      try {
        const { invoke } = await import("@tauri-apps/api/core");
        return await invoke<boolean>("update_settings", { settings });
      } catch (err) {
        console.warn("Tauri IPC update_settings error:", err);
      }
    }
    try {
      await fetch("http://127.0.0.1:4243/api/settings", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(settings),
      });
      return true;
    } catch {
      return false;
    }
  },

  minimizeWindow: async (): Promise<void> => {
    if (isTauri) {
      try {
        const { invoke } = await import("@tauri-apps/api/core");
        await invoke("minimize_window");
      } catch (e) {
        console.error(e);
      }
    }
  },

  hideWindow: async (): Promise<void> => {
    if (isTauri) {
      try {
        const { invoke } = await import("@tauri-apps/api/core");
        await invoke("hide_window");
      } catch (e) {
        console.error(e);
      }
    }
  },

  exitApp: async (): Promise<void> => {
    if (isTauri) {
      try {
        const { invoke } = await import("@tauri-apps/api/core");
        await invoke("exit_app");
      } catch (e) {
        console.error(e);
      }
    }
    try {
      await fetch("http://127.0.0.1:4243/api/shutdown", { method: "POST" });
    } catch {
      // ignore
    }
  },

  onTelemetry: (callback: (telemetry: TelemetryEvent) => void): (() => void) => {
    let unlistenFn: (() => void) | null = null;
    if (isTauri) {
      import("@tauri-apps/api/event").then(({ listen }) => {
        listen<TelemetryEvent>("host-telemetry", (event) => {
          callback(event.payload);
        }).then((fn) => {
          unlistenFn = fn;
        });
      });
    }

    // Polling fallback interval every 500ms
    const interval = setInterval(async () => {
      try {
        const status = await tauriBridge.getHostStatus();
        callback({
          isConnected: status.isConnected,
          isServiceEnabled: status.isServiceEnabled,
          packetsPerSec: status.packetsPerSec,
          totalPackets: status.totalPackets,
          clientName: status.clientName,
          clientTransport: status.clientTransport,
        });
      } catch {
        // ignore
      }
    }, 500);

    return () => {
      clearInterval(interval);
      if (unlistenFn) {
        unlistenFn();
      }
    };
  },
};
