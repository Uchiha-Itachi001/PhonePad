//! Input injection abstraction trait and types.

pub const WHEEL_DELTA: i32 = 120;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MouseButton {
    Left,
    Right,
    Middle,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NumpadKey {
    Num0 = 0,
    Num1 = 1,
    Num2 = 2,
    Num3 = 3,
    Num4 = 4,
    Num5 = 5,
    Num6 = 6,
    Num7 = 7,
    Num8 = 8,
    Num9 = 9,
    Add = 10,
    Subtract = 11,
    Multiply = 12,
    Divide = 13,
    Enter = 14,
    Backspace = 15,
    Decimal = 16,
    Unknown = 255,
}

impl From<i16> for NumpadKey {
    fn from(val: i16) -> Self {
        match val {
            0 => NumpadKey::Num0,
            1 => NumpadKey::Num1,
            2 => NumpadKey::Num2,
            3 => NumpadKey::Num3,
            4 => NumpadKey::Num4,
            5 => NumpadKey::Num5,
            6 => NumpadKey::Num6,
            7 => NumpadKey::Num7,
            8 => NumpadKey::Num8,
            9 => NumpadKey::Num9,
            10 => NumpadKey::Add,
            11 => NumpadKey::Subtract,
            12 => NumpadKey::Multiply,
            13 => NumpadKey::Divide,
            14 => NumpadKey::Enter,
            15 => NumpadKey::Backspace,
            16 => NumpadKey::Decimal,
            _ => NumpadKey::Unknown,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MediaKey {
    PlayPause = 1,
    VolumeUp = 2,
    VolumeDown = 3,
    Mute = 4,
    NextSlide = 5,
    PrevSlide = 6,
    NavBack = 7,
    NavForward = 8,
    Unknown = 255,
}

impl From<i16> for MediaKey {
    fn from(val: i16) -> Self {
        match val {
            1 => MediaKey::PlayPause,
            2 => MediaKey::VolumeUp,
            3 => MediaKey::VolumeDown,
            4 => MediaKey::Mute,
            5 => MediaKey::NextSlide,
            6 => MediaKey::PrevSlide,
            7 => MediaKey::NavBack,
            8 => MediaKey::NavForward,
            _ => MediaKey::Unknown,
        }
    }
}

/// Abstract interface for injecting OS-level mouse and keyboard events.
pub trait InputInjector: Send + Sync {
    /// Injects relative mouse movement by pixel deltas (dx, dy).
    fn move_relative(&mut self, dx: i32, dy: i32);

    /// Injects a complete Left Click (Down + Up).
    fn click_left(&mut self) {
        self.mouse_down(MouseButton::Left);
        self.mouse_up(MouseButton::Left);
    }

    /// Injects a complete Right Click (Down + Up).
    fn click_right(&mut self) {
        self.mouse_down(MouseButton::Right);
        self.mouse_up(MouseButton::Right);
    }

    /// Injects a complete Middle Click (Down + Up).
    fn click_middle(&mut self) {
        self.mouse_down(MouseButton::Middle);
        self.mouse_up(MouseButton::Middle);
    }

    /// Presses a mouse button down without releasing.
    fn mouse_down(&mut self, button: MouseButton);

    /// Releases a mouse button.
    fn mouse_up(&mut self, button: MouseButton);

    /// Injects vertical and horizontal scroll wheel increments (standard discrete notches).
    fn scroll(&mut self, dx: i32, dy: i32);

    /// Injects high-resolution fractional wheel deltas directly to OS wheel APIs.
    fn scroll_raw(&mut self, dx: i32, dy: i32) {
        let notches_x = dx / crate::input::WHEEL_DELTA;
        let notches_y = dy / crate::input::WHEEL_DELTA;
        if notches_x != 0 || notches_y != 0 {
            self.scroll(notches_x, notches_y);
        }
    }

    /// Injects Task View / Overview gesture (Win + Tab).
    fn show_task_view(&mut self);

    /// Injects Show Desktop gesture (Win + D).
    fn show_desktop(&mut self);

    /// Injects App Switch Next (Alt + Tab).
    fn app_switch_next(&mut self);

    /// Injects App Switch Prev (Alt + Shift + Tab).
    fn app_switch_prev(&mut self);

    /// Starts laptop precision Alt+Tab switcher (holds Alt down to display window picker).
    fn alt_tab_start(&mut self, forward: bool) {
        if forward {
            self.app_switch_next();
        } else {
            self.app_switch_prev();
        }
    }

    /// Moves selection in visible Alt+Tab switcher.
    fn alt_tab_step(&mut self, forward: bool) {
        if forward {
            self.app_switch_next();
        } else {
            self.app_switch_prev();
        }
    }

    /// Releases Alt key to switch to selected window and close switcher.
    fn alt_tab_finish(&mut self) {}

    /// Injects browser/explorer Navigation Back (Alt + Left).
    fn nav_back(&mut self);

    /// Injects browser/explorer Navigation Forward (Alt + Right).
    fn nav_forward(&mut self);

    /// Injects a discrete virtual Numpad keystroke.
    fn send_numpad_key(&mut self, key: NumpadKey);

    /// Injects a media or presentation slide control keystroke.
    fn send_media_key(&mut self, key: MediaKey);

    /// Injects zoom in / zoom out (positive notches = zoom in via Ctrl+Wheel, negative = zoom out).
    fn zoom(&mut self, notches: i32);
}

impl InputInjector for Box<dyn InputInjector> {
    fn move_relative(&mut self, dx: i32, dy: i32) {
        (**self).move_relative(dx, dy);
    }

    fn click_left(&mut self) {
        (**self).click_left();
    }

    fn click_right(&mut self) {
        (**self).click_right();
    }

    fn click_middle(&mut self) {
        (**self).click_middle();
    }

    fn mouse_down(&mut self, button: MouseButton) {
        (**self).mouse_down(button);
    }

    fn mouse_up(&mut self, button: MouseButton) {
        (**self).mouse_up(button);
    }

    fn scroll(&mut self, dx: i32, dy: i32) {
        (**self).scroll(dx, dy);
    }

    fn scroll_raw(&mut self, dx: i32, dy: i32) {
        (**self).scroll_raw(dx, dy);
    }

    fn show_task_view(&mut self) {
        (**self).show_task_view();
    }

    fn show_desktop(&mut self) {
        (**self).show_desktop();
    }

    fn app_switch_next(&mut self) {
        (**self).app_switch_next();
    }

    fn app_switch_prev(&mut self) {
        (**self).app_switch_prev();
    }

    fn alt_tab_start(&mut self, forward: bool) {
        (**self).alt_tab_start(forward);
    }

    fn alt_tab_step(&mut self, forward: bool) {
        (**self).alt_tab_step(forward);
    }

    fn alt_tab_finish(&mut self) {
        (**self).alt_tab_finish();
    }

    fn nav_back(&mut self) {
        (**self).nav_back();
    }

    fn nav_forward(&mut self) {
        (**self).nav_forward();
    }

    fn send_numpad_key(&mut self, key: NumpadKey) {
        (**self).send_numpad_key(key);
    }

    fn send_media_key(&mut self, key: MediaKey) {
        (**self).send_media_key(key);
    }

    fn zoom(&mut self, notches: i32) {
        (**self).zoom(notches);
    }
}
