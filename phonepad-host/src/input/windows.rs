//! Windows-specific input injector using Win32 SendInput API.

use super::traits::{InputInjector, MediaKey, MouseButton, NumpadKey};
use windows_sys::Win32::UI::Input::KeyboardAndMouse::{
    SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, INPUT_MOUSE, KEYBDINPUT, KEYEVENTF_KEYUP,
    MOUSEEVENTF_HWHEEL, MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, MOUSEEVENTF_MIDDLEDOWN,
    MOUSEEVENTF_MIDDLEUP, MOUSEEVENTF_MOVE, MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP,
    MOUSEEVENTF_WHEEL, MOUSEINPUT, VK_ADD, VK_BACK, VK_D, VK_DECIMAL, VK_DIVIDE, VK_LWIN,
    VK_MEDIA_PLAY_PAUSE, VK_MENU, VK_MULTIPLY, VK_NEXT, VK_NUMPAD0, VK_NUMPAD1, VK_NUMPAD2,
    VK_NUMPAD3, VK_NUMPAD4, VK_NUMPAD5, VK_NUMPAD6, VK_NUMPAD7, VK_NUMPAD8, VK_NUMPAD9,
    VK_PRIOR, VK_RETURN, VK_RIGHT, VK_SHIFT, VK_SUBTRACT, VK_TAB, VK_VOLUME_DOWN, VK_VOLUME_MUTE,
    VK_VOLUME_UP, VK_LEFT,
};

const WHEEL_DELTA: i32 = 120;

#[derive(Default)]
pub struct WindowsInjector;

impl WindowsInjector {
    pub fn new() -> Self {
        Self
    }

    fn send_mouse_input(flags: u32, dx: i32, dy: i32, mouse_data: u32) {
        unsafe {
            let mouse_input = MOUSEINPUT {
                dx,
                dy,
                mouseData: mouse_data,
                dwFlags: flags,
                time: 0,
                dwExtraInfo: 0,
            };

            let input = INPUT {
                r#type: INPUT_MOUSE,
                Anonymous: INPUT_0 { mi: mouse_input },
            };

            let result = SendInput(1, &input, std::mem::size_of::<INPUT>() as i32);
            if result == 0 {
                log::warn!("Win32 SendInput returned 0 (failed to inject event)");
            }
        }
    }

    fn send_key(vk: u16, key_up: bool) {
        unsafe {
            let kb_input = KEYBDINPUT {
                wVk: vk,
                wScan: 0,
                dwFlags: if key_up { KEYEVENTF_KEYUP } else { 0 },
                time: 0,
                dwExtraInfo: 0,
            };

            let input = INPUT {
                r#type: INPUT_KEYBOARD,
                Anonymous: INPUT_0 { ki: kb_input },
            };

            SendInput(1, &input, std::mem::size_of::<INPUT>() as i32);
        }
    }

    fn trigger_combo(keys: &[u16]) {
        // Press in sequence
        for &key in keys {
            Self::send_key(key, false);
        }
        // Release in reverse sequence
        for &key in keys.iter().rev() {
            Self::send_key(key, true);
        }
    }

    fn tap_single_key(vk: u16) {
        Self::send_key(vk, false);
        Self::send_key(vk, true);
    }
}

impl InputInjector for WindowsInjector {
    fn move_relative(&mut self, dx: i32, dy: i32) {
        if dx == 0 && dy == 0 {
            return;
        }
        Self::send_mouse_input(MOUSEEVENTF_MOVE, dx, dy, 0);
    }

    fn mouse_down(&mut self, button: MouseButton) {
        let flag = match button {
            MouseButton::Left => MOUSEEVENTF_LEFTDOWN,
            MouseButton::Right => MOUSEEVENTF_RIGHTDOWN,
            MouseButton::Middle => MOUSEEVENTF_MIDDLEDOWN,
        };
        Self::send_mouse_input(flag, 0, 0, 0);
    }

    fn mouse_up(&mut self, button: MouseButton) {
        let flag = match button {
            MouseButton::Left => MOUSEEVENTF_LEFTUP,
            MouseButton::Right => MOUSEEVENTF_RIGHTUP,
            MouseButton::Middle => MOUSEEVENTF_MIDDLEUP,
        };
        Self::send_mouse_input(flag, 0, 0, 0);
    }

    fn click_left(&mut self) {
        Self::send_mouse_input(MOUSEEVENTF_LEFTDOWN, 0, 0, 0);
        std::thread::sleep(std::time::Duration::from_millis(12));
        Self::send_mouse_input(MOUSEEVENTF_LEFTUP, 0, 0, 0);
    }

    fn click_right(&mut self) {
        Self::send_mouse_input(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0);
        std::thread::sleep(std::time::Duration::from_millis(12));
        Self::send_mouse_input(MOUSEEVENTF_RIGHTUP, 0, 0, 0);
    }

    fn click_middle(&mut self) {
        Self::send_mouse_input(MOUSEEVENTF_MIDDLEDOWN, 0, 0, 0);
        std::thread::sleep(std::time::Duration::from_millis(12));
        Self::send_mouse_input(MOUSEEVENTF_MIDDLEUP, 0, 0, 0);
    }

