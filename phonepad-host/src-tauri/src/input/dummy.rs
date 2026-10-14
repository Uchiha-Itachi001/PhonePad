//! Dummy injector recording injected events for unit testing and CI.

use super::traits::{InputInjector, MediaKey, MouseButton, NumpadKey};

#[derive(Default, Debug)]
pub struct DummyInjector {
    pub moved_x: i32,
    pub moved_y: i32,
    pub left_clicks: usize,
    pub right_clicks: usize,
    pub middle_clicks: usize,
    pub mouse_down_count: usize,
    pub mouse_up_count: usize,
    pub scroll_x: i32,
    pub scroll_y: i32,
    pub scroll_raw_x: i32,
    pub scroll_raw_y: i32,
    pub task_view_count: usize,
    pub show_desktop_count: usize,
    pub app_switch_next_count: usize,
    pub app_switch_prev_count: usize,
    pub alt_tab_active: bool,
    pub alt_tab_start_count: usize,
    pub alt_tab_step_count: usize,
    pub alt_tab_finish_count: usize,
    pub nav_back_count: usize,
    pub nav_forward_count: usize,
    pub numpad_keys: Vec<NumpadKey>,
    pub media_keys: Vec<MediaKey>,
    pub keyboard_events: Vec<(u8, u16)>,
    pub zoom_notches: i32,
}

impl DummyInjector {
    pub fn new() -> Self {
        Self::default()
    }
}

impl InputInjector for DummyInjector {
    fn move_relative(&mut self, dx: i32, dy: i32) {
        self.moved_x += dx;
        self.moved_y += dy;
    }

    fn click_left(&mut self) {
        self.left_clicks += 1;
    }

    fn click_right(&mut self) {
        self.right_clicks += 1;
    }

    fn click_middle(&mut self) {
        self.middle_clicks += 1;
    }

    fn mouse_down(&mut self, _button: MouseButton) {
        self.mouse_down_count += 1;
    }

    fn mouse_up(&mut self, _button: MouseButton) {
        self.mouse_up_count += 1;
    }

    fn scroll(&mut self, dx: i32, dy: i32) {
        self.scroll_x += dx;
        self.scroll_y += dy;
        self.scroll_raw_x += dx * crate::input::WHEEL_DELTA;
        self.scroll_raw_y += dy * crate::input::WHEEL_DELTA;
    }

    fn scroll_raw(&mut self, dx: i32, dy: i32) {
        self.scroll_raw_x += dx;
        self.scroll_raw_y += dy;
        self.scroll_x += dx / crate::input::WHEEL_DELTA;
        self.scroll_y += dy / crate::input::WHEEL_DELTA;
    }

    fn show_task_view(&mut self) {
        self.task_view_count += 1;
    }

    fn show_desktop(&mut self) {
        self.show_desktop_count += 1;
    }

    fn app_switch_next(&mut self) {
        self.app_switch_next_count += 1;
    }

    fn app_switch_prev(&mut self) {
        self.app_switch_prev_count += 1;
    }

    fn alt_tab_start(&mut self, forward: bool) {
        self.alt_tab_active = true;
        self.alt_tab_start_count += 1;
        if forward {
            self.app_switch_next_count += 1;
        } else {
            self.app_switch_prev_count += 1;
        }
    }

    fn alt_tab_step(&mut self, forward: bool) {
        self.alt_tab_step_count += 1;
        if forward {
            self.app_switch_next_count += 1;
        } else {
            self.app_switch_prev_count += 1;
        }
    }

    fn alt_tab_finish(&mut self) {
        self.alt_tab_active = false;
        self.alt_tab_finish_count += 1;
    }

    fn nav_back(&mut self) {
        self.nav_back_count += 1;
    }

    fn nav_forward(&mut self) {
        self.nav_forward_count += 1;
    }

    fn send_numpad_key(&mut self, key: NumpadKey) {
        self.numpad_keys.push(key);
    }

    fn send_media_key(&mut self, key: MediaKey) {
        match key {
            MediaKey::NavBack => self.nav_back(),
            MediaKey::NavForward => self.nav_forward(),
            _ => self.media_keys.push(key),
        }
    }

    fn send_keyboard_event(&mut self, event_type: u8, code: u16) {
        self.keyboard_events.push((event_type, code));
    }

    fn zoom(&mut self, notches: i32) {
        self.zoom_notches += notches;
    }
}
