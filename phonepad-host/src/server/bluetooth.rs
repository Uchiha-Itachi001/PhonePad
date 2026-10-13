//! Native Windows Bluetooth RFCOMM listener (Serial Port Profile - SPP).

#[cfg(windows)]
pub mod windows_bth {
    use crate::gesture::{BallisticsEngine, GestureFilter, GestureFsm};
    use crate::input::create_default_injector;
    use crate::protocol::PACKET_SIZE;
    use crate::server::connection::SessionHandler;
    use std::mem::size_of;
    use std::time::Duration;
    use windows_sys::core::GUID;
    use windows_sys::Win32::Networking::WinSock::*;

    pub const AF_BTH: u16 = 32;
    pub const BTHPROTO_RFCOMM: i32 = 3;
    pub const BT_PORT_ANY: u32 = u32::MAX; // ((ULONG)-1) in ws2bth.h

    pub const NS_BTH: u32 = 16;
    pub const RNRSERVICE_REGISTER: i32 = 0;
    pub const RNRSERVICE_DELETE: i32 = 2;

    /// Standard Bluetooth Serial Port Profile (SPP) UUID: 00001101-0000-1000-8000-00805F9B34FB
    pub const SPP_GUID: GUID = GUID {
        data1: 0x00001101,
        data2: 0x0000,
        data3: 0x1000,
        data4: [0x80, 0x00, 0x00, 0x80, 0x5F, 0x9B, 0x34, 0xFB],
    };

    #[repr(C, packed(1))]
    #[derive(Clone, Copy)]
    #[allow(non_snake_case)]
    pub struct SOCKADDR_BTH {
        pub addressFamily: u16,
        pub btAddr: u64,
        pub serviceClassId: GUID,
        pub port: u32,
    }

    #[repr(C)]
    #[allow(non_snake_case)]
    pub struct SOCKET_ADDRESS {
        pub lpSockaddr: *mut SOCKADDR,
        pub iSockaddrLength: i32,
    }

    #[repr(C)]
    #[allow(non_snake_case)]
    pub struct CSADDR_INFO {
        pub LocalAddr: SOCKET_ADDRESS,
        pub RemoteAddr: SOCKET_ADDRESS,
        pub iSocketType: i32,
        pub iProtocol: i32,
    }

    #[repr(C)]
    #[allow(non_snake_case)]
    pub struct WSAQUERYSETW {
        pub dwSize: u32,
        pub lpszServiceInstanceName: *mut u16,
        pub lpServiceClassId: *mut GUID,
        pub lpVersion: *mut std::ffi::c_void,
        pub lpszComment: *mut u16,
        pub dwNameSpace: u32,
        pub lpNSProviderId: *mut GUID,
        pub lpszContext: *mut u16,
        pub dwNumberOfProtocols: u32,
        pub lpafpProtocols: *mut std::ffi::c_void,
        pub lpszQueryString: *mut u16,
        pub dwNumberOfCsAddrs: u32,
        pub lpcsaBuffer: *mut CSADDR_INFO,
        pub dwOutputFlags: u32,
        pub lpBlob: *mut std::ffi::c_void,
    }

    unsafe extern "system" {
        pub fn WSASetServiceW(
            lpqsreginfo: *const WSAQUERYSETW,
            essoperation: i32,
            dwcontrolflags: u32,
        ) -> i32;
    }

