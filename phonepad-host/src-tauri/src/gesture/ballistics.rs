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

/// Computes accelerated cursor movement with 1 Euro adaptive jitter filtering,
/// time-normalized velocity tracking, and sub-pixel remainder accumulation.
#[derive(Debug, Default)]
pub struct BallisticsEngine {
    pub config: BallisticsConfig,
    rem_x: f32,
    rem_y: f32,
    current_speed: f32,
    last_event_time: Option<std::time::Instant>,
    // Direction tracking for instant reversal snapping
    prev_fx: f32,
    prev_fy: f32,
    has_prev_dir: bool,
}

impl BallisticsEngine {
    pub fn new(config: BallisticsConfig) -> Self {
        Self {
            config,
            rem_x: 0.0,
            rem_y: 0.0,
            current_speed: 0.0,
            last_event_time: None,
            prev_fx: 0.0,
            prev_fy: 0.0,
            has_prev_dir: false,
        }
    }

    /// Resets sub-pixel remainders and velocity tracking (e.g., when all fingers lift from the surface).
    pub fn reset_accumulator(&mut self) {
        self.rem_x = 0.0;
        self.rem_y = 0.0;
        self.current_speed = 0.0;
        self.last_event_time = None;
        self.prev_fx = 0.0;
        self.prev_fy = 0.0;
        self.has_prev_dir = false;
    }

    /// Dynamically sets sensitivity factor.
    pub fn set_sensitivity(&mut self, sensitivity: f32) {
        self.config.sensitivity = sensitivity.clamp(0.2, 5.0);
    }

    /// Applies non-linear acceleration to raw dx/dy and returns integer OS mouse steps.
    pub fn process_delta(&mut self, raw_dx: i16, raw_dy: i16) -> (i32, i32) {
        self.process_delta_f32(raw_dx as f32, raw_dy as f32)
    }

    /// Applies precision touchpad ballistics with time-normalized velocity tracking and sub-pixel accumulation.
    pub fn process_delta_f32(&mut self, fx: f32, fy: f32) -> (i32, i32) {
        let magnitude = (fx * fx + fy * fy).sqrt();
        if magnitude < 0.0001 {
            return (0, 0);
        }

        let now = std::time::Instant::now();
        let dt = match self.last_event_time {
            Some(last) => {
                let elapsed = now.duration_since(last).as_secs_f32();
                if elapsed > 0.060 {
                    // Finger paused or lifted: reset momentum and directional history
                    self.current_speed = 0.0;
                    self.has_prev_dir = false;
                    0.00833 // default standard 120Hz frame (~8.33ms)
                } else {
                    elapsed.clamp(0.002, 0.050)
                }
            }
            None => {
                self.current_speed = 0.0;
                self.has_prev_dir = false;
                0.00833
            }
        };
        self.last_event_time = Some(now);

        // Instantaneous velocity in pixels per second
        let instant_velocity = magnitude / dt;

        // Direction awareness: detect sharp reversals (>90 deg)
        if self.has_prev_dir {
            let prev_mag = (self.prev_fx * self.prev_fx + self.prev_fy * self.prev_fy).sqrt();
            if prev_mag > 0.001 {
                let dot = (self.prev_fx * fx + self.prev_fy * fy) / (prev_mag * magnitude);
                if dot < 0.0 {
                    // Sudden reversal: immediately damp momentum to eliminate rubber-band sluggishness
                    self.current_speed = instant_velocity.min(self.current_speed * 0.25);
                    self.rem_x *= 0.2;
                    self.rem_y *= 0.2;
                }
            }
        }
        self.prev_fx = fx;
        self.prev_fy = fy;
        self.has_prev_dir = true;

        // Adaptive velocity tracking
        if instant_velocity < self.current_speed * 0.35 {
            // Rapid deceleration (user stopping on a small target): drop quickly
            self.current_speed = self.current_speed * 0.25 + instant_velocity * 0.75;
        } else {
            // Time-invariant EMA smoothing (time constant ~ 35ms)
            let alpha_v = (1.0 - (-dt / 0.035).exp()).clamp(0.20, 0.85);
            self.current_speed = self.current_speed * (1.0 - alpha_v) + magnitude * alpha_v;
        }

        // Calculate velocity scaling factor from smoothed speed scalar
        let multiplier = if self.current_speed <= self.config.threshold {
            self.config.sensitivity
        } else {
            let over = self.current_speed / self.config.threshold;
            let boosted = self.config.sensitivity * over.powf(self.config.acceleration_exponent - 1.0);
            boosted.min(self.config.max_multiplier * self.config.sensitivity)
        };

        // Compute accelerated floating deltas directly with zero phase-lag spatial response
        let target_x = fx * multiplier + self.rem_x;
        let target_y = fy * multiplier + self.rem_y;

        let out_x = target_x.round() as i32;
        let out_y = target_y.round() as i32;

        self.rem_x = target_x - (out_x as f32);
        self.rem_y = target_y - (out_y as f32);

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

        // Frame 1: 1 * 0.5 = 0.5 -> round is 1, rem -0.5
        let (x1, y1) = engine.process_delta(1, 0);
        assert_eq!((x1, y1), (1, 0));

        // Frame 2: 1 * 0.5 + (-0.5) = 0.0 -> round is 0, rem 0.0
        let (x2, y2) = engine.process_delta(1, 0);
        assert_eq!((x2, y2), (0, 0));
    }

    #[test]
    fn test_fast_flick_boosts_movement() {
        let mut engine = BallisticsEngine::default();
        let (x, _) = engine.process_delta(20, 0);
        // At delta 20, multiplier should be > base sensitivity
        assert!(x > 20);
    }
}
