//! Non-linear ballistic mouse acceleration and sub-pixel accumulation.

#[derive(Debug, Clone)]
pub struct BallisticsConfig {
    /// Base sensitivity factor (typically 1.0)
    pub sensitivity: f32,
    /// Velocity threshold where acceleration begins kicking in (in raw delta units)
    pub threshold: f32,
    /// Acceleration exponent (typically 1.25 to 1.5)
    pub acceleration_exponent: f32,
    /// Maximum velocity scaling clamp to prevent wild cursor teleportation
    pub max_multiplier: f32,
}

impl Default for BallisticsConfig {
    fn default() -> Self {
        Self {
            sensitivity: 1.25,
            threshold: 3.0,
            acceleration_exponent: 1.35,
            max_multiplier: 4.5,
        }
    }
}

/// Computes accelerated cursor movement while preserving fractional sub-pixel remainders.
#[derive(Debug, Default)]
pub struct BallisticsEngine {
    pub config: BallisticsConfig,
    rem_x: f32,
    rem_y: f32,
}

impl BallisticsEngine {
    pub fn new(config: BallisticsConfig) -> Self {
        Self {
            config,
            rem_x: 0.0,
            rem_y: 0.0,
        }
    }

    /// Resets sub-pixel remainders (e.g., when all fingers lift from the surface).
    pub fn reset_accumulator(&mut self) {
        self.rem_x = 0.0;
        self.rem_y = 0.0;
    }

    /// Dynamically sets sensitivity factor.
    pub fn set_sensitivity(&mut self, sensitivity: f32) {
        self.config.sensitivity = sensitivity.clamp(0.2, 5.0);
    }

    /// Applies non-linear acceleration to raw dx/dy and returns integer OS mouse steps.
    pub fn process_delta(&mut self, raw_dx: i16, raw_dy: i16) -> (i32, i32) {
        let fx = raw_dx as f32;
        let fy = raw_dy as f32;

        let magnitude = (fx * fx + fy * fy).sqrt();
        if magnitude < 0.001 {
            return (0, 0);
        }

        // Calculate velocity scaling factor
        let multiplier = if magnitude <= self.config.threshold {
            self.config.sensitivity
        } else {
            let over = magnitude / self.config.threshold;
            let boosted = self.config.sensitivity * over.powf(self.config.acceleration_exponent - 1.0);
            boosted.min(self.config.max_multiplier)
        };

        // Compute accelerated floating deltas with accumulated remainders
        let target_x = fx * multiplier + self.rem_x;
        let target_y = fy * multiplier + self.rem_y;

        // Truncate to integer pixels for OS injection
        let out_x = target_x.trunc() as i32;
        let out_y = target_y.trunc() as i32;

        // Save remainder for subsequent frame
        self.rem_x = target_x.fract();
        self.rem_y = target_y.fract();

        // Clamp output to reasonable screen bounds to prevent hostile injection jumps
        let safe_x = out_x.clamp(-1500, 1500);
        let safe_y = out_y.clamp(-1500, 1500);

        (safe_x, safe_y)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zero_delta_returns_zero() {
        let mut engine = BallisticsEngine::default();
        assert_eq!(engine.process_delta(0, 0), (0, 0));
    }

    #[test]
    fn test_sub_pixel_accumulator_accumulates() {
        let mut config = BallisticsConfig::default();
        config.sensitivity = 0.5; // slow down movement
        config.threshold = 10.0;

        let mut engine = BallisticsEngine::new(config);

        // Frame 1: 1 * 0.5 = 0.5 -> trunc 0, rem 0.5
        let (x1, y1) = engine.process_delta(1, 0);
        assert_eq!((x1, y1), (0, 0));

        // Frame 2: 1 * 0.5 + 0.5 = 1.0 -> trunc 1, rem 0.0
        let (x2, y2) = engine.process_delta(1, 0);
        assert_eq!((x2, y2), (1, 0));
    }

    #[test]
    fn test_fast_flick_boosts_movement() {
        let mut engine = BallisticsEngine::default();
        let (x, _) = engine.process_delta(20, 0);
        // At delta 20, multiplier should be > base sensitivity
        assert!(x > 20);
    }
}