    /// Runs a persistent Bluetooth RFCOMM SPP server for paired mobile clients.
    pub fn run_bluetooth_rfcomm_server(_idle_timeout: Duration) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unsafe {
            let mut wsa_data: WSADATA = std::mem::zeroed();
            let res = WSAStartup(0x0202, &mut wsa_data);
            if res != 0 {
                return Err(format!("WSAStartup failed with error: {}", res).into());
            }

            let s = socket(AF_BTH as i32, SOCK_STREAM as i32, BTHPROTO_RFCOMM);
            if s == INVALID_SOCKET {
                let err = WSAGetLastError();
                return Err(format!("Bluetooth socket() failed. Is Bluetooth turned on? (WSA error: {})", err).into());
            }

            let sa = SOCKADDR_BTH {
                addressFamily: AF_BTH,
                btAddr: 0,
                serviceClassId: GUID { data1: 0, data2: 0, data3: 0, data4: [0; 8] },
                port: BT_PORT_ANY,
            };

            let bind_res = bind(s, &sa as *const _ as *const SOCKADDR, size_of::<SOCKADDR_BTH>() as i32);
            if bind_res != 0 {
                let err = WSAGetLastError();
                closesocket(s);
                return Err(format!("Bluetooth bind() failed with WSA error: {}", err).into());
            }

            // Retrieve dynamically allocated RFCOMM channel
            let mut bound_sa: SOCKADDR_BTH = std::mem::zeroed();
            let mut bound_len = size_of::<SOCKADDR_BTH>() as i32;
            let getsockname_res = getsockname(s, &mut bound_sa as *mut _ as *mut SOCKADDR, &mut bound_len);
            let channel = if getsockname_res == 0 { bound_sa.port } else { 1 };

            // Register SDP Service Record so Android SDP queries find PhonePad
            let mut service_name: Vec<u16> = "PhonePad Host\0".encode_utf16().collect();
            let mut cs_addr = CSADDR_INFO {
                LocalAddr: SOCKET_ADDRESS {
                    lpSockaddr: &mut bound_sa as *mut _ as *mut SOCKADDR,
                    iSockaddrLength: size_of::<SOCKADDR_BTH>() as i32,
                },
                RemoteAddr: SOCKET_ADDRESS {
                    lpSockaddr: &mut bound_sa as *mut _ as *mut SOCKADDR,
                    iSockaddrLength: size_of::<SOCKADDR_BTH>() as i32,
                },
                iSocketType: SOCK_STREAM as i32,
                iProtocol: BTHPROTO_RFCOMM,
            };

            let mut spp_guid = SPP_GUID;
            let qs = WSAQUERYSETW {
                dwSize: size_of::<WSAQUERYSETW>() as u32,
                lpszServiceInstanceName: service_name.as_mut_ptr(),
                lpServiceClassId: &mut spp_guid,
                lpVersion: std::ptr::null_mut(),
                lpszComment: std::ptr::null_mut(),
                dwNameSpace: NS_BTH,
                lpNSProviderId: std::ptr::null_mut(),
                lpszContext: std::ptr::null_mut(),
                dwNumberOfProtocols: 0,
                lpafpProtocols: std::ptr::null_mut(),
                lpszQueryString: std::ptr::null_mut(),
                dwNumberOfCsAddrs: 1,
                lpcsaBuffer: &mut cs_addr,
                dwOutputFlags: 0,
                lpBlob: std::ptr::null_mut(),
            };

            let sdp_res = WSASetServiceW(&qs, RNRSERVICE_REGISTER, 0);
            if sdp_res != 0 {
                let err = WSAGetLastError();
                log::warn!("Bluetooth SDP advertisement notice (WSA: {}). Channel {} is active.", err, channel);
            } else {
                log::info!("✨ Bluetooth SDP Service Record published (Channel: {}, SPP UUID: 00001101-0000-1000-8000-00805F9B34FB)", channel);
            }

            let listen_res = listen(s, 1);
            if listen_res != 0 {
                let err = WSAGetLastError();
                closesocket(s);
                return Err(format!("Bluetooth listen() failed with WSA error: {}", err).into());
            }

            log::info!("🔵 PhonePad Bluetooth RFCOMM Listener active on Channel {} (SPP UUID: 00001101-0000-1000-8000-00805F9B34FB)", channel);
            log::info!("Pair your Android phone via PC Windows Bluetooth Settings, then open PhonePad.");

            loop {
                let mut client_sa: SOCKADDR_BTH = std::mem::zeroed();
                let mut sa_len = size_of::<SOCKADDR_BTH>() as i32;

                log::info!("Waiting for Bluetooth incoming connection...");
                let client_sock = accept(s, &mut client_sa as *const _ as *mut SOCKADDR, &mut sa_len);
                if client_sock == INVALID_SOCKET {
                    let err = WSAGetLastError();
                    log::warn!("Bluetooth accept error: {}", err);
                    continue;
                }

                let remote_addr = client_sa.btAddr;
                log::info!("📱 Bluetooth client connected (Remote Radio: {:012X})", remote_addr);

                let injector = create_default_injector();
                let ballistics = BallisticsEngine::default();
                let filter = GestureFilter::default();
                let fsm = GestureFsm::default();
                let mut session = SessionHandler::new(injector, ballistics, filter, fsm);

                // Read loop for Bluetooth RFCOMM stream
                let mut buf = [0u8; PACKET_SIZE];
                let mut first_frame = true;

                loop {
                    // Blocking read for PACKET_SIZE bytes
                    let mut bytes_read = 0;
                    let mut read_failed = false;

                    while bytes_read < PACKET_SIZE {
                        let n = recv(
                            client_sock,
                            buf[bytes_read..].as_mut_ptr() as *mut _,
                            (PACKET_SIZE - bytes_read) as i32,
                            0,
                        );

                        if n <= 0 {
                            read_failed = true;
                            break;
                        }
                        bytes_read += n as usize;
                    }

                    if read_failed {
                        log::info!("Bluetooth connection closed or dropped.");
                        break;
                    }

                    if first_frame && buf[0] == crate::protocol::HANDSHAKE_MAGIC {
                        first_frame = false;
                        let mut extra = [0u8; 2];
                        let mut extra_read = 0;
                        while extra_read < 2 {
                            let n = recv(client_sock, extra[extra_read..].as_mut_ptr() as *mut _, (2 - extra_read) as i32, 0);
                            if n <= 0 { break; }
                            extra_read += n as usize;
                        }
                        let mut handshake_buf = [0u8; crate::protocol::HANDSHAKE_SIZE];
                        handshake_buf[..6].copy_from_slice(&buf);
                        handshake_buf[6..8].copy_from_slice(&extra);
                        if let Ok(hs) = crate::protocol::HandshakeFrame::from_bytes(&handshake_buf) {
                            log::info!("✨ Bluetooth handshake verified: device_id=0x{:08X}, type={:?}", hs.device_id, hs.device_type);
                        } else {
                            log::warn!("Security violation: Invalid Bluetooth handshake - closing connection.");
                            break;
                        }
                        continue;
                    }

                    first_frame = false;
                    let packet = crate::protocol::Packet::from_bytes(&buf);
                    session.handle_packet(packet);
                }

                closesocket(client_sock);
                log::info!("Bluetooth session ended (Packets processed: {})", session.packets_received);
            }
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn test_bth_socket_bind_and_sdp() {
            unsafe {
                let mut wsa_data: WSADATA = std::mem::zeroed();
                let res = WSAStartup(0x0202, &mut wsa_data);
                assert_eq!(res, 0);

                let s = socket(AF_BTH as i32, SOCK_STREAM as i32, BTHPROTO_RFCOMM);
                assert_ne!(s, INVALID_SOCKET);

                let sa = SOCKADDR_BTH {
                    addressFamily: AF_BTH,
                    btAddr: 0,
                    serviceClassId: GUID { data1: 0, data2: 0, data3: 0, data4: [0; 8] },
                    port: BT_PORT_ANY,
                };

                let bind_res = bind(s, &sa as *const _ as *const SOCKADDR, size_of::<SOCKADDR_BTH>() as i32);
                assert_eq!(bind_res, 0, "bind must succeed with packed 30-byte SOCKADDR_BTH");

                let mut bound_sa: SOCKADDR_BTH = std::mem::zeroed();
                let mut bound_len = size_of::<SOCKADDR_BTH>() as i32;
                let getsockname_res = getsockname(s, &mut bound_sa as *mut _ as *mut SOCKADDR, &mut bound_len);
                assert_eq!(getsockname_res, 0);
                assert!(bound_sa.port >= 1 && bound_sa.port <= 30);

                closesocket(s);
            }
        }
    }
}
