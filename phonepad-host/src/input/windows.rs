//! Windows-specific input injector using Win32 SendInput API.

use super::traits::{
    InputInjector, MediaKey, MouseButton, NumpadKey, ShortcutKey, SpecialKey,
    KEY_TYPE_SHORTCUT, KEY_TYPE_SPECIAL, KEY_TYPE_UNICODE,
};
use windows_sys::Win32::UI::Input::KeyboardAndMouse::{
    SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, INPUT_MOUSE, KEYBDINPUT, KEYEVENTF_KEYUP,
    KEYEVENTF_UNICODE, MOUSEEVENTF_HWHEEL, MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP,
    MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP, MOUSEEVENTF_MOVE, MOUSEEVENTF_RIGHTDOWN,
    MOUSEEVENTF_RIGHTUP, MOUSEEVENTF_WHEEL, MOUSEINPUT, VK_ADD, VK_BACK, VK_CONTROL, VK_D,
    VK_DECIMAL, VK_DELETE, VK_DIVIDE, VK_DOWN, VK_END, VK_ESCAPE, VK_HOME, VK_LEFT, VK_LWIN,
    VK_MEDIA_PLAY_PAUSE, VK_MENU, VK_MULTIPLY, VK_NEXT, VK_NUMPAD0, VK_NUMPAD1, VK_NUMPAD2,
    VK_NUMPAD3, VK_NUMPAD4, VK_NUMPAD5, VK_NUMPAD6, VK_NUMPAD7, VK_NUMPAD8, VK_NUMPAD9,
    VK_PRIOR, VK_RETURN, VK_RIGHT, VK_SHIFT, VK_SPACE, VK_SUBTRACT, VK_TAB, VK_UP,
    VK_VOLUME_DOWN, VK_VOLUME_MUTE, VK_VOLUME_UP,
};

const WHEEL_DELTA: i32 = 120;

#[derive(Default)]
pub struct WindowsInjector;

impl WindowsInjector {
    pub fn new() -> Self {
        Self::ensure_attached_to_input_desktop();
        Self
    }

