//! Gesture filtering, deadzones, and scroll notch accumulation.

#[derive(Debug, Clone)]
pub struct FilterConfig {
    /// Jitter deadzone in raw units (movements below this are filtered out)
    pub deadzone_threshold: f32,
    /// Number of touch delta units required to trigger one discrete OS scroll notch
    pub scroll_units_per_notch: f32,
    /// Natural scroll direction (true = natural trackpad, false = traditional mouse wheel)
    pub natural_scroll: bool,
}

impl Default for FilterConfig {
    fn default() -> Self {
        Self {
            deadzone_threshold: 0.4,
            scroll_units_per_notch: 16.0,
            natural_scroll: true,
        }
    }
}

/// Filters noise and translates raw 2-finger deltas to smooth OS scroll wheel clicks.
#[derive(Debug, Default)]
pub struct GestureFilter {
    pub config: FilterConfig,
    scroll_accum_x: f32,
    scroll_accum_y: f32,
}

impl GestureFilter {
    pub fn new(config: FilterConfig) -> Self {
        Self {
            config,
            scroll_accum_x: 0.0,
            scroll_accum_y: 0.0,
        }
    }

    /// Suppresses micro-jitter when finger is nearly stationary.
    #[inline]
    pub fn apply_deadzone(&self, raw_dx: i16, raw_dy: i16) -> (i16, i16) {
        let mag = ((raw_dx as f32).powi(2) + (raw_dy as f32).powi(2)).sqrt();
        if mag < self.config.deadzone_threshold {
            (0, 0)
        } else {
            (raw_dx, raw_dy)
        }
    }

    /// Suppresses floating-point micro-jitter when finger is nearly stationary.
    #[inline]
    pub fn apply_deadzone_f32(&self, fx: f32, fy: f32) -> (f32, f32) {
        let mag = (fx * fx + fy * fy).sqrt();
        if mag < self.config.deadzone_threshold {
            (0.0, 0.0)
        } else {
            (fx, fy)
        }
    }

    /// Converts raw continuous 2-finger scroll deltas into OS wheel click increments.
    pub fn process_scroll(&mut self, raw_dx: i16, raw_dy: i16) -> (i32, i32) {
        let direction_factor = if self.config.natural_scroll { 1.0 } else { -1.0 };

        self.scroll_accum_x += raw_dx as f32 * direction_factor;
        self.scroll_accum_y += raw_dy as f32 * direction_factor;

        let notches_x = (self.scroll_accum_x / self.config.scroll_units_per_notch).trunc() as i32;
        let notches_y = (self.scroll_accum_y / self.config.scroll_units_per_notch).trunc() as i32;

        self.scroll_accum_x -= notches_x as f32 * self.config.scroll_units_per_notch;
        self.scroll_accum_y -= notches_y as f32 * self.config.scroll_units_per_notch;

        (notches_x, notches_y)
    }

    /// Converts continuous 2-finger scroll deltas into high-resolution OS wheel increments.
    pub fn process_smooth_scroll(&mut self, fx: f32, fy: f32) -> (i32, i32) {
        let direction_factor = if self.config.natural_scroll { 1.0 } else { -1.0 };
        let scale = (crate::input::WHEEL_DELTA as f32) / self.config.scroll_units_per_notch;

        let target_x = (fx * direction_factor * scale) + self.scroll_accum_x;
        let target_y = (fy * direction_factor * scale) + self.scroll_accum_y;

        let wheel_x = target_x.round() as i32;
        let wheel_y = target_y.round() as i32;

        self.scroll_accum_x = target_x - (wheel_x as f32);
        self.scroll_accum_y = target_y - (wheel_y as f32);

        (wheel_x, wheel_y)
    }

    /// Resets scroll accumulators when fingers are lifted.
    pub fn reset(&mut self) {
        self.scroll_accum_x = 0.0;
        self.scroll_accum_y = 0.0;
    }

    /// Sets natural scroll direction.
    pub fn set_natural_scroll(&mut self, natural: bool) {
        self.config.natural_scroll = natural;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_deadzone_filters_tiny_noise() {
        let filter = GestureFilter::default();
        assert_eq!(filter.apply_deadzone(0, 0), (0, 0));
        assert_eq!(filter.apply_deadzone(1, 1), (1, 1));
    }

    #[test]
    fn test_scroll_accumulator_produces_notches() {
        let mut filter = GestureFilter::default();

        // 8 units: not yet a full 16-unit notch
        let (sx, sy) = filter.process_scroll(0, 8);
        assert_eq!((sx, sy), (0, 0));

        // Another 8 units: now 16 units -> 1 notch
        let (sx2, sy2) = filter.process_scroll(0, 8);
        assert_eq!((sx2, sy2), (0, 1));
    }

    #[test]
    fn test_natural_scroll_inversion() {
        let mut filter = GestureFilter::new(FilterConfig {
            deadzone_threshold: 0.8,
            scroll_units_per_notch: 16.0,
            natural_scroll: false,
        });

        let (sx, sy) = filter.process_scroll(0, 16);
        assert_eq!((sx, sy), (0, -1));
    }

    #[test]
    fn test_deadzone_f32() {
        let filter = GestureFilter::default();
        assert_eq!(filter.apply_deadzone_f32(0.1, 0.2), (0.0, 0.0));
        assert_eq!(filter.apply_deadzone_f32(1.0, 0.0), (1.0, 0.0));
    }

    #[test]
    fn test_process_smooth_scroll_continuous_increments() {
        let mut filter = GestureFilter::default();
        // 1.0 unit delta -> 7.5 wheel units -> rounds to 8
        let (wx1, wy1) = filter.process_smooth_scroll(0.0, 1.0);
        assert_eq!((wx1, wy1), (0, 8));

        // Next 1.0 unit delta -> 7.5 - 0.5 remainder = 7.0 -> rounds to 7
        let (wx2, wy2) = filter.process_smooth_scroll(0.0, 1.0);
        assert_eq!((wx2, wy2), (0, 7));
    }
}

