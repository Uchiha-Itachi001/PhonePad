export interface HostStatus {
  isRunning: boolean;
  isServiceEnabled: boolean;
  isConnected: boolean;
  localIp: string;
  port: number;
  computerName: string;
  authPin: number;
  clientName: string;
  clientTransport: string;
  packetsPerSec: number;
  totalPackets: number;
  sensitivity: number;
  naturalScroll: boolean;
  gesturesEnabled: boolean;
  tapToClick: boolean;
  qrPayload: string;
}

export interface TelemetryEvent {
  isConnected: boolean;
  isServiceEnabled: boolean;
  packetsPerSec: number;
  totalPackets: number;
  clientName: string;
  clientTransport: string;
}

export interface UpdateSettingsPayload {
  sensitivity?: number;
  naturalScroll?: boolean;
  gesturesEnabled?: boolean;
  tapToClick?: boolean;
}
