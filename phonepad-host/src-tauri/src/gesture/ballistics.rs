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
            sensitivity: 1.35,
            threshold: 2.5,
            acceleration_exponent: 1.25,
            max_multiplier: 3.8,
        }
    }
}

/// Computes accelerated cursor movement while preserving fractional sub-pixel remainders.
#[derive(Debug, Default)]
pub struct BallisticsEngine {
    pub config: BallisticsConfig,
    rem_x: f32,
    rem_y: f32,
    smooth_dx: f32,
    smooth_dy: f32,
    has_active_stroke: bool,
}

impl BallisticsEngine {
    pub fn new(config: BallisticsConfig) -> Self {
        Self {
            config,
            rem_x: 0.0,
            rem_y: 0.0,
            smooth_dx: 0.0,
            smooth_dy: 0.0,
            has_active_stroke: false,
        }
    }

    /// Resets sub-pixel remainders (e.g., when all fingers lift from the surface).
    pub fn reset_accumulator(&mut self) {
        self.rem_x = 0.0;
        self.rem_y = 0.0;
        self.smooth_dx = 0.0;
        self.smooth_dy = 0.0;
        self.has_active_stroke = false;
    }

    /// Dynamically sets sensitivity factor.
    pub fn set_sensitivity(&mut self, sensitivity: f32) {
        self.config.sensitivity = sensitivity.clamp(0.2, 5.0);
    }

    /// Applies non-linear acceleration to raw dx/dy and returns integer OS mouse steps.
    pub fn process_delta(&mut self, raw_dx: i16, raw_dy: i16) -> (i32, i32) {
        self.process_delta_f32(raw_dx as f32, raw_dy as f32)
    }

    /// Applies adaptive low-pass smoothing and non-linear acceleration to floating-point deltas.
    pub fn process_delta_f32(&mut self, fx: f32, fy: f32) -> (i32, i32) {
        let magnitude = (fx * fx + fy * fy).sqrt();
        if magnitude < 0.001 {
            return (0, 0);
        }

        // Initialize stroke tracking on first movement event
        if !self.has_active_stroke {
            self.smooth_dx = fx;
            self.smooth_dy = fy;
            self.has_active_stroke = true;
        } else {
            // Adaptive low-pass filter: smooths micro-jitter on slow precision moves,
            // while retaining instant response (alpha -> 1.0) on fast flicks
            let alpha = (0.70 + 0.15 * (magnitude / self.config.threshold)).clamp(0.70, 1.0);
            self.smooth_dx = self.smooth_dx * (1.0 - alpha) + fx * alpha;
            self.smooth_dy = self.smooth_dy * (1.0 - alpha) + fy * alpha;
        }

        let v_mag = (self.smooth_dx * self.smooth_dx + self.smooth_dy * self.smooth_dy).sqrt();

        // Calculate velocity scaling factor from smoothed velocity
        let multiplier = if v_mag <= self.config.threshold {
            self.config.sensitivity
        } else {
            let over = v_mag / self.config.threshold;
            let boosted = self.config.sensitivity * over.powf(self.config.acceleration_exponent - 1.0);
            boosted.min(self.config.max_multiplier)
        };

        // Compute accelerated floating deltas with accumulated remainders
        let target_x = self.smooth_dx * multiplier + self.rem_x;
        let target_y = self.smooth_dy * multiplier + self.rem_y;

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
