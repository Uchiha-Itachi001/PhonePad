//! Security verification utilities: IP subnet filtering, origin validation, and attack defense.

use std::net::IpAddr;

/// Validates that an IP address belongs strictly to a private local area network (LAN)
/// or loopback interface, completely barring connections from public WAN / external internet routes.
pub fn is_trusted_private_ip(ip: &IpAddr) -> bool {
    match ip {
        IpAddr::V4(ipv4) => {
            // Loopback: 127.0.0.0/8
            if ipv4.is_loopback() {
                return true;
            }
            // Link-local (APIPA): 169.254.0.0/16
            if ipv4.is_link_local() {
                return true;
            }
            // RFC 1918 Private subnets:
            // 10.0.0.0/8
            // 172.16.0.0/12
            // 192.168.0.0/16
            let octets = ipv4.octets();
            match octets[0] {
                10 => true,
                172 if (16..=31).contains(&octets[1]) => true,
                192 if octets[1] == 168 => true,
                _ => false,
            }
        }
        IpAddr::V6(ipv6) => {
            // Loopback: ::1
            if ipv6.is_loopback() {
                return true;
            }
            // Unique Local Address (ULA): fc00::/7
            let segments = ipv6.segments();
            if (segments[0] & 0xfe00) == 0xfc00 {
                return true;
            }
            // Link-local unicast: fe80::/10
            if (segments[0] & 0xffc0) == 0xfe80 {
                return true;
            }
            false
        }
    }
}

/// Checks if client IP is on the same local subnet as the host's active network interface.
pub fn is_same_subnet(client_ip: &IpAddr, host_ip_str: &str) -> bool {
    if client_ip.is_loopback() {
        return true;
    }
    let host_ip: IpAddr = match host_ip_str.trim().parse() {
        Ok(ip) => ip,
        Err(_) => return false,
    };
    if host_ip.is_loopback() {
        return client_ip.is_loopback();
    }

    match (client_ip, host_ip) {
        (IpAddr::V4(c), IpAddr::V4(h)) => {
            let c_oct = c.octets();
            let h_oct = h.octets();
            // Match /24 subnet (e.g. 192.168.1.X or 10.0.0.X) or /16 for large LANs
            if c_oct[0] == h_oct[0] && c_oct[1] == h_oct[1] {
                if c_oct[0] == 192 && c_oct[1] == 168 {
                    c_oct[2] == h_oct[2]
                } else {
                    true
                }
            } else {
                false
            }
        }
        (IpAddr::V6(c), IpAddr::V6(h)) => {
            // Match first 64 bits (/64 subnet prefix)
            let c_seg = c.segments();
            let h_seg = h.segments();
            c_seg[..4] == h_seg[..4]
        }
        _ => false,
    }
}

/// Validates that an HTTP Origin or Host header belongs strictly to trusted local origins.
pub fn is_trusted_http_origin(origin_header: Option<&str>) -> bool {
    match origin_header {
        None => true, // Native application / internal same-origin request
        Some(origin) => {
            let o = origin.trim().to_lowercase();
            o == "http://localhost:1420"
                || o == "http://127.0.0.1:1420"
                || o == "https://localhost:1420"
                || o == "tauri://localhost"
                || o == "http://tauri.localhost"
                || o == "https://tauri.localhost"
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_trusted_private_ip_allows_private_and_loopback() {
        assert!(is_trusted_private_ip(&"127.0.0.1".parse().unwrap()));
        assert!(is_trusted_private_ip(&"192.168.1.45".parse().unwrap()));
        assert!(is_trusted_private_ip(&"10.0.5.21".parse().unwrap()));
        assert!(is_trusted_private_ip(&"172.20.10.2".parse().unwrap()));
        assert!(is_trusted_private_ip(&"169.254.12.34".parse().unwrap()));
        assert!(is_trusted_private_ip(&"::1".parse().unwrap()));
    }

    #[test]
    fn test_trusted_private_ip_blocks_public_wan() {
        assert!(!is_trusted_private_ip(&"8.8.8.8".parse().unwrap()));
        assert!(!is_trusted_private_ip(&"1.1.1.1".parse().unwrap()));
        assert!(!is_trusted_private_ip(&"142.250.190.46".parse().unwrap()));
        assert!(!is_trusted_private_ip(&"203.0.113.1".parse().unwrap()));
    }

    #[test]
    fn test_same_subnet_matching() {
        assert!(is_same_subnet(&"192.168.1.100".parse().unwrap(), "192.168.1.50"));
        assert!(!is_same_subnet(&"192.168.2.100".parse().unwrap(), "192.168.1.50"));
        assert!(is_same_subnet(&"127.0.0.1".parse().unwrap(), "127.0.0.1"));
    }

    #[test]
    fn test_http_origin_validation() {
        assert!(is_trusted_http_origin(None));
        assert!(is_trusted_http_origin(Some("http://localhost:1420")));
        assert!(is_trusted_http_origin(Some("tauri://localhost")));
        assert!(!is_trusted_http_origin(Some("https://malicious-website.com")));
        assert!(!is_trusted_http_origin(Some("http://evil-attacker.io:8080")));
    }
}
