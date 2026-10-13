import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/bluetooth_transport.dart';
import '../../../core/network/discovery_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_controller.dart';

/// Modal dialog for discovering and selecting PhonePad PC hosts via Wi-Fi or Bluetooth.
class ConnectionHubModal extends StatefulWidget {
  final DiscoveryClient discoveryClient;
  final BluetoothTransport bluetoothTransport;
  final String currentDestination;
  final bool isBluetooth;
  final Function(String address, bool isBluetooth, String displayName, int pin) onConnect;

  const ConnectionHubModal({
    super.key,
    required this.discoveryClient,
    required this.bluetoothTransport,
    required this.currentDestination,
    required this.isBluetooth,
    required this.onConnect,
  });

  @override
  State<ConnectionHubModal> createState() => _ConnectionHubModalState();
}

class _ConnectionHubModalState extends State<ConnectionHubModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _ipController =
      TextEditingController(text: '192.168.1.15:4242');
  final TextEditingController _pinController =
      TextEditingController();

  List<DiscoveredHost> _wifiHosts = [];
  List<BluetoothDeviceInfo> _btDevices = [];
  bool _isLoadingBt = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: widget.isBluetooth ? 1 : 0);
    _wifiHosts = widget.discoveryClient.currentHosts;

    widget.discoveryClient.startDiscovery();
    widget.discoveryClient.hostsStream.listen((hosts) {
      if (mounted) {
        setState(() {
          _wifiHosts = hosts;
        });
      }
    });

    _loadBluetoothDevices();
  }

  Future<void> _loadBluetoothDevices() async {
    setState(() => _isLoadingBt = true);
    try {
      await widget.bluetoothTransport.requestPermissions();
      final devices = await widget.bluetoothTransport.getPairedDevices();
      if (mounted) {
        setState(() {
          _btDevices = devices;
          _isLoadingBt = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBt = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance.theme;

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: theme.backgroundSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: theme.borderSubtle)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONTROL CENTER',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Connections • Themes • Gestures',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.borderSubtle),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: theme.accentPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.accentPrimary.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  labelColor: theme.accentPrimary,
                  unselectedLabelColor: theme.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.wifi_rounded, size: 16),
                      text: 'Wi-Fi Auto',
                    ),
                    Tab(
                      icon: Icon(Icons.bluetooth_rounded, size: 16),
                      text: 'Bluetooth',
                    ),
                    Tab(
                      icon: Icon(Icons.lan_rounded, size: 16),
                      text: 'Manual IP',
                    ),
                    Tab(
                      icon: Icon(Icons.palette_rounded, size: 16),
                      text: 'Themes & Grid',
                    ),
                    Tab(
                      icon: Icon(Icons.tune_rounded, size: 16),
                      text: 'Gestures',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildWifiAutoTab(),
                    _buildBluetoothTab(),
                    _buildManualIpTab(),
                    _buildThemesAndGridTab(),
                    _buildGesturesTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWifiAutoTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DISCOVERED PC HOSTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: PhonePadColors.textSecondary,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  widget.discoveryClient.sendDiscoveryProbe();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16, color: PhonePadColors.accentEmerald),
                label: const Text('Scan Again', style: TextStyle(color: PhonePadColors.accentEmerald, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_wifiHosts.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: PhonePadColors.accentEmerald.withValues(alpha: 0.08),
                        border: Border.all(
                          color: PhonePadColors.accentEmerald.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.wifi_tethering_rounded,
                        color: PhonePadColors.accentEmerald,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Broadcasting UDP Beacon...',
                      style: TextStyle(
                        color: PhonePadColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Make sure PhonePad Host is running on your PC\nand both devices are on the same Wi-Fi or Hotspot.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PhonePadColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _wifiHosts.length,
                itemBuilder: (context, index) {
                  final host = _wifiHosts[index];
                  final isCurrent = widget.currentDestination == host.destination && !widget.isBluetooth;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? PhonePadColors.accentEmerald.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent
                            ? PhonePadColors.accentEmerald.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: PhonePadColors.accentEmerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.laptop_chromebook_rounded, color: PhonePadColors.accentEmerald),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                host.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: PhonePadColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${host.destination} • Latency < 2ms',
                                style: const TextStyle(fontSize: 12, color: PhonePadColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PhonePadColors.accentEmerald,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onConnect(host.destination, false, host.name, host.pin);
                          },
                          child: Text(
                            isCurrent ? 'Active' : 'Connect ⚡',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBluetoothTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PAIRED BLUETOOTH PCs',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: PhonePadColors.textSecondary,
                ),
              ),
              TextButton.icon(
                onPressed: _loadBluetoothDevices,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: PhonePadColors.accentCyan),
                label: const Text('Refresh', style: TextStyle(color: PhonePadColors.accentCyan, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isLoadingBt)
            const Expanded(child: Center(child: CircularProgressIndicator(color: PhonePadColors.accentCyan)))
          else if (_btDevices.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bluetooth_searching_rounded, size: 40, color: PhonePadColors.textSecondary),
                      const SizedBox(height: 12),
                      const Text(
                        'No Paired Bluetooth PCs',
                        style: TextStyle(fontWeight: FontWeight.bold, color: PhonePadColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pair your phone with your laptop in Windows Bluetooth Settings first, then tap Refresh.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: PhonePadColors.textSecondary.withValues(alpha: 0.8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _btDevices.length,
                itemBuilder: (context, index) {
                  final dev = _btDevices[index];
                  final isCurrent = widget.currentDestination == dev.name && widget.isBluetooth;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? PhonePadColors.accentCyan.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent
                            ? PhonePadColors.accentCyan.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: PhonePadColors.accentCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.bluetooth_connected_rounded, color: PhonePadColors.accentCyan),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dev.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: PhonePadColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dev.address,
                                style: const TextStyle(fontSize: 12, color: PhonePadColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PhonePadColors.accentCyan,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onConnect(dev.address, true, dev.name, 0);
                          },
                          child: Text(
                            isCurrent ? 'Active' : 'Connect',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildManualIpTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HOST IP ADDRESS & PORT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: PhonePadColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the IP and Security PIN displayed on the PhonePad Host desktop window.',
            style: TextStyle(fontSize: 12, color: PhonePadColors.textSecondary.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ipController,
            style: const TextStyle(color: PhonePadColors.textPrimary, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              prefixIcon: const Icon(Icons.lan_rounded, color: PhonePadColors.accentEmerald),
              hintText: '192.168.1.15:4242',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: PhonePadColors.accentEmerald, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: PhonePadColors.textPrimary, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              prefixIcon: const Icon(Icons.password_rounded, color: PhonePadColors.accentEmerald),
              hintText: 'Security PIN (shown on PC)',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: PhonePadColors.accentEmerald, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    _ipController.text = '127.0.0.1:4242';
                  },
                  child: const Text('Use ADB Localhost', style: TextStyle(color: PhonePadColors.textPrimary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PhonePadColors.accentEmerald,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final target = _ipController.text.trim();
                    final pin = int.tryParse(_pinController.text.trim()) ?? 0;
                    if (target.isNotEmpty) {
                      Navigator.pop(context);
                      widget.onConnect(target, false, 'Wi-Fi: $target', pin);
                    }
                  },
                  child: const Text('Connect via IP', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemesAndGridTab() {
    final currentTheme = ThemeController.instance.theme;
    final currentDensity = ThemeController.instance.dotDensity;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Text(
          'COLOR PALETTE THEMES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: currentTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),

        ...PhonePadThemeData.allThemes.map((t) {
          final isSelected = t.id == currentTheme.id;
          return GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              ThemeController.instance.setTheme(t.id);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? t.accentPrimary.withValues(alpha: 0.12)
                    : currentTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? t.accentPrimary
                      : currentTheme.borderSubtle,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  // Palette Preview Circles
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.accentPrimary,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.accentSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.surfaceCard,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: currentTheme.textPrimary,
                          ),
                        ),
                        Text(
                          t.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: currentTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: t.accentPrimary,
                      size: 20,
                    ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 16),
        Text(
          'TOUCHPAD DOT MATRIX DENSITY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: currentTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),

        ...DotMatrixDensity.values.map((d) {
          final isSelected = d == currentDensity;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ThemeController.instance.setDotDensity(d);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? currentTheme.accentPrimary.withValues(alpha: 0.12)
                    : currentTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? currentTheme.accentPrimary
                      : currentTheme.borderSubtle,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.grid_view_rounded : Icons.grid_on_rounded,
                    size: 18,
                    color: isSelected
                        ? currentTheme.accentPrimary
                        : currentTheme.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: currentTheme.textPrimary,
                          ),
                        ),
                        Text(
                          d.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: currentTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_rounded,
                      color: currentTheme.accentPrimary,
                      size: 18,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGesturesTab() {
    final currentTheme = ThemeController.instance.theme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Text(
          'TOUCHPAD GESTURE BEHAVIOR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: currentTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),

        // 2-Finger Nav Switch
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: currentTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: currentTheme.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: currentTheme.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.swipe_rounded, color: currentTheme.accentPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2-Finger Browser Back / Forward',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: currentTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Swipe left/right to navigate back & forward in browsers and Explorer (Alt + Left/Right).',
                      style: TextStyle(fontSize: 11, color: currentTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: ThemeController.instance.twoFingerNavEnabled,
                activeColor: currentTheme.accentPrimary,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  ThemeController.instance.setTwoFingerNav(val);
                },
              ),
            ],
          ),
        ),

        // 3-Finger Laptop Switcher Switch
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: currentTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: currentTheme.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: currentTheme.accentSecondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.view_carousel_rounded, color: currentTheme.accentSecondary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3-Finger Laptop App Switcher',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: currentTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Holds Alt down during horizontal swipe to preview all windows on screen; swipe up for Task View (Win + Tab).',
                      style: TextStyle(fontSize: 11, color: currentTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: ThemeController.instance.threeFingerSwitcherEnabled,
                activeColor: currentTheme.accentSecondary,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  ThemeController.instance.setThreeFingerSwitcher(val);
                },
              ),
            ],
          ),
        ),

        // Micro-Movement Sub-Pixel Engine Status
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: currentTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: currentTheme.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: currentTheme.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.gps_fixed_rounded, color: currentTheme.accentPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Micro-Movement Sub-Pixel Engine',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: currentTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Accumulates fractional deltas (0.1px - 0.4px) for 120Hz micro-accuracy without dropping frames.',
                      style: TextStyle(fontSize: 11, color: currentTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: currentTheme.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: currentTheme.accentPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        Text(
          'QUICK GESTURE GUIDE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: currentTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: currentTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: currentTheme.borderSubtle),
          ),
          child: Column(
            children: [
              _buildGestureRow('1-Finger Glide', 'Move Mouse Cursor', currentTheme),
              _buildGestureRow('1-Finger Tap', 'Left Mouse Click', currentTheme),
              _buildGestureRow('Double-Tap & Hold', 'Drag Lock / Move Window', currentTheme),
              _buildGestureRow('2-Finger Tap', 'Right Mouse Click', currentTheme),
              _buildGestureRow('2-Finger Vertical', 'Smooth 2D Scroll', currentTheme),
              _buildGestureRow('2-Finger Horizontal', 'Browser Back & Forward', currentTheme),
              _buildGestureRow('3-Finger Swipe ↔', 'Laptop App Switcher (Alt+Tab)', currentTheme),
              _buildGestureRow('3-Finger Swipe ↑', 'Task View / Overview (Win+Tab)', currentTheme),
              _buildGestureRow('3-Finger Swipe ↓', 'Show Desktop (Win+D)', currentTheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGestureRow(String gesture, String action, PhonePadThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            gesture,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textPrimary),
          ),
          Text(
            action,
            style: TextStyle(fontSize: 12, color: theme.accentPrimary),
          ),
        ],
      ),
    );
  }
}
