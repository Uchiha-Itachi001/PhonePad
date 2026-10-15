import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/discovery_client.dart';
import '../../../core/power/power_governor.dart';
import '../../../core/theme/theme_controller.dart';

/// Control Center modal with unified same Wi-Fi Auto-Discovery, Appearance, Gestures, and Power Saver.
class ConnectionHubModal extends StatefulWidget {
  final DiscoveryClient discoveryClient;
  final String currentDestination;
  final Function(String address, String displayName, int pin) onConnect;
  final int initialSubTab;

  const ConnectionHubModal({
    super.key,
    required this.discoveryClient,
    required this.currentDestination,
    required this.onConnect,
    this.initialSubTab = 0,
  });

  @override
  State<ConnectionHubModal> createState() => _ConnectionHubModalState();
}

class _ConnectionHubModalState extends State<ConnectionHubModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DiscoveredHost> _wifiHosts = [];

  @override
  void initState() {
    super.initState();
    // 4 Main Tabs: Connections, Appearance, Gestures, Power Saver
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
    _wifiHosts = widget.discoveryClient.currentHosts;

    widget.discoveryClient.startDiscovery();
    widget.discoveryClient.hostsStream.listen((hosts) {
      if (mounted) {
        setState(() {
          _wifiHosts = hosts;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance.theme;

        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

        return Container(
          height: MediaQuery.of(context).size.height * (isLandscape ? 0.94 : 0.88),
          decoration: BoxDecoration(
            color: theme.backgroundSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: theme.borderSubtle)),
          ),
          child: Column(
            children: [
              // Drag Handle Indicator (Ultra-compact in landscape)
              Center(
                child: Container(
                  margin: EdgeInsets.only(
                    top: isLandscape ? 4 : 10,
                    bottom: isLandscape ? 2 : 6,
                  ),
                  width: isLandscape ? 32 : 40,
                  height: isLandscape ? 3 : 4,
                  decoration: BoxDecoration(
                    color: theme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Control Center Header (Scaled down in landscape)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: isLandscape ? 2 : 6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SETTINGS & CONTROL',
                          style: TextStyle(
                            fontSize: isLandscape ? 13 : 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: isLandscape ? 1.0 : 1.4,
                            color: theme.textPrimary,
                          ),
                        ),
                        if (!isLandscape) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Configure Wireless Links, Visuals & Power',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      visualDensity: isLandscape ? VisualDensity.compact : VisualDensity.standard,
                      padding: isLandscape ? EdgeInsets.zero : const EdgeInsets.all(8),
                      constraints: isLandscape ? const BoxConstraints() : null,
                      icon: Icon(
                        Icons.close_rounded,
                        color: theme.textSecondary,
                        size: isLandscape ? 18 : 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Top Primary Tab Bar (4 Unified Tabs - Slim 34px in Landscape)
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isLandscape ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  color: theme.surfaceCard,
                  borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),
                  border: Border.all(color: theme.borderSubtle),
                ),
                child: SizedBox(
                  height: isLandscape ? 34 : null,
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: theme.accentPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(isLandscape ? 10 : 14),
                      border: Border.all(
                        color: theme.accentPrimary.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    labelColor: theme.accentPrimary,
                    unselectedLabelColor: theme.textSecondary,
                    labelPadding: isLandscape ? const EdgeInsets.symmetric(horizontal: 4) : null,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isLandscape ? 10 : 11,
                    ),
                    tabs: isLandscape
                        ? const [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.sensors_rounded, size: 13),
                                  SizedBox(width: 4),
                                  Text('Connect'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.palette_rounded, size: 13),
                                  SizedBox(width: 4),
                                  Text('Themes'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.tune_rounded, size: 13),
                                  SizedBox(width: 4),
                                  Text('Gestures'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.battery_saver_rounded, size: 13),
                                  SizedBox(width: 4),
                                  Text('Power'),
                                ],
                              ),
                            ),
                          ]
                        : const [
                            Tab(icon: Icon(Icons.sensors_rounded, size: 16), text: 'Connect'),
                            Tab(icon: Icon(Icons.palette_rounded, size: 16), text: 'Themes'),
                            Tab(icon: Icon(Icons.tune_rounded, size: 16), text: 'Gestures'),
                            Tab(icon: Icon(Icons.battery_saver_rounded, size: 16), text: 'Power'),
                          ],
                  ),
                ),
              ),

              SizedBox(height: isLandscape ? 3 : 8),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildConnectionsTab(theme),
                    _buildThemesAndGridTab(theme),
                    _buildGesturesTab(theme),
                    _buildPowerSaverTab(theme),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 1: UNIFIED CONNECTIONS (WITH SUB-TABS)
  // =========================================================================

  Widget _buildConnectionsTab(PhonePadThemeData theme) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      children: [
        // Desktop App Download Instruction Banner
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: isLandscape ? 3 : 6,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: isLandscape ? 5 : 8,
          ),
          decoration: BoxDecoration(
            color: theme.accentPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.accentPrimary.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: theme.accentPrimary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_rounded,
                  size: isLandscape ? 14 : 17,
                  color: theme.accentPrimary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Desktop App Required',
                      style: TextStyle(
                        fontSize: isLandscape ? 10 : 11,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Download and run PhonePad Host on the PC or laptop where you want to use this.',
                      style: TextStyle(
                        fontSize: isLandscape ? 9 : 10,
                        color: theme.textSecondary.withValues(alpha: 0.9),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isLandscape ? 2 : 4),

        // Discovered Host List & Auto Scanning View
        Expanded(
          child: _buildWifiAutoContent(theme),
        ),
      ],
    );
  }

  // --- Wi-Fi Auto Discovered Host View ---
  Widget _buildWifiAutoContent(PhonePadThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DISCOVERED PC HOSTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: theme.textSecondary,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.discoveryClient.sendDiscoveryProbe();
                },
                icon: Icon(Icons.refresh_rounded, size: 15, color: theme.accentPrimary),
                label: Text('Scan', style: TextStyle(color: theme.accentPrimary, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (_wifiHosts.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.accentPrimary.withValues(alpha: 0.08),
                        border: Border.all(
                          color: theme.accentPrimary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.wifi_tethering_rounded,
                        color: theme.accentPrimary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Listening for UDP Beacon...',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ensure PhonePad Host is running on PC and\nboth devices are on the same Wi-Fi network.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textSecondary.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentPrimary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.discoveryClient.sendDiscoveryProbe();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'Refresh Scan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                  final isCurrent = widget.currentDestination == host.destination;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? theme.accentPrimary.withValues(alpha: 0.12)
                          : theme.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent ? theme.accentPrimary : theme.borderSubtle,
                        width: isCurrent ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.accentPrimary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.laptop_windows_rounded, color: theme.accentPrimary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                host.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                host.destination,
                                style: TextStyle(fontSize: 11, color: theme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCurrent ? theme.surfaceCard : theme.accentPrimary,
                            foregroundColor: isCurrent ? theme.accentPrimary : Colors.black,
                            elevation: isCurrent ? 0 : 4,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onConnect(host.destination, host.name, 0);
                          },
                          child: Text(
                            isCurrent ? 'Active' : 'Connect',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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

  // =========================================================================
  // TAB 2: THEMES & GRID MATRIX
  // =========================================================================

  Widget _buildThemesAndGridTab(PhonePadThemeData currentTheme) {
    final currentDensity = ThemeController.instance.dotDensity;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
        const SizedBox(height: 8),

        ...PhonePadThemeData.allThemes.map((t) {
          final isSelected = t.id == currentTheme.id;
          return GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              ThemeController.instance.setTheme(t.id);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? t.accentPrimary.withValues(alpha: 0.12)
                    : currentTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? t.accentPrimary : currentTheme.borderSubtle,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.accentPrimary,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.accentSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: currentTheme.textPrimary,
                          ),
                        ),
                        Text(
                          t.subtitle,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: currentTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: t.accentPrimary, size: 18),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 14),

        Text(
          'DOT MATRIX DENSITY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: currentTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: currentTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: currentTheme.borderSubtle),
          ),
          child: Row(
            children: DotMatrixDensity.values.map((d) {
              final isSel = d == currentDensity;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ThemeController.instance.setDotDensity(d);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel
                          ? currentTheme.accentPrimary.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSel
                            ? currentTheme.accentPrimary.withValues(alpha: 0.6)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      d.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        color: isSel
                            ? currentTheme.textPrimary
                            : currentTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // =========================================================================
  // TAB 3: GESTURES
  // =========================================================================

  Widget _buildGesturesTab(PhonePadThemeData currentTheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      children: [
        Text(
          'TRACKPAD GESTURES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: currentTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // 2-Finger Nav Switch
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: currentTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: currentTheme.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentTheme.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.swipe_rounded, color: currentTheme.accentPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2-Finger Browser Back / Forward',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: currentTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Swipe horizontal for Alt + Left/Right page navigation.',
                      style: TextStyle(fontSize: 10.5, color: currentTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: ThemeController.instance.twoFingerNavEnabled,
                activeThumbColor: currentTheme.accentPrimary,
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: currentTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: currentTheme.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentTheme.accentSecondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.view_carousel_rounded, color: currentTheme.accentSecondary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3-Finger Laptop App Switcher',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: currentTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Holds Alt down during horizontal swipe to preview windows.',
                      style: TextStyle(fontSize: 10.5, color: currentTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: ThemeController.instance.threeFingerSwitcherEnabled,
                activeThumbColor: currentTheme.accentSecondary,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  ThemeController.instance.setThreeFingerSwitcher(val);
                },
              ),
            ],
          ),
        ),

        // 2-Finger Pinch to Zoom Switch
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: currentTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: currentTheme.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentTheme.accentTertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.zoom_in_rounded, color: currentTheme.accentTertiary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2-Finger Pinch to Zoom',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: currentTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Squeeze / shrink to zoom out, expand to zoom in (Ctrl + Wheel).',
                      style: TextStyle(fontSize: 10.5, color: currentTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: ThemeController.instance.pinchZoomEnabled,
                activeThumbColor: currentTheme.accentTertiary,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  ThemeController.instance.setPinchZoom(val);
                },
              ),
            ],
          ),
        ),

        Text(
          'GESTURE REFERENCE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: currentTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: currentTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: currentTheme.borderSubtle),
          ),
          child: Column(
            children: [
              _buildGestureRow('1-Finger Glide', 'Move Cursor', currentTheme),
              _buildGestureRow('1-Finger Tap', 'Left Click', currentTheme),
              _buildGestureRow('Double-Tap & Hold', 'Drag Lock / Move Window', currentTheme),
              _buildGestureRow('2-Finger Tap', 'Right Click', currentTheme),
              _buildGestureRow('2-Finger Pinch / Squeeze', 'Zoom In / Out (Ctrl+Wheel)', currentTheme),
              _buildGestureRow('2-Finger Vertical', 'Smooth 2D Scroll', currentTheme),
              _buildGestureRow('2-Finger Horizontal', 'Browser Back / Forward', currentTheme),
              _buildGestureRow('3-Finger Swipe ↔', 'Laptop App Switcher (Alt+Tab)', currentTheme),
              _buildGestureRow('3-Finger Swipe ↑', 'Task View (Win+Tab)', currentTheme),
              _buildGestureRow('3-Finger Swipe ↓', 'Show Desktop (Win+D)', currentTheme),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGestureRow(String gesture, String action, PhonePadThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            gesture,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.textPrimary),
          ),
          Text(
            action,
            style: TextStyle(fontSize: 11.5, color: theme.accentPrimary),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 4: AMOLED POWER SAVER SETTINGS
  // =========================================================================

  Widget _buildPowerSaverTab(PhonePadThemeData currentTheme) {
    return ListenableBuilder(
      listenable: PowerGovernor.instance,
      builder: (context, _) {
        final governor = PowerGovernor.instance;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          children: [
            Text(
              'AMOLED POWER CONSERVATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: currentTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            // Master Enable Toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: currentTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: currentTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: currentTheme.accentPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bolt_rounded, color: currentTheme.accentPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AMOLED Auto-Dimming',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: currentTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dims OLED screen during idle periods to eliminate battery drain.',
                          style: TextStyle(fontSize: 10.5, color: currentTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: governor.isEnabled,
                    activeThumbColor: currentTheme.accentPrimary,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      governor.setEnabled(val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'IDLE SLEEP TIMEOUT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: currentTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            // Timeout Selector Pills
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: currentTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: currentTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  _buildTimeoutOption('1 min', 60, governor, currentTheme),
                  _buildTimeoutOption('2 min', 120, governor, currentTheme),
                  _buildTimeoutOption('3 min', 180, governor, currentTheme),
                  _buildTimeoutOption('5 min', 300, governor, currentTheme),
                  _buildTimeoutOption('Never', 0, governor, currentTheme),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Live Governor Telemetry Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: currentTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: currentTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.touch_app_rounded, size: 16, color: currentTheme.accentPrimary),
                          const SizedBox(width: 6),
                          Text(
                            'Instant 0ms Tap-to-Wake',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: currentTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: governor.isDimmed
                              ? Colors.amber.withValues(alpha: 0.15)
                              : currentTheme.accentPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          governor.isDimmed ? 'DIMMED' : 'AWAKE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: governor.isDimmed ? Colors.amber : currentTheme.accentPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When dimmed, a zero-power touch listener stays active. Any finger contact immediately restores 100% luminance in 0ms without input lag.',
                    style: TextStyle(
                      fontSize: 11,
                      color: currentTheme.textSecondary.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildTimeoutOption(
    String label,
    int seconds,
    PowerGovernor governor,
    PhonePadThemeData theme,
  ) {
    final isSelected = governor.timeoutSeconds == seconds;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          governor.setTimeoutSeconds(seconds);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.accentPrimary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.accentPrimary.withValues(alpha: 0.6)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? theme.textPrimary : theme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
