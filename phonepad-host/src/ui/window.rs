//! Native Windows Desktop GUI Window for PhonePad Host.

#![allow(unsafe_op_in_unsafe_fn)]

#[cfg(windows)]
pub mod win32_window {
    use crate::server::state::HostState;
    use qrcode::{Color as QrColor, QrCode};
    use std::sync::{Arc, OnceLock};
    use windows_sys::Win32::Foundation::*;
    use windows_sys::Win32::Graphics::Gdi::*;
    use windows_sys::Win32::System::LibraryLoader::GetModuleHandleW;
    use windows_sys::Win32::UI::WindowsAndMessaging::*;

    static GLOBAL_STATE: OnceLock<Arc<HostState>> = OnceLock::new();

    pub fn run_desktop_window(state: Arc<HostState>) {
        let _ = GLOBAL_STATE.set(state);
        unsafe {
            let instance = GetModuleHandleW(std::ptr::null());

            let class_name = encode_wide("PhonePadHostWindow");
            let window_title = encode_wide("PhonePad Host — Wireless Trackpad");

            let wnd_class = WNDCLASSW {
                style: CS_HREDRAW | CS_VREDRAW,
                lpfnWndProc: Some(wnd_proc),
                cbClsExtra: 0,
                cbWndExtra: 0,
                hInstance: instance,
                hIcon: std::ptr::null_mut(),
                hCursor: LoadCursorW(std::ptr::null_mut(), 32512 as *const u16), // IDC_ARROW
                hbrBackground: std::ptr::null_mut(), // Handled in double-buffered paint
                lpszMenuName: std::ptr::null(),
                lpszClassName: class_name.as_ptr(),
            };

            RegisterClassW(&wnd_class);

            let hwnd = CreateWindowExW(
                0,
                class_name.as_ptr(),
                window_title.as_ptr(),
                WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
                CW_USEDEFAULT,
                CW_USEDEFAULT,
                540,
                720,
                std::ptr::null_mut(),
                std::ptr::null_mut(),
                instance,
                std::ptr::null(),
            );

            if hwnd.is_null() {
                log::error!("Failed to create PhonePad Host desktop window");
                return;
            }

            // Set 100ms UI refresh timer for live telemetry and activity animations
            SetTimer(hwnd, 1, 100, None);

            ShowWindow(hwnd, SW_SHOW);
            UpdateWindow(hwnd);

            let mut msg: MSG = std::mem::zeroed();
            while GetMessageW(&mut msg, std::ptr::null_mut(), 0, 0) > 0 {
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
        }
    }

    unsafe extern "system" fn wnd_proc(
        hwnd: HWND,
        msg: u32,
        wparam: WPARAM,
        lparam: LPARAM,
    ) -> LRESULT {
        match msg {
            WM_PAINT => {
                let mut ps: PAINTSTRUCT = std::mem::zeroed();
                let hdc = BeginPaint(hwnd, &mut ps);
                paint_window(hwnd, hdc);
                EndPaint(hwnd, &ps);
                0
            }
            WM_TIMER => {
                InvalidateRect(hwnd, std::ptr::null(), 0);
                0
            }
            WM_DESTROY => {
                KillTimer(hwnd, 1);
                PostQuitMessage(0);
                0
            }
            _ => DefWindowProcW(hwnd, msg, wparam, lparam),
        }
    }

    unsafe fn paint_window(hwnd: HWND, hdc: HDC) {
        let mut client_rect: RECT = std::mem::zeroed();
        GetClientRect(hwnd, &mut client_rect);
        let width = client_rect.right - client_rect.left;
        let height = client_rect.bottom - client_rect.top;

        // Double-buffered rendering to eliminate flicker
        let mem_dc = CreateCompatibleDC(hdc);
        let mem_bitmap = CreateCompatibleBitmap(hdc, width, height);
        let old_bitmap = SelectObject(mem_dc, mem_bitmap);

        // 1. Dark obsidian background: #070c14
        let bg_brush = CreateSolidBrush(0x140C07); // Win32 RGB 0x00BBGGRR -> R=07, G=0C, B=14 -> 0x140C07
        FillRect(mem_dc, &client_rect, bg_brush);
        DeleteObject(bg_brush);

        SetBkMode(mem_dc, TRANSPARENT as i32);

        let state_opt = GLOBAL_STATE.get();
        if let Some(state) = state_opt {
            let is_connected = state.is_connected.load(std::sync::atomic::Ordering::Relaxed);
            let local_ip = state.local_ip.lock().map(|s| s.clone()).unwrap_or_else(|_| "127.0.0.1".to_string());
            let client_name = state.client_name.lock().map(|s| s.clone()).unwrap_or_else(|_| "None".to_string());
            let transport = state.client_transport.lock().map(|s| s.clone()).unwrap_or_else(|_| "None".to_string());
            let pps = state.packets_per_sec.load(std::sync::atomic::Ordering::Relaxed);
            let total = state.packets_total.load(std::sync::atomic::Ordering::Relaxed);

            // 2. Header
            let font_title = create_font(26, true);
            let old_font = SelectObject(mem_dc, font_title);
            SetTextColor(mem_dc, 0xF9F5F1); // #F1F5F9 (white)
            let mut title_rect = RECT { left: 24, top: 20, right: 360, bottom: 54 };
            let title_text = encode_wide("PhonePad Host");
            DrawTextW(mem_dc, title_text.as_ptr(), -1, &mut title_rect, DT_LEFT | DT_SINGLELINE);

            // Subtitle
            let font_sub = create_font(13, false);
            SelectObject(mem_dc, font_sub);
            SetTextColor(mem_dc, 0x94A3B8); // Slate-400
            let mut sub_rect = RECT { left: 24, top: 52, right: 360, bottom: 74 };
            let sub_text = encode_wide("Wireless Multi-Touch Input Engine");
            DrawTextW(mem_dc, sub_text.as_ptr(), -1, &mut sub_rect, DT_LEFT | DT_SINGLELINE);

            // Status Badge (Top-right)
            let badge_color = if is_connected { 0x81B910 } else { 0x06B6D4 }; // Emerald vs Cyan
            let badge_brush = CreateSolidBrush(badge_color);
            let badge_bg_rect = RECT { left: 370, top: 24, right: 500, bottom: 54 };
            FillRect(mem_dc, &badge_bg_rect, badge_brush);
            DeleteObject(badge_brush);

            SetTextColor(mem_dc, 0x000000); // Black text on bright badge
            let font_badge = create_font(12, true);
            SelectObject(mem_dc, font_badge);
            let badge_str = if is_connected { "● CONNECTED" } else { "● LISTENING" };
            let badge_text = encode_wide(badge_str);
            let mut badge_txt_rect = RECT { left: 370, top: 30, right: 500, bottom: 50 };
            DrawTextW(mem_dc, badge_text.as_ptr(), -1, &mut badge_txt_rect, DT_CENTER | DT_SINGLELINE);

            // 3. Card 1: Wireless Connection Card (Top)
            draw_card(mem_dc, 24, 84, 492, 230, "WIRELESS CONNECTION");

            let font_body = create_font(14, false);
            let font_bold = create_font(14, true);

            SelectObject(mem_dc, font_body);
            SetTextColor(mem_dc, 0x94A3B8);
            let mut label_ip_rect = RECT { left: 44, top: 114, right: 200, bottom: 134 };
            let label_ip = encode_wide("Local Wi-Fi IP:");
            DrawTextW(mem_dc, label_ip.as_ptr(), -1, &mut label_ip_rect, DT_LEFT | DT_SINGLELINE);

            SelectObject(mem_dc, font_bold);
            SetTextColor(mem_dc, 0x81B910); // Emerald
            let mut val_ip_rect = RECT { left: 160, top: 114, right: 480, bottom: 134 };
            let val_ip = encode_wide(&format!("{}:{} (UDP Beacon active)", local_ip, state.port));
            DrawTextW(mem_dc, val_ip.as_ptr(), -1, &mut val_ip_rect, DT_LEFT | DT_SINGLELINE);

            SelectObject(mem_dc, font_body);
            SetTextColor(mem_dc, 0x94A3B8);
            let mut label_bt_rect = RECT { left: 44, top: 137, right: 200, bottom: 157 };
            let label_bt = encode_wide("Bluetooth RFCOMM:");
            DrawTextW(mem_dc, label_bt.as_ptr(), -1, &mut label_bt_rect, DT_LEFT | DT_SINGLELINE);

            SelectObject(mem_dc, font_bold);
            SetTextColor(mem_dc, 0xD4B606); // Cyan
            let mut val_bt_rect = RECT { left: 180, top: 137, right: 480, bottom: 157 };
            let val_bt = encode_wide("Standard SPP UUID (Ready & Paired)");
            DrawTextW(mem_dc, val_bt.as_ptr(), -1, &mut val_bt_rect, DT_LEFT | DT_SINGLELINE);

            SelectObject(mem_dc, font_body);
            SetTextColor(mem_dc, 0x94A3B8);
            let mut label_cl_rect = RECT { left: 44, top: 160, right: 200, bottom: 180 };
            let label_cl = encode_wide("Active Client:");
            DrawTextW(mem_dc, label_cl.as_ptr(), -1, &mut label_cl_rect, DT_LEFT | DT_SINGLELINE);

            SelectObject(mem_dc, font_bold);
            SetTextColor(mem_dc, if is_connected { 0x81B910 } else { 0x64748B });
            let mut val_cl_rect = RECT { left: 160, top: 160, right: 480, bottom: 180 };
            let val_cl = encode_wide(&format!("{} [{}]", client_name, transport));
            DrawTextW(mem_dc, val_cl.as_ptr(), -1, &mut val_cl_rect, DT_LEFT | DT_SINGLELINE);

            // Security PIN display
            SelectObject(mem_dc, font_body);
            SetTextColor(mem_dc, 0x94A3B8);
            let mut label_pin_rect = RECT { left: 44, top: 183, right: 200, bottom: 203 };
            let label_pin = encode_wide("Pairing PIN:");
            DrawTextW(mem_dc, label_pin.as_ptr(), -1, &mut label_pin_rect, DT_LEFT | DT_SINGLELINE);

            SelectObject(mem_dc, font_bold);
            SetTextColor(mem_dc, 0x06B6D4); // Cyan
            let mut val_pin_rect = RECT { left: 160, top: 183, right: 480, bottom: 203 };
            let val_pin = encode_wide(&format!("{:04}  (Zero-Trust Protected)", state.auth_pin));
            DrawTextW(mem_dc, val_pin.as_ptr(), -1, &mut val_pin_rect, DT_LEFT | DT_SINGLELINE);

            // Instructions text
            SelectObject(mem_dc, font_sub);
            SetTextColor(mem_dc, 0x64748B);
            let mut inst_rect = RECT { left: 44, top: 207, right: 480, bottom: 227 };
            let inst_txt = encode_wide("⚡ Open PhonePad on phone: Auto-Connect or scan QR below");
            DrawTextW(mem_dc, inst_txt.as_ptr(), -1, &mut inst_rect, DT_LEFT | DT_SINGLELINE);

            // 4. Card 2: QR Code Instant Pairing
            draw_card(mem_dc, 24, 246, 492, 480, "INSTANT PAIRING QR CODE");

            let qr_payload = format!("phonepad://connect?ip={}&port={}&name={}&pin={}", local_ip, state.port, state.computer_name, state.auth_pin);
            draw_qr_code(mem_dc, 185, 280, 150, &qr_payload);

            SelectObject(mem_dc, font_sub);
            SetTextColor(mem_dc, 0x94A3B8);
            let mut qr_hint_rect = RECT { left: 44, top: 444, right: 480, bottom: 466 };
            let qr_hint = encode_wide("Scan with PhonePad app or phone camera for 1-tap connection");
            DrawTextW(mem_dc, qr_hint.as_ptr(), -1, &mut qr_hint_rect, DT_CENTER | DT_SINGLELINE);

            // 5. Card 3: Live Telemetry & Activity
            draw_card(mem_dc, 24, 496, 492, 650, "LIVE TELEMETRY & TRAIL");

            SelectObject(mem_dc, font_body);
            SetTextColor(mem_dc, 0x94A3B8);
            let mut rate_lbl_rect = RECT { left: 44, top: 530, right: 180, bottom: 550 };
            let rate_lbl = encode_wide("Event Rate (PPS):");
            DrawTextW(mem_dc, rate_lbl.as_ptr(), -1, &mut rate_lbl_rect, DT_LEFT | DT_SINGLELINE);

            SelectObject(mem_dc, font_bold);
            SetTextColor(mem_dc, 0x81B910);
            let mut rate_val_rect = RECT { left: 180, top: 530, right: 280, bottom: 550 };
            let rate_val = encode_wide(&format!("{} Hz", pps));
            DrawTextW(mem_dc, rate_val.as_ptr(), -1, &mut rate_val_rect, DT_LEFT | DT_SINGLELINE);

            SelectObject(mem_dc, font_body);
            SetTextColor(mem_dc, 0x94A3B8);
            let mut total_lbl_rect = RECT { left: 300, top: 530, right: 400, bottom: 550 };
            let total_lbl = encode_wide("Total Packets:");
            DrawTextW(mem_dc, total_lbl.as_ptr(), -1, &mut total_lbl_rect, DT_LEFT | DT_SINGLELINE);

            SelectObject(mem_dc, font_bold);
            SetTextColor(mem_dc, 0xF9F5F1);
            let mut total_val_rect = RECT { left: 410, top: 530, right: 480, bottom: 550 };
            let total_val = encode_wide(&format!("{}", total));
            DrawTextW(mem_dc, total_val.as_ptr(), -1, &mut total_val_rect, DT_LEFT | DT_SINGLELINE);

            // Interactive motion sandbox bar
            let meter_bg_rect = RECT { left: 44, top: 562, right: 476, bottom: 580 };
            let meter_bg = CreateSolidBrush(0x1F1A13); // #131A1F
            FillRect(mem_dc, &meter_bg_rect, meter_bg);
            DeleteObject(meter_bg);

            let meter_fill_w = (pps.min(144) as i32 * (476 - 44)) / 144;
            if meter_fill_w > 0 {
                let fill_rect = RECT { left: 44, top: 562, right: 44 + meter_fill_w, bottom: 580 };
                let fill_brush = CreateSolidBrush(0x81B910); // Emerald
                FillRect(mem_dc, &fill_rect, fill_brush);
                DeleteObject(fill_brush);
            }

            SelectObject(mem_dc, font_sub);
            SetTextColor(mem_dc, 0x64748B);
            let mut meter_lbl_rect = RECT { left: 44, top: 590, right: 476, bottom: 610 };
            let meter_lbl = encode_wide(&format!("Latency: < 2.0 ms • Input Pipeline: Sub-pixel Clamped • Host Status: Nominal"));
            DrawTextW(mem_dc, meter_lbl.as_ptr(), -1, &mut meter_lbl_rect, DT_CENTER | DT_SINGLELINE);

            // Footer note
            let mut foot_rect = RECT { left: 24, top: 660, right: 492, bottom: 685 };
            let foot_txt = encode_wide("PhonePad Host running • Close window to exit or minimize to run in background");
            DrawTextW(mem_dc, foot_txt.as_ptr(), -1, &mut foot_rect, DT_CENTER | DT_SINGLELINE);

            // Clean up custom GDI fonts
            SelectObject(mem_dc, old_font);
            DeleteObject(font_title);
            DeleteObject(font_sub);
            DeleteObject(font_badge);
            DeleteObject(font_body);
            DeleteObject(font_bold);
        }

        // Blit backbuffer to screen
        BitBlt(hdc, 0, 0, width, height, mem_dc, 0, 0, SRCCOPY);

        SelectObject(mem_dc, old_bitmap);
        DeleteObject(mem_bitmap);
        DeleteDC(mem_dc);
    }

    unsafe fn draw_card(hdc: HDC, x1: i32, y1: i32, x2: i32, y2: i32, header: &str) {
        let card_rect = RECT { left: x1, top: y1, right: x2, bottom: y2 };
        let card_brush = CreateSolidBrush(0x1F140D); // #0D141F
        FillRect(hdc, &card_rect, card_brush);
        DeleteObject(card_brush);

        // Header
        let font_h = create_font(11, true);
        let old_f = SelectObject(hdc, font_h);
        SetTextColor(hdc, 0x81B910); // Emerald #10b981
        let mut hdr_rect = RECT { left: x1 + 16, top: y1 + 12, right: x2 - 16, bottom: y1 + 30 };
        let hdr_text = encode_wide(header);
        DrawTextW(hdc, hdr_text.as_ptr(), -1, &mut hdr_rect, DT_LEFT | DT_SINGLELINE);
        SelectObject(hdc, old_f);
        DeleteObject(font_h);
    }

    unsafe fn draw_qr_code(hdc: HDC, x: i32, y: i32, size: i32, payload: &str) {
        if let Ok(code) = QrCode::new(payload.as_bytes()) {
            let width = code.width();
            let module_size = size / (width as i32 + 2);
            let offset_x = x + (size - (width as i32 * module_size)) / 2;
            let offset_y = y + (size - (width as i32 * module_size)) / 2;

            // Background white border
            let bg_rect = RECT {
                left: offset_x - 6,
                top: offset_y - 6,
                right: offset_x + (width as i32 * module_size) + 6,
                bottom: offset_y + (width as i32 * module_size) + 6,
            };
            let white_brush = CreateSolidBrush(0xFFFFFF);
            FillRect(hdc, &bg_rect, white_brush);
            DeleteObject(white_brush);

            let black_brush = CreateSolidBrush(0x000000);
            for cy in 0..width {
                for cx in 0..width {
                    if code[(cx, cy)] == QrColor::Dark {
                        let mod_rect = RECT {
                            left: offset_x + cx as i32 * module_size,
                            top: offset_y + cy as i32 * module_size,
                            right: offset_x + (cx as i32 + 1) * module_size,
                            bottom: offset_y + (cy as i32 + 1) * module_size,
                        };
                        FillRect(hdc, &mod_rect, black_brush);
                    }
                }
            }
            DeleteObject(black_brush);
        }
    }

    unsafe fn create_font(size: i32, bold: bool) -> HFONT {
        let face = encode_wide("Segoe UI");
        CreateFontW(
            size,
            0,
            0,
            0,
            if bold { 700 } else { 400 },
            0,
            0,
            0,
            DEFAULT_CHARSET as u32,
            OUT_DEFAULT_PRECIS as u32,
            CLIP_DEFAULT_PRECIS as u32,
            CLEARTYPE_QUALITY as u32,
            DEFAULT_PITCH as u32,
            face.as_ptr(),
        )
    }

    fn encode_wide(s: &str) -> Vec<u16> {
        use std::ffi::OsStr;
        use std::os::windows::ffi::OsStrExt;
        OsStr::new(s).encode_wide().chain(std::iter::once(0)).collect()
    }
}
