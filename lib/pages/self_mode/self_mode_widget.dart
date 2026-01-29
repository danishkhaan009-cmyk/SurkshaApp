import '/flutter_flow/flutter_flow_button_tabbar.dart';
import '/flutter_flow/flutter_flow_static_map.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:mapbox_search/mapbox_search.dart' as mapbox;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/services/location_tracking_service.dart';
import '/services/child_mode_service.dart';
import '/services/installed_apps_service.dart';
import '/services/call_logs_service.dart';
import '/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'self_mode_model.dart';
export 'self_mode_model.dart';

class SelfModeWidget extends StatefulWidget {
  const SelfModeWidget({super.key});

  static String routeName = 'Self_mode';
  static String routePath = '/selfMode';

  @override
  State<SelfModeWidget> createState() => _SelfModeWidgetState();
}

class _SelfModeWidgetState extends State<SelfModeWidget>
    with TickerProviderStateMixin {
  late SelfModeModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Installed apps state variables
  bool _isLoadingApps = false;
  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _filteredApps = [];
  // ignore: unused_field
  String? _appsError;
  final TextEditingController _appSearchController = TextEditingController();

  // Call logs state variables
  bool _isLoadingCallLogs = false;
  List<Map<String, dynamic>> _callLogs = [];
  // ignore: unused_field
  String? _callLogsError;

  // Local locked apps set
  Set<String> _localLockedApps = {};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SelfModeModel());

    _model.tabBarController = TabController(
      vsync: this,
      length: 6,
      initialIndex: 0,
    )..addListener(_handleTabChange);

    _model.switchValue = true;

    // 1. Enable blocking engine on the native side immediately
    AppBlockBridge.setChildMode(true);

    // 2. Load locally locked apps
    _loadLocalLockedApps();

    // 3. Check for accessibility on launch
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAccessibility());

    // 4. Start periodic app sync if device ID exists
    _startAppSync();

    // Setup search listener
    _appSearchController.addListener(_filterApps);
  }

  Future<void> _startAppSync() async {
    final deviceId = await ChildModeService.getChildDeviceId();
    if (deviceId != null && deviceId.isNotEmpty) {
      print('📱 Starting periodic app sync for self mode device: $deviceId');
      InstalledAppsService.startPeriodicSync(deviceId);
    }
  }

  Future<void> _checkAccessibility() async {
    final enabled = await PermissionService.isAccessibilityEnabled();
    if (!enabled) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'To enable app locking, SurakshaApp needs Accessibility Service permission.\n\nPlease enable it in the next screen.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await PermissionService.requestAccessibilityPermission();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B242)),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadLocalLockedApps() async {
    final locked = await AppBlockBridge.getLockedApps();
    if (mounted) {
      setState(() {
        _localLockedApps = locked.toSet();
      });
    }
  }

  @override
  void dispose() {
    _model.tabBarController?.removeListener(_handleTabChange);
    _model.dispose();
    _appSearchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_model.tabBarController!.indexIsChanging) {
      safeSetState(() {});
      if (_model.tabBarController!.index == 5) {
        if (_callLogs.isEmpty && !_isLoadingCallLogs) {
          _fetchCallLogs();
        }
      } else if (_model.tabBarController!.index == 1) {
        if (_installedApps.isEmpty && !_isLoadingApps) {
          _fetchInstalledApps();
        }
      }
    }
  }

  // Fetch call logs
  Future<void> _fetchCallLogs() async {
    setState(() {
      _isLoadingCallLogs = true;
      _callLogsError = null;
    });

    try {
      final callLogs = await CallLogsService.getCallLogs(limit: 50);
      if (!mounted) return;
      setState(() {
        _callLogs = callLogs;
        _isLoadingCallLogs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCallLogs = false;
        _callLogsError = e.toString();
      });
    }
  }

  // Fetch installed apps
  Future<void> _fetchInstalledApps() async {
    setState(() {
      _isLoadingApps = true;
      _appsError = null;
    });

    try {
      final apps = await InstalledAppsService.getInstalledApps();
      if (!mounted) return;
      setState(() {
        _installedApps = apps;
        _filteredApps = apps;
        _isLoadingApps = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingApps = false;
        _appsError = e.toString();
      });
    }
  }

  // Filter apps based on search query
  void _filterApps() {
    final query = _appSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredApps = _installedApps;
      } else {
        _filteredApps = _installedApps.where((app) {
          final appName = (app['appName'] as String).toLowerCase();
          final packageName = (app['packageName'] as String).toLowerCase();
          return appName.contains(query) || packageName.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _showExitPinDialog();
      },
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          appBar: AppBar(
            backgroundColor: Colors.white,
            automaticallyImplyLeading: false,
            title: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 0.0, 0.0),
              child: Text(
                'Self-Control Mode',
                style: FlutterFlowTheme.of(context).headlineMedium.override(
                      font: GoogleFonts.interTight(
                        fontWeight: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontWeight,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontStyle,
                      ),
                      color: const Color(0xFF1A1A1A),
                      fontSize: 22.0,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.exit_to_app,
                  color: Color(0xFF1A1A1A),
                  size: 24,
                ),
                onPressed: () async {
                  await _showExitPinDialog();
                },
              ),
            ],
            centerTitle: false,
            elevation: 2.0,
          ),
          body: SafeArea(
            top: true,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Container(
                    width: MediaQuery.sizeOf(context).width * 1.0,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF6F6F6),
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: const Alignment(-1.0, 0),
                          child: FlutterFlowButtonTabBar(
                            useToggleButtonStyle: false,
                            isScrollable: true,
                            labelStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  fontSize: 16.0,
                                  lineHeight: 2.0,
                                ),
                            unselectedLabelStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                ),
                            labelColor:
                                FlutterFlowTheme.of(context).primaryText,
                            unselectedLabelColor:
                                FlutterFlowTheme.of(context).secondaryText,
                            backgroundColor: const Color(0xFFD4E7D4),
                            unselectedBackgroundColor: Colors.white,
                            borderColor: const Color(0xFF00B242),
                            unselectedBorderColor:
                                FlutterFlowTheme.of(context).alternate,
                            borderWidth: 1.0,
                            borderRadius: 5.0,
                            elevation: 0.0,
                            buttonMargin: const EdgeInsetsDirectional.fromSTEB(
                                10.0, 10.0, 10.0, 10.0),
                            tabs: const [
                              Tab(
                                text: 'Rules',
                                icon: Icon(Icons.access_time),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                    50.0, 0.0, 50.0, 0.0),
                              ),
                              Tab(
                                text: 'Apps',
                                icon: Icon(Icons.apps_sharp),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                    50.0, 0.0, 50.0, 0.0),
                              ),
                              Tab(
                                text: 'Location Plus',
                                icon: Icon(Icons.location_on_outlined),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                    50.0, 0.0, 50.0, 0.0),
                              ),
                              Tab(
                                text: 'Photos Pro',
                                icon: Icon(Icons.photo_outlined),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                    50.0, 0.0, 50.0, 0.0),
                              ),
                              Tab(
                                text: 'Chat Pro',
                                icon: Icon(Icons.video_chat_outlined),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                    50.0, 0.0, 50.0, 0.0),
                              ),
                              Tab(
                                text: 'Call Pro',
                                icon: Icon(Icons.call_outlined),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                    50.0, 0.0, 50.0, 0.0),
                              ),
                            ],
                            controller: _model.tabBarController,
                            onTap: (i) async {
                              [
                                () async {}, // Rules tab
                                () async {
                                  // Apps tab - load apps if not loaded
                                  print('📱 Apps tab clicked');
                                  if (_installedApps.isEmpty &&
                                      !_isLoadingApps) {
                                    print('🔄 Apps list is empty, fetching...');
                                    await _fetchInstalledApps();
                                  } else {
                                    print(
                                        '✅ Apps already loaded: ${_installedApps.length} apps');
                                  }
                                },
                                () async {}, // Location Plus tab
                                () async {}, // Photos Pro tab
                                () async {}, // Keylogging tab
                                () async {
                                  // Call Pro tab - load call logs if not loaded
                                  print('📞 Call Pro tab clicked');
                                  if (_callLogs.isEmpty &&
                                      !_isLoadingCallLogs) {
                                    print(
                                        '🔄 Call logs list is empty, fetching...');
                                    await _fetchCallLogs();
                                  } else {
                                    print(
                                        '✅ Call logs already loaded: ${_callLogs.length} calls');
                                  }
                                } // Call Pro tab
                              ][i]();
                            },
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _model.tabBarController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildRulesTab(),
                              _buildAppsTab(),
                              _buildLocationTab(),
                              _buildPlaceholderTab('Photos Pro'),
                              _buildPlaceholderTab('Chat Pro'),
                              _buildCallsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRulesTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
        child: Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    Container(
                      width: 50.0,
                      height: 50.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      child: const Icon(Icons.access_time,
                          color: Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bed time',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                          Text('45/120 min today',
                              style: GoogleFonts.poppins()),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _model.switchValue!,
                      onChanged: (val) =>
                          safeSetState(() => _model.switchValue = val),
                      activeColor: const Color(0xFF4CAF51),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FFButtonWidget(
                      onPressed: () {},
                      text: 'Edit',
                      icon: const Icon(Icons.mode_edit_outlined, size: 18),
                      options: FFButtonOptions(
                        width: 250,
                        height: 40,
                        color: const Color(0xFFF6F6F6),
                        textStyle: FlutterFlowTheme.of(context).labelMedium,
                        borderSide: const BorderSide(color: Color(0xFFDBDBDB)),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_sharp,
                          color: FlutterFlowTheme.of(context).error, size: 28),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppsTab() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _appSearchController,
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _isLoadingApps
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredApps.length,
                    itemBuilder: (context, i) {
                      final app = _filteredApps[i];
                      final packageName = app['packageName'] ?? '';
                      final isLocked = _localLockedApps.contains(packageName);

                      return ListTile(
                        leading: app['icon'] != null
                            ? Image.memory(app['icon'], width: 40)
                            : const Icon(Icons.android),
                        title: Text(app['appName'] ?? 'Unknown'),
                        subtitle: Text(packageName),
                        trailing: Switch.adaptive(
                          value: isLocked,
                          onChanged: (val) async {
                            if (val) {
                              // Only ask for PIN when LOCKING
                              final pin = await _showSetAppPinDialog();
                              if (pin != null) {
                                await _toggleAppLock(packageName, true, pin);
                              }
                            } else {
                              // Unlock directly
                              await _toggleAppLock(packageName, false, "");
                            }
                          },
                          activeColor: const Color(0xFF58C16D),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showSetAppPinDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Set App Lock PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Enter 4-digit PIN'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.length == 4) {
                Navigator.pop(ctx, controller.text);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAppLock(String packageName, bool lock, String pin) async {
    // 1. Sync to native Android side
    final List<String> currentLocked = _localLockedApps.toList();

    if (lock) {
      if (!currentLocked.contains(packageName)) currentLocked.add(packageName);
      // Set the PIN for this specific app
      await AppBlockBridge.setAppLockPin(packageName, pin);
    } else {
      currentLocked.remove(packageName);
    }

    // Update locked apps list using AppBlockBridge
    await AppBlockBridge.setLockedApps(currentLocked);

    // 2. Refresh local UI state
    await _loadLocalLockedApps();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(lock ? 'App locked successfully' : 'App unlocked')),
      );
    }
  }

  Widget _buildLocationTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: FlutterFlowStaticMap(
              location: const LatLng(9.341465, -79.891704),
              apiKey: 'ENTER_YOUR_MAPBOX_API_KEY_HERE',
              style: mapbox.MapBoxStyle.Light,
              width: double.infinity,
              height: 200,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: FFButtonWidget(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final deviceId = prefs.getString('deviceId');
                if (deviceId != null) {
                  await LocationTrackingService().startTracking(deviceId);
                  await LocationTrackingService().triggerLocationUpdate();
                }
              },
              text: 'Start Location Tracking',
              options: const FFButtonOptions(
                  width: double.infinity, height: 50, color: Color(0xFF58C16D)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallsTab() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: _isLoadingCallLogs
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _callLogs.length,
              itemBuilder: (context, i) {
                final call = _callLogs[i];
                return ListTile(
                  leading: const Icon(Icons.call),
                  title: Text(call['name'] ?? 'Unknown'),
                  subtitle: Text(call['number'] ?? ''),
                );
              },
            ),
    );
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(child: Text(title, style: const TextStyle(fontSize: 20)));
  }

  Future<void> _showExitPinDialog() async {
    final pinController = TextEditingController();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Exit PIN', textAlign: TextAlign.center),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
                hintText: '____',
                counterText: '',
                border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final isCorrect =
                    await ChildModeService.verifyExitPin(pinController.text);
                if (isCorrect) {
                  final deviceId = await ChildModeService.getChildDeviceId();
                  await LocationTrackingService().stopTracking();
                  if (deviceId != null) {
                    await Supabase.instance.client.from('devices').update(
                        {'active_device_identifier': null}).eq('id', deviceId);
                  }
                  await ChildModeService.deactivateChildMode();
                  if (context.mounted) {
                    Navigator.pop(context);
                    context.goNamed(SelectModeWidget.routeName);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Incorrect PIN'),
                      backgroundColor: Colors.red));
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }
}
