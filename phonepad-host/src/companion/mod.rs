//! Host companion telemetry, sensitivity presets, and status monitoring.

use crate::gesture::BallisticsConfig;
use std::time::{Duration, Instant};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SensitivityPreset {
    Precision,
    Balanced,
    Agile4K,
}

impl SensitivityPreset {
    pub fn to_ballistics_config(self) -> BallisticsConfig {
        match self {
            SensitivityPreset::Precision => BallisticsConfig {
                sensitivity: 0.75,
                threshold: 6.0,
                acceleration_exponent: 1.20,
                max_multiplier: 2.5,
            },
            SensitivityPreset::Balanced => BallisticsConfig {
                sensitivity: 1.15,
                threshold: 4.0,
                acceleration_exponent: 1.35,
                max_multiplier: 4.5,
            },
            SensitivityPreset::Agile4K => BallisticsConfig {
                sensitivity: 1.60,
                threshold: 3.0,
                acceleration_exponent: 1.50,
                max_multiplier: 7.0,
            },
        }
    }
}

/// Tracks real-time connection telemetry, stream frequency, and battery health.
#[derive(Debug)]
pub struct CompanionTelemetry {
    pub preset: SensitivityPreset,
    pub total_packets: u64,
    pub current_hz: u32,
    pub phone_battery: Option<u8>,
    last_second_marker: Instant,
    packets_in_current_second: u32,
}

impl Default for CompanionTelemetry {
    fn default() -> Self {
        Self {
            preset: SensitivityPreset::Balanced,
            total_packets: 0,
            current_hz: 0,
            phone_battery: None,
            last_second_marker: Instant::now(),
            packets_in_current_second: 0,
        }
    }
}

impl CompanionTelemetry {
    pub fn new(preset: SensitivityPreset) -> Self {
        Self {
            preset,
            ..Default::default()
        }
    }

    /// Records an ingested packet and updates real-time frequency.
    pub fn record_packet(&mut self, flags: u8) {
        self.total_packets += 1;
        self.packets_in_current_second += 1;

        let now = Instant::now();
        let elapsed = now.duration_since(self.last_second_marker);
        if elapsed >= Duration::from_secs(1) {
            self.current_hz = self.packets_in_current_second;
            self.packets_in_current_second = 0;
            self.last_second_marker = now;
        }

        // Heartbeat or flags containing battery level in upper nibble
        let upper_nibble = (flags >> 4) & 0x0F;
        if upper_nibble > 0 {
            self.phone_battery = Some(upper_nibble * 10);
        }
    }

    /// Formats live telemetry banner for system tray popovers and logs.
    pub fn format_status_banner(&self, is_connected: bool, client_addr: &str) -> String {
        let status = if is_connected { "CONNECTED" } else { "LISTENING" };
        let battery_str = self
            .phone_battery
            .map(|b| format!("{}%", b))
            .unwrap_or_else(|| "Unknown".to_string());

        format!(
            "PhonePad Host [{}] | Client: {} | Rate: {} Hz | Preset: {:?} | Phone Battery: {}",
            status, client_addr, self.current_hz, self.preset, battery_str
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sensitivity_presets_produce_valid_ballistics() {
        let prec = SensitivityPreset::Precision.to_ballistics_config();
        assert!(prec.sensitivity < 1.0);

        let agile = SensitivityPreset::Agile4K.to_ballistics_config();
        assert!(agile.sensitivity > 1.2);
    }

    #[test]
    fn test_telemetry_packet_recording() {
        let mut telem = CompanionTelemetry::default();
        telem.record_packet(0x80); // upper nibble 8 -> 80% battery
        assert_eq!(telem.total_packets, 1);
        assert_eq!(telem.phone_battery, Some(80));
    }
}
