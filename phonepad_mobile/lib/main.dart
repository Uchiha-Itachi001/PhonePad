import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/network/bluetooth_transport.dart';
import 'core/network/discovery_client.dart';
import 'core/network/tcp_transport.dart';
import 'core/network/transport.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme_controller.dart';
import 'features/connection/presentation/connection_hub.dart';
import 'features/touch/presentation/touch_surface.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Support both portrait and landscape orientations for adaptive tablet/desktop layout
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
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
  final BluetoothTransport _btTransport = BluetoothTransport();
  final TcpTransport _tcpTransport = TcpTransport();
  final DiscoveryClient _discoveryClient = DiscoveryClient();

  late ITransport _activeTransport;
  bool _useBluetooth = false;
  String _destination = 'Auto-Scanning for PC...';

  @override
  void initState() {
    super.initState();
    _activeTransport = _tcpTransport;

    // Start background Wi-Fi discovery probe
    _initAutoDiscovery();
  }

  void _initAutoDiscovery() {
    _discoveryClient.startDiscovery();

    // Listen for discovered PC hosts and auto-connect if disconnected
    _discoveryClient.hostsStream.listen((hosts) {
      if (mounted &&
          hosts.isNotEmpty &&
          _activeTransport.status == ConnectionStatus.disconnected &&
          !_useBluetooth) {
        final firstHost = hosts.first;
        _connectHost(firstHost.destination, false, firstHost.name, pin: firstHost.pin);
      }
    });
  }

  Future<void> _connectHost(String address, bool isBluetooth, String displayName, {int pin = 0}) async {
    try {
      await _activeTransport.disconnect();
      if (!isBluetooth) {
        _tcpTransport.setPin(pin);
      }
      setState(() {
        _useBluetooth = isBluetooth;
        _activeTransport = isBluetooth ? _btTransport : _tcpTransport;
        _destination = displayName;
      });
      await _activeTransport.connect(address);
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
          bluetoothTransport: _btTransport,
          currentDestination: _destination,
          isBluetooth: _useBluetooth,
          onConnect: (address, isBt, name, pin) {
            _connectHost(address, isBt, name, pin: pin);
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _discoveryClient.dispose();
    _activeTransport.disconnect();
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
            builder: (innerContext) => TouchSurface(
              transport: _activeTransport,
              destination: _destination,
              onSettingsTap: () => _showConnectionModal(innerContext),
            ),
          ),
        );
      },
    );
  }
}