    pub fn ensure_attached_to_input_desktop() {
        #[link(name = "user32")]
        unsafe extern "system" {
            fn OpenInputDesktop(dwflags: u32, finherit: i32, dwdesiredaccess: u32) -> *mut core::ffi::c_void;
            fn SetThreadDesktop(hdesktop: *mut core::ffi::c_void) -> i32;
        }
        unsafe {
            const DESKTOP_ALL: u32 = 0x01FF;
            let desk = OpenInputDesktop(0, 0, DESKTOP_ALL);
            if !desk.is_null() {
                SetThreadDesktop(desk);
            }
        }
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

            let mut result = SendInput(1, &input, std::mem::size_of::<INPUT>() as i32);
            if result == 0 {
                Self::ensure_attached_to_input_desktop();
                result = SendInput(1, &input, std::mem::size_of::<INPUT>() as i32);
                if result == 0 {
                    log::warn!("Win32 SendInput returned 0 (failed to inject event)");
                }
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

            let mut result = SendInput(1, &input, std::mem::size_of::<INPUT>() as i32);
            if result == 0 {
                Self::ensure_attached_to_input_desktop();
                result = SendInput(1, &input, std::mem::size_of::<INPUT>() as i32);
                if result == 0 {
                    log::warn!("Win32 SendInput key returned 0 (failed to inject key)");
                }
            }
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
        std::thread::sleep(std::time::Duration::from_millis(4));
        Self::send_key(vk, true);
    }

    fn send_unicode_char(code: u16) {
        unsafe {
            let kb_down = KEYBDINPUT {
                wVk: 0,
                wScan: code,
                dwFlags: KEYEVENTF_UNICODE,
                time: 0,
                dwExtraInfo: 0,
            };
            let input_down = INPUT {
                r#type: INPUT_KEYBOARD,
                Anonymous: INPUT_0 { ki: kb_down },
            };

            let kb_up = KEYBDINPUT {
                wVk: 0,
                wScan: code,
                dwFlags: KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
                time: 0,
                dwExtraInfo: 0,
            };
            let input_up = INPUT {
                r#type: INPUT_KEYBOARD,
                Anonymous: INPUT_0 { ki: kb_up },
            };

            let mut res_down = SendInput(1, &input_down, std::mem::size_of::<INPUT>() as i32);
            if res_down == 0 {
                Self::ensure_attached_to_input_desktop();
                res_down = SendInput(1, &input_down, std::mem::size_of::<INPUT>() as i32);
                if res_down == 0 {
                    log::warn!("SendInput unicode char down returned 0 for U+{:04X}", code);
                }
            }
            std::thread::sleep(std::time::Duration::from_millis(4));
            let mut res_up = SendInput(1, &input_up, std::mem::size_of::<INPUT>() as i32);
            if res_up == 0 {
                Self::ensure_attached_to_input_desktop();
                res_up = SendInput(1, &input_up, std::mem::size_of::<INPUT>() as i32);
                if res_up == 0 {
                    log::warn!("SendInput unicode char up returned 0 for U+{:04X}", code);
                }
            }
        }
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

    fn scroll_raw(&mut self, dx: i32, dy: i32) {
        // High-resolution continuous wheel: positive dy scrolls up
        if dy != 0 {
            Self::send_mouse_input(MOUSEEVENTF_WHEEL, 0, 0, dy as u32);
        }
        // High-resolution horizontal wheel: positive dx scrolls right
        if dx != 0 {
            Self::send_mouse_input(MOUSEEVENTF_HWHEEL, 0, 0, dx as u32);
        }
    }

    fn scroll(&mut self, dx: i32, dy: i32) {
        self.scroll_raw(dx * WHEEL_DELTA, dy * WHEEL_DELTA);
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

    fn send_keyboard_event(&mut self, event_type: u8, code: u16) {
        match event_type {
            KEY_TYPE_UNICODE => {
                log::debug!("Injecting Unicode char U+{:04X}", code);
                Self::send_unicode_char(code);
            }
            KEY_TYPE_SPECIAL => {
                let special = SpecialKey::from(code);
                let vk = match special {
                    SpecialKey::Backspace => VK_BACK,
                    SpecialKey::Enter => VK_RETURN,
                    SpecialKey::Tab => VK_TAB,
                    SpecialKey::Escape => VK_ESCAPE,
                    SpecialKey::Delete => VK_DELETE,
                    SpecialKey::ArrowUp => VK_UP,
                    SpecialKey::ArrowDown => VK_DOWN,
                    SpecialKey::ArrowLeft => VK_LEFT,
                    SpecialKey::ArrowRight => VK_RIGHT,
                    SpecialKey::Home => VK_HOME,
                    SpecialKey::End => VK_END,
                    SpecialKey::PageUp => VK_PRIOR,
                    SpecialKey::PageDown => VK_NEXT,
                    SpecialKey::Space => VK_SPACE,
                    SpecialKey::Unknown => return,
                };
                log::debug!("Injecting SpecialKey {:?} (VK: 0x{:02X})", special, vk);
                Self::tap_single_key(vk);
            }
            KEY_TYPE_SHORTCUT => {
                let shortcut = ShortcutKey::from(code);
                let target_key = match shortcut {
                    ShortcutKey::SelectAll => b'A' as u16,
                    ShortcutKey::Copy => b'C' as u16,
                    ShortcutKey::Paste => b'V' as u16,
                    ShortcutKey::Cut => b'X' as u16,
                    ShortcutKey::Undo => b'Z' as u16,
                    ShortcutKey::Redo => b'Y' as u16,
                    ShortcutKey::Save => b'S' as u16,
                    ShortcutKey::Unknown => return,
                };
                log::debug!("Injecting Shortcut {:?} (Ctrl + 0x{:02X})", shortcut, target_key);
                Self::trigger_combo(&[VK_CONTROL, target_key]);
            }
            _ => {
                log::warn!("Unknown keyboard event type: {}", event_type);
            }
        }
    }

    fn zoom(&mut self, notches: i32) {
        if notches == 0 {
            return;
        }
        log::debug!("Injecting Zoom via Ctrl+Wheel: notches={}", notches);
        // Hold Ctrl down
        Self::send_key(VK_CONTROL, false);
        // Inject wheel delta (positive = zoom in, negative = zoom out)
        let delta = notches * WHEEL_DELTA;
        Self::send_mouse_input(MOUSEEVENTF_WHEEL, 0, 0, delta as u32);
        // Release Ctrl
        Self::send_key(VK_CONTROL, true);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_send_input_diagnostic() {
        WindowsInjector::ensure_attached_to_input_desktop();
        unsafe {
            let mi = MOUSEINPUT {
                dx: 0,
                dy: 0,
                mouseData: 0,
                dwFlags: MOUSEEVENTF_MOVE,
                time: 0,
                dwExtraInfo: 0,
            };
            let input = INPUT {
                r#type: INPUT_MOUSE,
                Anonymous: INPUT_0 { mi },
            };
            let sent = SendInput(1, &input, std::mem::size_of::<INPUT>() as i32);
            let err = windows_sys::Win32::Foundation::GetLastError();
            println!("\n>>> DIAGNOSTIC: SendInput returned {}, GetLastError = {} (size_of<INPUT> = {}) <<<\n", sent, err, std::mem::size_of::<INPUT>());
            assert_eq!(sent, 1, "SendInput must succeed once attached to input desktop");
        }
    }
}