    fn scroll(&mut self, dx: i32, dy: i32) {
        // Vertical wheel: positive dy scrolls up
        if dy != 0 {
            let delta = dy * WHEEL_DELTA;
            Self::send_mouse_input(MOUSEEVENTF_WHEEL, 0, 0, delta as u32);
        }
        // Horizontal wheel: positive dx scrolls right
        if dx != 0 {
            let delta = dx * WHEEL_DELTA;
            Self::send_mouse_input(MOUSEEVENTF_HWHEEL, 0, 0, delta as u32);
        }
    }

    fn show_task_view(&mut self) {
        log::debug!("Injecting Task View shortcut (Win + Tab)");
        Self::trigger_combo(&[VK_LWIN, VK_TAB]);
    }

    fn show_desktop(&mut self) {
        log::debug!("Injecting Show Desktop shortcut (Win + D)");
        Self::trigger_combo(&[VK_LWIN, VK_D]);
    }

    fn app_switch_next(&mut self) {
        log::debug!("Injecting App Switch Next (Alt + Tab)");
        Self::trigger_combo(&[VK_MENU, VK_TAB]);
    }

    fn app_switch_prev(&mut self) {
        log::debug!("Injecting App Switch Prev (Alt + Shift + Tab)");
        Self::trigger_combo(&[VK_MENU, VK_SHIFT, VK_TAB]);
    }

    fn alt_tab_start(&mut self, forward: bool) {
        log::debug!("Starting laptop precision Alt+Tab switcher (Alt down)");
        Self::send_key(VK_MENU, false); // Hold Alt DOWN
        if forward {
            Self::tap_single_key(VK_TAB);
        } else {
            Self::send_key(VK_SHIFT, false);
            Self::tap_single_key(VK_TAB);
            Self::send_key(VK_SHIFT, true);
        }
    }

    fn alt_tab_step(&mut self, forward: bool) {
        log::debug!("Stepping laptop Alt+Tab switcher (forward: {})", forward);
        if forward {
            Self::tap_single_key(VK_TAB);
        } else {
            Self::send_key(VK_SHIFT, false);
            Self::tap_single_key(VK_TAB);
            Self::send_key(VK_SHIFT, true);
        }
    }

    fn alt_tab_finish(&mut self) {
        log::debug!("Finishing laptop Alt+Tab switcher (Alt up)");
        Self::send_key(VK_MENU, true); // Release Alt
    }

    fn nav_back(&mut self) {
        log::debug!("Injecting Browser/Explorer Back (Alt + Left)");
        Self::trigger_combo(&[VK_MENU, VK_LEFT]);
    }

    fn nav_forward(&mut self) {
        log::debug!("Injecting Browser/Explorer Forward (Alt + Right)");
        Self::trigger_combo(&[VK_MENU, VK_RIGHT]);
    }

    fn send_numpad_key(&mut self, key: NumpadKey) {
        let vk = match key {
            NumpadKey::Num0 => VK_NUMPAD0,
            NumpadKey::Num1 => VK_NUMPAD1,
            NumpadKey::Num2 => VK_NUMPAD2,
            NumpadKey::Num3 => VK_NUMPAD3,
            NumpadKey::Num4 => VK_NUMPAD4,
            NumpadKey::Num5 => VK_NUMPAD5,
            NumpadKey::Num6 => VK_NUMPAD6,
            NumpadKey::Num7 => VK_NUMPAD7,
            NumpadKey::Num8 => VK_NUMPAD8,
            NumpadKey::Num9 => VK_NUMPAD9,
            NumpadKey::Add => VK_ADD,
            NumpadKey::Subtract => VK_SUBTRACT,
            NumpadKey::Multiply => VK_MULTIPLY,
            NumpadKey::Divide => VK_DIVIDE,
            NumpadKey::Enter => VK_RETURN,
            NumpadKey::Backspace => VK_BACK,
            NumpadKey::Decimal => VK_DECIMAL,
            NumpadKey::Unknown => return,
        };
        log::debug!("Injecting Numpad key {:?}", key);
        Self::tap_single_key(vk);
    }

    fn send_media_key(&mut self, key: MediaKey) {
        let vk = match key {
            MediaKey::PlayPause => VK_MEDIA_PLAY_PAUSE,
            MediaKey::VolumeUp => VK_VOLUME_UP,
            MediaKey::VolumeDown => VK_VOLUME_DOWN,
            MediaKey::Mute => VK_VOLUME_MUTE,
            MediaKey::NextSlide => VK_NEXT,
            MediaKey::PrevSlide => VK_PRIOR,
            MediaKey::NavBack => {
                self.nav_back();
                return;
            }
            MediaKey::NavForward => {
                self.nav_forward();
                return;
            }
            MediaKey::Unknown => return,
        };
        log::debug!("Injecting Media key {:?}", key);
        Self::tap_single_key(vk);
    }
}
