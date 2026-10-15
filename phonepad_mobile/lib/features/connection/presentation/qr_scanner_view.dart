import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/theme_controller.dart';

/// Parsed connection data from PhonePad Host QR code.
class QrPairingData {
  final String ip;
  final int port;
  final String name;
  final int pin;

  const QrPairingData({
    required this.ip,
    required this.port,
    required this.name,
    required this.pin,
  });

  String get destination => '$ip:$port';

  static QrPairingData? parse(String raw) {
    try {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;

      // Format 1: phonepad://connect?ip=192.168.1.15&port=4242&name=Desktop-PC&pin=4242
      final uri = Uri.tryParse(trimmed);
      if (uri != null && (uri.scheme == 'phonepad' || uri.host == 'connect')) {
        final ip = uri.queryParameters['ip'] ?? '';
        final port = int.tryParse(uri.queryParameters['port'] ?? '4242') ?? 4242;
        final name = uri.queryParameters['name'] ?? 'Desktop Host';
        final pin = int.tryParse(uri.queryParameters['pin'] ?? '0') ?? 0;
        if (ip.isNotEmpty) {
          return QrPairingData(ip: ip, port: port, name: name, pin: pin);
        }
      }

      // Format 2: raw ip:port or ip:port:pin
      if (trimmed.contains(':')) {
        final parts = trimmed.split(':');
        final ip = parts[0].trim();
        final port = int.tryParse(parts[1].trim()) ?? 4242;
        final pin = parts.length > 2 ? (int.tryParse(parts[2].trim()) ?? 0) : 0;
        if (ip.isNotEmpty) {
          return QrPairingData(ip: ip, port: port, name: 'Scanned Host', pin: pin);
        }
      }

      // Format 3: raw IP only
      if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(trimmed)) {
        return QrPairingData(ip: trimmed, port: 4242, name: 'Scanned Host', pin: 0);
      }
    } catch (_) {}
    return null;
  }
}

/// Interactive QR code scanner view with aiming reticle, torch toggle, and camera flip.
class QrScannerView extends StatefulWidget {
  final Function(QrPairingData data) onScanned;
  final VoidCallback? onCancel;

  const QrScannerView({
    super.key,
    required this.onScanned,
    this.onCancel,
  });

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  bool _hasScanned = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        final pairing = QrPairingData.parse(rawValue);
        if (pairing != null) {
          _hasScanned = true;
          HapticFeedback.heavyImpact();
          widget.onScanned(pairing);
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.theme;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                'Camera Access Required',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _controller.start();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Live Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Camera error: ${error.errorCode}',
                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),

          // Darkened Vignette Overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),

          // Central Aiming Viewfinder Box
          LayoutBuilder(
            builder: (context, constraints) {
              final boxSize = isLandscape
                  ? (constraints.maxHeight * 0.7).clamp(140.0, 220.0)
                  : (constraints.maxWidth * 0.65).clamp(160.0, 260.0);

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Cutout Viewfinder Border
                  Container(
                    width: boxSize,
                    height: boxSize,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.accentPrimary.withValues(alpha: 0.8),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accentPrimary.withValues(alpha: 0.25),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),

                  // Animated Scanning Laser Line
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, _) {
                      final topOffset = (_animController.value * (boxSize - 12));
                      return Positioned(
                        top: (constraints.maxHeight - boxSize) / 2 + topOffset,
                        child: Container(
                          width: boxSize - 16,
                          height: 2.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                theme.accentPrimary,
                                Colors.white,
                                theme.accentPrimary,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.accentPrimary,
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),

          // Top Header Bar: Controls (Torch & Switch Camera)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Torch Flash Toggle Button
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _controller,
                  builder: (context, state, _) {
                    final isTorchOn = state.torchState == TorchState.on;
                    return IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: isTorchOn
                            ? Colors.amber.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.5),
                        foregroundColor: isTorchOn ? Colors.amber : Colors.white,
                      ),
                      onPressed: () => _controller.toggleTorch(),
                      icon: Icon(
                        isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        size: 20,
                      ),
                      tooltip: 'Toggle Flashlight',
                    );
                  },
                ),

                // Instruction Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 14, color: theme.accentPrimary),
                      const SizedBox(width: 6),
                      const Text(
                        'Align QR Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Camera Switch Button
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _controller.switchCamera(),
                  icon: const Icon(Icons.flip_camera_ios_rounded, size: 20),
                  tooltip: 'Switch Camera',
                ),
              ],
            ),
          ),

          // Bottom Helper Tip
          Positioned(
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Point camera at the Host desktop QR code',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
