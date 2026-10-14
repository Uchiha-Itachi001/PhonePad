import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/network/discovery_client.dart';
import 'core/network/tcp_transport.dart';
import 'core/network/transport.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme_controller.dart';
import 'features/connection/presentation/connection_hub.dart';
import 'features/modes/models/surface_mode.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/touch/presentation/touch_surface.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock permanently to landscape orientation for desktop trackpad & full keyboard experience
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: PhonePadColors.backgroundPrimary,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const PhonePadApp());
}

class PhonePadApp extends StatefulWidget {
  const PhonePadApp({super.key});

  @override
  State<PhonePadApp> createState() => _PhonePadAppState();
}

class _PhonePadAppState extends State<PhonePadApp> {
  final TcpTransport _tcpTransport = TcpTransport();
  final DiscoveryClient _discoveryClient = DiscoveryClient();

  String _destination = 'Auto-Scanning for PC...';
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();

    // Start background Wi-Fi discovery probe
    _initAutoDiscovery();
  }

  void _initAutoDiscovery() {
    _discoveryClient.startDiscovery();

    // Listen for discovered PC hosts and auto-connect if disconnected
    _discoveryClient.hostsStream.listen((hosts) {
      if (mounted &&
          hosts.isNotEmpty &&
          _tcpTransport.status == ConnectionStatus.disconnected) {
        final firstHost = hosts.first;
        _connectHost(firstHost.destination, firstHost.name, pin: firstHost.pin);
      }
    });
  }

  Future<void> _connectHost(String address, String displayName, {int pin = 0}) async {
    try {
      await _tcpTransport.disconnect();
      _tcpTransport.setPin(pin);
      setState(() {
        _destination = displayName;
      });
      await _tcpTransport.connect(address);
    } catch (_) {
      // Handled via transport status stream
    }
  }

  void _showConnectionModal(BuildContext modalContext) {
    showModalBottomSheet(
      context: modalContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ConnectionHubModal(
          discoveryClient: _discoveryClient,
          currentDestination: _destination,
          onConnect: (address, name, pin) {
            _connectHost(address, name, pin: pin);
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _discoveryClient.dispose();
    _tcpTransport.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance.theme;
        return MaterialApp(
          title: 'PhonePad',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: theme.isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: theme.backgroundPrimary,
            colorScheme: ColorScheme(
              brightness: theme.isDark ? Brightness.dark : Brightness.light,
              primary: theme.accentPrimary,
              onPrimary: theme.isDark ? Colors.black : Colors.white,
              secondary: theme.accentSecondary,
              onSecondary: Colors.white,
              error: const Color(0xFFEF4444),
              onError: Colors.white,
              surface: theme.backgroundSecondary,
              onSurface: theme.textPrimary,
            ),
          ),
          home: Builder(
            builder: (innerContext) {
              if (_showSplash) {
                return SplashScreen(
                  onFinish: () {
                    if (mounted) {
                      setState(() {
                        _showSplash = false;
                      });
                    }
                  },
                );
              }
              return TouchSurface(
                transport: _tcpTransport,
                destination: _destination,
                onSettingsTap: () => _showConnectionModal(innerContext),
                initialMode: SurfaceMode.remote,
              );
            },
          ),
        );
      },
    );
  }
}
