import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../flutter_flow/flutter_flow_static_map.dart';
import '../../services/app_lock_service.dart';
import '../../services/permission_service.dart';
import '../app_list/app_list_item.dart';
import '/flutter_flow/flutter_flow_audio_player.dart';
import '/flutter_flow/flutter_flow_button_tabbar.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '/services/location_tracking_service.dart';
import '/services/installed_apps_service.dart';
import '/services/call_logs_service.dart';
import '/services/device_data_sync_service.dart';
import '/backend/supabase/supabase_rules.dart';
import 'childs_device_model.dart';
export 'childs_device_model.dart';
import 'package:mapbox_search/mapbox_search.dart' as mapbox;

class ChildsDeviceWidget extends StatefulWidget {
  const ChildsDeviceWidget({
    super.key,
    this.deviceId,
    this.childName,
    this.childAge,
  });

  final String? deviceId;
  final String? childName;
  final int? childAge;

  static String routeName = 'Childs_Device';
  static String routePath = '/childsDevice';

  @override
  State<ChildsDeviceWidget> createState() => _ChildsDeviceWidgetState();
}

class _ChildsDeviceWidgetState extends State<ChildsDeviceWidget>
    with TickerProviderStateMixin {
  late ChildsDeviceModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Location state variables
  bool _isLoadingLocation = true;
  List<Map<String, dynamic>> _locationHistory = [];
  Map<String, dynamic>? _latestLocation;
  String? _deviceId;

  // Installed apps state variables
  bool _isLoadingApps = false;
  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _filteredApps = [];
  String? _appsError;
  final TextEditingController _appSearchController = TextEditingController();
  StreamSubscription? _appsSubscription;

  // Call logs state variables
  bool _isLoadingCallLogs = false;
  List<Map<String, dynamic>> _callLogs = [];
  String? _callLogsError;

  // List to store rules
  List<Map<String, dynamic>> rules = [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChildsDeviceModel());

    _model.tabBarController = TabController(
      vsync: this,
      length: 6,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));
    _model.tabBarController!.addListener(_handleTabChange);

    _model.switchValue = true;

    // Fetch location data
    _fetchLocationData();

    // Fetch rules from database
    _fetchRulesFromDatabase();

    // Fetch installed apps
    _fetchInstalledApps();

    // Setup search listener
    _appSearchController.addListener(_filterApps);
  }

  // Fetch rules from Supabase
  Future<void> _fetchRulesFromDatabase() async {
    if (widget.deviceId == null || widget.deviceId!.isEmpty) {
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // Fetch rules for this device
      final rulesData = await supabase
          .from('device_rules')
          .select()
          .eq('device_id', widget.deviceId!)
          .order('created_at', ascending: false);

      setState(() {
        rules = rulesData.map<Map<String, dynamic>>((rule) {
          // Convert database rule to UI format
          IconData ruleIcon;

          switch (rule['rule_type']) {
            case 'App Time Limit':
              ruleIcon = FontAwesomeIcons.clock;
              break;
            case 'Daily Screen Time':
              ruleIcon = Icons.access_time_rounded;
              break;
            case 'Bedtime Lock':
              ruleIcon = Icons.bedtime_outlined;
              break;
            case 'App Lock':
              ruleIcon = Icons.lock_rounded;
              break;
            default:
              ruleIcon = Icons.rule;
          }

          return {
            'id': rule['id'], // Store database ID
            'icon': ruleIcon,
            'title': rule['title'],
            'subtitle': rule['subtitle'],
            // keep both casing variants so helpers can read either
            'isActive': rule['is_active'] ?? rule['isActive'] ?? false,
            'is_active': rule['is_active'] ?? rule['isActive'] ?? false,
            'rule_type': rule['rule_type'],
            'app_package_name': rule['app_package_name'] ??
                rule['package_name'] ??
                rule['appPackageName'],
            'time_limit_minutes': rule['time_limit_minutes'],
            // include PIN related fields so UI can detect if PIN was set
            'app_lock_pin': rule['app_lock_pin'],
            'pin_code': rule['pin_code'],
          };
        }).toList();
      });

      print('✅ Loaded ${rules.length} rules from database');
    } catch (e) {
      print('❌ Error fetching rules: $e');
    }
  }

  // Fetch location history from Supabase
  Future<void> _fetchLocationData() async {
    try {
      print('🔍 Fetching location data for device: ${widget.deviceId}');

      // Use the device ID passed from parent dashboard
      if (widget.deviceId == null || widget.deviceId!.isEmpty) {
        print('⚠️ No device ID provided');
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      _deviceId = widget.deviceId;
      print('✅ Using Device ID: $_deviceId');

      final supabase = Supabase.instance.client;

      // Fetch latest location
      final latestLocations = await supabase
          .from('locations')
          .select()
          .eq('device_id', _deviceId!)
          .order('recorded_at', ascending: false)
          .limit(1);

      print('📍 Found ${latestLocations.length} latest locations');

      if (latestLocations.isNotEmpty) {
        _latestLocation = latestLocations.first;
        print('✅ Latest location: ${_latestLocation?['address']}');
      } else {
        print('⚠️ No latest location found');
      }

      // Fetch location history (last 10 locations)
      final locationHistory = await supabase
          .from('locations')
          .select()
          .eq('device_id', _deviceId!)
          .order('recorded_at', ascending: false)
          .limit(10);

      print('📜 Found ${locationHistory.length} location history entries');

      setState(() {
        _locationHistory = List<Map<String, dynamic>>.from(locationHistory);
        _isLoadingLocation = false;
      });

      print('✅ Location data fetch completed');
    } catch (e) {
      print('❌ Error fetching location data: $e');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  // Fetch installed apps
  Future<void> _fetchInstalledApps() async {
    print(
        '🔄 Starting to fetch installed apps for device: ${widget.deviceId}...');
    setState(() {
      _isLoadingApps = true;
      _appsError = null;
    });

    try {
      // Use the device ID from widget parameter to fetch apps from database
      final deviceIdToFetch = widget.deviceId ?? _deviceId;

      if (deviceIdToFetch == null || deviceIdToFetch.isEmpty) {
        throw Exception('Device ID is not available');
      }

      // Cancel existing subscription if any
      await _appsSubscription?.cancel();

      // Set up real-time subscription for app updates
      print('👁️ Setting up real-time subscription for apps...');
      _appsSubscription =
          DeviceDataSyncService.watchInstalledApps(deviceIdToFetch).listen(
              (appsFromDb) {
        if (!mounted) return;

        // Transform the data to match the expected format
        final apps = appsFromDb
            .map((app) => {
                  'appName': app['app_name'] ?? 'Unknown App',
                  'packageName': app['package_name'] ?? '',
                  'versionName': app['version_name'] ?? '',
                })
            .toList();

        print('✅ Real-time update: ${apps.length} installed apps');

        setState(() {
          _installedApps = apps;
          _filteredApps = _appSearchController.text.isEmpty
              ? apps
              : apps.where((app) {
                  final query = _appSearchController.text.toLowerCase();
                  final appName = (app['appName'] as String).toLowerCase();
                  final packageName =
                      (app['packageName'] as String).toLowerCase();
                  return appName.contains(query) || packageName.contains(query);
                }).toList();
          _isLoadingApps = false;
          _appsError = null;
        });
      }, onError: (error) {
        print('❌ Error in real-time subscription: $error');
        if (mounted) {
          setState(() {
            _isLoadingApps = false;
            _appsError = error.toString();
          });
        }
      });
    } catch (e, stackTrace) {
      print('❌ Error fetching installed apps: $e');
      print('Stack trace: $stackTrace');

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

// Replace the existing _fetchCallLogs with this database-backed version
  Future<void> _fetchCallLogs() async {
    print('📞 Starting to fetch call logs from database...');
    if (!mounted) return;

    setState(() {
      _isLoadingCallLogs = true;
      _callLogsError = null;
    });

    try {
      // Fetch call logs from the database for this device
      final callLogs =
          await DeviceDataSyncService.fetchCallLogs(widget.deviceId ?? '');

      print('✅ Loaded ${callLogs.length ?? 0} call logs from database');

      // Convert timestamp strings back to DateTime objects
      final parsed = <Map<String, dynamic>>[];
      for (final item in callLogs) {
        if (item is Map<String, dynamic>) {
          final call = Map<String, dynamic>.from(item);
          // Convert timestamp string to DateTime if needed
          if (call['timestamp'] is String) {
            call['timestamp'] = DateTime.parse(call['timestamp']);
          }
          parsed.add(call);
        }
      }

      if (!mounted) return;
      setState(() {
        _callLogs = parsed;
        _isLoadingCallLogs = false;
        _callLogsError = null;
      });
    } catch (e, st) {
      print('❌ Error fetching call logs: $e');
      print('Stack trace: $st');
      if (!mounted) return;
      setState(() {
        _isLoadingCallLogs = false;
        _callLogsError = e.toString();
        _callLogs = [];
      });
    }
  }

  void _handleTabChange() {
    if (!_model.tabBarController!.indexIsChanging &&
        _model.tabBarController!.index == 5) {
      if (_callLogs.isEmpty && !_isLoadingCallLogs) {
        _fetchCallLogs();
      }
    }
  }

// in dispose()
  @override
  void dispose() {
    try {
      _model.tabBarController!.removeListener(_handleTabChange);
    } catch (_) {}
    _model.dispose();
    _appSearchController.dispose();
    _appsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30.0,
            borderWidth: 1.0,
            buttonSize: 60.0,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF1A1A1A),
              size: 30.0,
            ),
            onPressed: () async {
              context.pop();
            },
          ),
          title: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 0.0, 0.0),
            child: Text(
              '${widget.childName ?? 'Child Name'}, ${widget.childAge ?? 12}',
              style: FlutterFlowTheme.of(context).headlineMedium.override(
                    font: GoogleFonts.interTight(
                      fontWeight: FlutterFlowTheme.of(context)
                          .headlineMedium
                          .fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
                    color: const Color(0xFF1A1A1A),
                    fontSize: 22.0,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
            ),
          ),
          actions: const [],
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
                  height: 0.0,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF6F6F6),
                  ),
                  child: Align(
                    alignment: const AlignmentDirectional(0.0, 0.0),
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
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
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
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
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
                                icon: Icon(
                                  Icons.access_time,
                                ),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                    50.0, 0.0, 50.0, 0.0),
                              ),
                              Tab(
                                text: 'Apps',
                                icon: Icon(
                                  Icons.apps_sharp,
                                ),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                    50.0, 0.0, 50.0, 0.0),
                              ),
                              Tab(
                                text: 'Location Plus',
                                icon: Icon(
                                  Icons.location_on_outlined,
                                ),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                    50.0, 0.0, 50.0, 0.0),
                              ),
                              Tab(
                                text: 'Photos Pro',
                                icon: Icon(
                                  Icons.photo_outlined,
                                ),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                    50.0, 0.0, 50.0, 0.0),
                              ),
                              Tab(
                                text: 'keylogging',
                                icon: Icon(
                                  Icons.video_chat_outlined,
                                ),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                    50.0, 0.0, 50.0, 0.0),
                              ),
                              Tab(
                                text: 'Call Pro',
                                icon: Icon(
                                  Icons.call_outlined,
                                ),
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
                              // Tab 0: Rules
                              _buildRulesTab(),
                              // Tab 1: Apps
                              _buildAppsTab(),
                              // Tab 2: Location
                              _buildLocationTab(),
                              // Tab 3: Photos
                              _buildPlaceholderTab('Photos Pro'),
                              // Tab 4: Chat
                              _buildPlaceholderTab('Chat Pro'),
                              // Tab 5: Call Pro
                              _buildCallsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddRuleDialog() {
    String? selectedRuleType = 'App Time Limit';
    String? selectedCategory = 'Social Media';
    String? selectedApp;
    int timeLimit = 60;
    String? appPin;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: SingleChildScrollView(
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add New Rule',
                            style: GoogleFonts.inter(
                              fontSize: 20.0,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Create rules to manage app usage and screen time',
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          color: const Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 24.0),

                      // Rule Type
                      Text(
                        'Rule Type',
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRuleType,
                            isExpanded: true,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            items: [
                              'App Time Limit',
                              'Daily Screen Time',
                              'Bedtime Lock',
                              'App Lock',
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: GoogleFonts.inter(
                                    fontSize: 14.0,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedRuleType = newValue;
                              });
                            },
                            icon: const Icon(Icons.keyboard_arrow_down),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // App Category
                      if (selectedRuleType == 'App Time Limit' ||
                          selectedRuleType == 'App Lock') ...[
                        Text(
                          'App Category',
                          style: GoogleFonts.inter(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCategory,
                              isExpanded: true,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              items: [
                                'Social Media',
                                'Messaging',
                                'Entertainment',
                                'Gaming',
                                'Browsers',
                              ].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Row(
                                    children: [
                                      Text(
                                        value,
                                        style: GoogleFonts.inter(
                                          fontSize: 14.0,
                                          color: const Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedCategory = newValue;
                                  selectedApp = null; // Reset app selection
                                });
                              },
                              icon: const Icon(Icons.keyboard_arrow_down),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        // App Name
                        Text(
                          'App Name',
                          style: GoogleFonts.inter(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedApp,
                              hint: Text(
                                'Select an app',
                                style: GoogleFonts.inter(
                                  fontSize: 14.0,
                                  color: const Color(0xFF999999),
                                ),
                              ),
                              isExpanded: true,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              items: _getAppsForCategory(selectedCategory)
                                  .map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: GoogleFonts.inter(
                                      fontSize: 14.0,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedApp = newValue;
                                });
                              },
                              icon: const Icon(Icons.keyboard_arrow_down),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                      ],

                      // For App Lock - show PIN instead of time limit
                      if (selectedRuleType == 'App Lock') ...[
                        Text(
                          'Set PIN for this App',
                          style: GoogleFonts.inter(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 4,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '4-digit PIN',
                              counterText: '',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14.0,
                                color: const Color(0xFF999999),
                              ),
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 14.0,
                              color: const Color(0xFF1A1A1A),
                            ),
                            onChanged: (value) {
                              appPin = value;
                            },
                          ),
                        ),
                      ],

                      // For other rule types - show time limit
                      if (selectedRuleType != 'App Lock') ...[
                        Text(
                          'Time Limit (minutes)',
                          style: GoogleFonts.inter(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '60',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14.0,
                                color: const Color(0xFF999999),
                              ),
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 14.0,
                              color: const Color(0xFF1A1A1A),
                            ),
                            onChanged: (value) {
                              timeLimit = int.tryParse(value) ?? 60;
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 24.0),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: Color(0xFFE0E0E0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14.0),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // Add new rule to database
                                if (selectedRuleType != null &&
                                    widget.deviceId != null) {
                                  String ruleTitle;
                                  String ruleSubtitle;
                                  String? appPackageName;
                                  String? bedtimeStart;
                                  String? bedtimeEnd;

                                  if (selectedRuleType == 'App Time Limit' &&
                                      selectedApp != null) {
                                    ruleTitle = '$selectedApp Time Limit';
                                    ruleSubtitle =
                                        'Limited to $timeLimit minutes';

                                    // Get package name from database
                                    appPackageName =
                                        await SupabaseRules.getPackageName(
                                            selectedApp!);
                                  } else if (selectedRuleType ==
                                      'Daily Screen Time') {
                                    ruleTitle = 'Daily Screen Limit';
                                    ruleSubtitle = '$timeLimit minutes per day';
                                  } else if (selectedRuleType == 'App Lock') {
                                    if (selectedApp == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              '❌ Please select an app to lock'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    if (appPin == null || appPin!.length != 4) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              '❌ Please set a 4-digit PIN'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    ruleTitle = '$selectedApp Lock';
                                    ruleSubtitle = 'App locked - PIN required';

                                    // Get package name for the locked app
                                    appPackageName =
                                        await SupabaseRules.getPackageName(
                                            selectedApp!);
                                  } else {
                                    // Bedtime Lock
                                    ruleTitle = 'Bedtime Lock';
                                    ruleSubtitle = '10:00 PM - 7:00 AM';
                                    bedtimeStart = '22:00:00';
                                    bedtimeEnd = '07:00:00';
                                  }

                                  // Get current user (parent) ID
                                  final supabase = Supabase.instance.client;
                                  final parentId =
                                      supabase.auth.currentUser?.id;

                                  if (parentId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('❌ Please log in first'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  // Show loading
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Adding rule...'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  }

                                  // Add rule to database
                                  final success = await SupabaseRules.addRule(
                                    deviceId: widget.deviceId!,
                                    parentId: parentId,
                                    ruleType: selectedRuleType!,
                                    title: ruleTitle,
                                    subtitle: ruleSubtitle,
                                    appCategory: selectedCategory,
                                    appName: selectedApp,
                                    appPackageName: appPackageName,
                                    timeLimitMinutes: timeLimit,
                                    bedtimeStart: bedtimeStart,
                                    bedtimeEnd: bedtimeEnd,
                                    isActive: true,
                                    appLockPin: appPin,
                                  );

                                  if (success) {
                                    // Refresh rules from database
                                    await _fetchRulesFromDatabase();

                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('✅ Rule added successfully'),
                                          backgroundColor: Color(0xFF58C16D),
                                        ),
                                      );

                                      Navigator.of(context).pop();
                                    }
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('❌ Failed to add rule'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF666666),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14.0),
                                elevation: 0,
                              ),
                              child: Text(
                                'Add Rule',
                                style: GoogleFonts.inter(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditRuleDialog(int index) {
    Map<String, dynamic> rule = rules[index];
    String? selectedRuleType;
    String? selectedCategory;
    String? selectedApp;
    int timeLimit = 60;

    // Parse existing rule data
    String title = rule['title'];
    String subtitle = rule['subtitle'];

    // Extract time limit from subtitle
    RegExp timeLimitRegex = RegExp(r'(\d+)\s*minutes?');
    Match? match = timeLimitRegex.firstMatch(subtitle);
    if (match != null) {
      timeLimit = int.parse(match.group(1)!);
    } else {
      // Try to extract from "X hours per day"
      RegExp hoursRegex = RegExp(r'(\d+)\s*hours?');
      Match? hoursMatch = hoursRegex.firstMatch(subtitle);
      if (hoursMatch != null) {
        timeLimit = int.parse(hoursMatch.group(1)!) * 60;
      }
    }

    // Determine rule type from title
    if (title.contains('Bedtime')) {
      selectedRuleType = 'Bedtime Lock';
    } else if (title.contains('Daily Screen')) {
      selectedRuleType = 'Daily Screen Time';
    } else if (title.contains('App Lock')) {
      selectedRuleType = 'App Lock';
    } else {
      selectedRuleType = 'App Time Limit';
      // Extract app name
      String appName = title.replaceAll(' Time Limit', '').trim();
      selectedApp = appName;
      selectedCategory = 'Social Media'; // Default
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Rule',
                          style: GoogleFonts.inter(
                            fontSize: 20.0,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Update rules to manage app usage and screen time',
                      style: GoogleFonts.inter(
                        fontSize: 14.0,
                        color: const Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Rule Type
                    Text(
                      'Rule Type',
                      style: GoogleFonts.inter(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRuleType,
                          isExpanded: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          items: [
                            'App Time Limit',
                            'Daily Screen Time',
                            'Bedtime Lock',
                            'App Lock',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: GoogleFonts.inter(
                                  fontSize: 14.0,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedRuleType = newValue;
                            });
                          },
                          icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // App Category
                    if (selectedRuleType == 'App Time Limit') ...[
                      Text(
                        'App Category',
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            items: [
                              'Social Media',
                              'Messaging',
                              'Entertainment',
                              'Gaming',
                              'Browsers',
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Row(
                                  children: [
                                    Text(
                                      value,
                                      style: GoogleFonts.inter(
                                        fontSize: 14.0,
                                        color: const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedCategory = newValue;
                                selectedApp = null;
                              });
                            },
                            icon: const Icon(Icons.keyboard_arrow_down),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // App Name
                      Text(
                        'App Name',
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedApp,
                            hint: Text(
                              'Select an app',
                              style: GoogleFonts.inter(
                                fontSize: 14.0,
                                color: const Color(0xFF999999),
                              ),
                            ),
                            isExpanded: true,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            items: _getAppsForCategory(selectedCategory)
                                .map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: selectedApp == value
                                        ? const Color(0xFF58C16D)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 8.0,
                                  ),
                                  child: Text(
                                    value,
                                    style: GoogleFonts.inter(
                                      fontSize: 14.0,
                                      color: selectedApp == value
                                          ? Colors.white
                                          : const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedApp = newValue;
                              });
                            },
                            icon: const Icon(Icons.keyboard_arrow_down),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],

                    // Time Limit
                    Text(
                      'Time Limit (minutes)',
                      style: GoogleFonts.inter(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller:
                            TextEditingController(text: timeLimit.toString()),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14.0,
                            color: const Color(0xFF999999),
                          ),
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          color: const Color(0xFF1A1A1A),
                        ),
                        onChanged: (value) {
                          timeLimit = int.tryParse(value) ?? timeLimit;
                        },
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14.0),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // Update the rule in database
                              if (selectedRuleType != null &&
                                  rule['id'] != null) {
                                String ruleTitle;
                                String ruleSubtitle;

                                if (selectedRuleType == 'App Time Limit' &&
                                    selectedApp != null) {
                                  ruleTitle = '$selectedApp Time Limit';
                                  ruleSubtitle =
                                      'Limited to $timeLimit minutes';
                                } else if (selectedRuleType ==
                                    'Daily Screen Time') {
                                  ruleTitle = 'Daily Screen Limit';
                                  ruleSubtitle = '$timeLimit minutes per day';
                                } else if (selectedRuleType == 'App Lock') {
                                  ruleTitle = 'App Lock';
                                  ruleSubtitle =
                                      'Full device lock - PIN required';
                                } else {
                                  ruleTitle = 'Bedtime Lock';
                                  ruleSubtitle = '10:00 PM - 7:00 AM';
                                }

                                // Update in database
                                final success = await SupabaseRules.updateRule(
                                  ruleId: rule['id'],
                                  title: ruleTitle,
                                  subtitle: ruleSubtitle,
                                  timeLimitMinutes: timeLimit,
                                );

                                if (success) {
                                  // Refresh rules from database
                                  await _fetchRulesFromDatabase();

                                  // Reload enforcement service
                                  // Parent dashboard - rules will auto-sync to child device
                                  print(
                                      '✅ Rule deleted - child device will update automatically');

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('✅ Rule updated successfully'),
                                        backgroundColor: Color(0xFF58C16D),
                                      ),
                                    );
                                    Navigator.of(context).pop();
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('❌ Failed to update rule'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF666666),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14.0),
                              elevation: 0,
                            ),
                            child: Text(
                              'Update Rule',
                              style: GoogleFonts.inter(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRuleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required Function(bool) onToggle,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: icon.fontFamily == 'FontAwesomeSolid' ||
                          icon.fontFamily == 'FontAwesomeBrands'
                      ? FaIcon(icon, color: const Color(0xFF1A1A1A), size: 24.0)
                      : Icon(icon, color: const Color(0xFF1A1A1A), size: 24.0),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isActive,
                  onChanged: onToggle,
                  activeColor: const Color(0xFF58C16D),
                  activeTrackColor: const Color(0xFF58C16D),
                  inactiveTrackColor: const Color(0xFFE0E0E0),
                  inactiveThumbColor: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18.0),
                    label: Text(
                      'Edit',
                      style: GoogleFonts.inter(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1A1A),
                      side: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                InkWell(
                  onTap: onDelete,
                  child: Container(
                    width: 44.0,
                    height: 44.0,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFEF5350),
                      size: 20.0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAppIcon(String appName) {
    switch (appName) {
      case 'Instagram':
        return FontAwesomeIcons.instagram;
      case 'Facebook':
        return FontAwesomeIcons.facebook;
      case 'Twitter':
        return FontAwesomeIcons.twitter;
      case 'TikTok':
        return FontAwesomeIcons.tiktok;
      case 'Snapchat':
        return FontAwesomeIcons.snapchat;
      case 'WhatsApp':
        return FontAwesomeIcons.whatsapp;
      case 'Telegram':
        return FontAwesomeIcons.telegram;
      case 'YouTube':
        return FontAwesomeIcons.youtube;
      case 'Netflix':
        return Icons.movie_outlined;
      case 'Spotify':
        return FontAwesomeIcons.spotify;
      case 'Chrome':
        return FontAwesomeIcons.chrome;
      case 'Safari':
        return FontAwesomeIcons.safari;
      default:
        return Icons.apps;
    }
  }

  List<String> _getAppsForCategory(String? category) {
    switch (category) {
      case 'Social Media':
        return ['Instagram', 'Facebook', 'Twitter', 'TikTok', 'Snapchat'];
      case 'Messaging':
        return ['WhatsApp', 'Telegram', 'Signal', 'Messenger'];
      case 'Entertainment':
        return ['YouTube', 'Netflix', 'Spotify', 'Prime Video'];
      case 'Gaming':
        return ['PUBG', 'Free Fire', 'Candy Crush', 'Clash of Clans'];
      case 'Browsers':
        return ['Chrome', 'Safari', 'Firefox', 'Edge'];
      default:
        return [];
    }
  }

  // Helper method to format time ago
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  Widget _buildLocationHistoryItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String duration,
    required String time,
  }) {
    return Row(
      children: [
        // Icon Container
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        // Location Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                duration,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        // Time
        Text(
          time,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRulesTab() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 0.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Dynamic Rule Cards
                  ...rules.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> rule = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < rules.length - 1 ? 16.0 : 0.0,
                      ),
                      child: _buildRuleCard(
                        icon: rule['icon'],
                        title: rule['title'],
                        subtitle: rule['subtitle'],
                        isActive: rule['isActive'],
                        onToggle: (value) async {
                          // Update in database
                          if (rule['id'] != null) {
                            final success = await SupabaseRules.toggleRule(
                              rule['id'],
                              value,
                            );

                            if (success) {
                              setState(() {
                                rules[index]['isActive'] = value;
                              });
                              // Reload rules on child device
                              await AppLockService().refreshLockedPackages();
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('❌ Failed to update rule'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        onEdit: () {
                          _showEditRuleDialog(index);
                        },
                        onDelete: () async {
                          // Delete from database
                          if (rule['id'] != null) {
                            final success =
                                await SupabaseRules.deleteRule(rule['id']);

                            if (success) {
                              setState(() {
                                rules.removeAt(index);
                              });
                              await AppLockService().refreshLockedPackages();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Rule deleted'),
                                    backgroundColor: Color(0xFF58C16D),
                                  ),
                                );
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('❌ Failed to delete rule'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    );
                  }),

                  if (rules.isNotEmpty) const SizedBox(height: 24.0),

                  // Add Rule Button
                  SizedBox(
                    width: MediaQuery.sizeOf(context).width,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showAddRuleDialog();
                      },
                      icon: const Icon(
                        Icons.add,
                        size: 24.0,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Add Rule',
                        style: GoogleFonts.inter(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppsTab() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _appSearchController,
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: Icon(Icons.search,
                    color: Theme.of(context).iconTheme.color),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
          ),
          Expanded(
            child: _isLoadingApps
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(color: Color(0xFF58C16D)),
                        SizedBox(height: 12),
                        Text('Loading apps...',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : _appsError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.apps,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _appsError!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _fetchInstalledApps,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try Again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF58C16D),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredApps.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.apps,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    _appSearchController.text.isNotEmpty
                                        ? 'No apps found matching "${_appSearchController.text}"'
                                        : 'No apps found',
                                    style: GoogleFonts.poppins(
                                        fontSize: 16, color: Colors.grey[600]),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _appSearchController.text.isNotEmpty
                                        ? 'Try a different search term'
                                        : 'Tap reload to refresh the app list',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: Colors.grey[500]),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _fetchInstalledApps,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Reload'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF58C16D),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredApps.length,
                            itemBuilder: (context, i) {
                              final app = _filteredApps[i];
                              final appName =
                                  app['appName']?.toString() ?? 'Unknown';
                              final packageName =
                                  (app['packageName'] as String?)?.trim() ?? '';

                              final rule = _getRuleForPackage(packageName,
                                  requireActive: false);
                              final isActive = rule != null &&
                                  ((rule['is_active'] ?? rule['isActive']) ==
                                      true);
                              final hasPin = _ruleHasPin(rule);

                              return ListTile(
                                leading: app['icon'] != null
                                    ? Image.memory(app['icon'], width: 40)
                                    : Icon(Icons.android,
                                        color:
                                            Theme.of(context).iconTheme.color),
                                title: Text(appName,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color)),
                                subtitle: Text(packageName,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color)),
                                onTap: () async {
                                  // open lock flow if you want whole-row tap to set lock
                                  await _onLockApp(app);
                                  // refresh rules AFTER the lock action completes
                                  await _fetchRulesFromDatabase();
                                  await AppLockService()
                                      .refreshLockedPackages();
                                  setState(() {}); // refresh UI
                                },
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch.adaptive(
                                      value: isActive,
                                      onChanged: hasPin
                                          ? (value) async {
                                              final success =
                                                  await SupabaseRules
                                                      .updateRuleActiveState(
                                                packageName: packageName,
                                                deviceId: widget.deviceId ?? '',
                                                activate: value,
                                              );
                                              if (success) {
                                                await _fetchRulesFromDatabase();
                                                await AppLockService()
                                                    .refreshLockedPackages();
                                              } else {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            'Failed to update lock state'),
                                                        backgroundColor:
                                                            Colors.red),
                                                  );
                                                }
                                              }
                                              setState(() {});
                                            }
                                          : null, // disabled if pin not set
                                      activeColor: const Color(0xFF58C16D),
                                    ),
                                    const SizedBox(width: 8),
                                    if (!hasPin) // Show Set PIN when no PIN is set
                                      ElevatedButton(
                                        onPressed: () async {
                                          await _onLockApp(app);
                                          await _fetchRulesFromDatabase();
                                          await AppLockService()
                                              .refreshLockedPackages();
                                          setState(() {});
                                        },
                                        child: const Text('Set PIN'),
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(72, 36),
                                          backgroundColor:
                                              const Color(0xFF666666),
                                        ),
                                      )
                                    else
                                      Icon(Icons.check_circle,
                                          color: const Color(0xFF58C16D),
                                          size: 20),
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

  // Return a rule for a package. If [requireActive] is true, only return an active rule.
  Map<String, dynamic>? _getRuleForPackage(String? packageName,
      {bool requireActive = false}) {
    if (packageName == null || packageName.isEmpty) return null;
    try {
      for (final r in rules) {
        final rt = (r['rule_type'] ?? r['rule_type'])?.toString();
        final pkg =
            (r['app_package_name'] ?? r['app_package_name'])?.toString();
        if (rt != 'App Lock') continue;
        if (pkg != packageName) continue;
        final active = (r['isActive'] ?? r['is_active']) == true;
        if (requireActive && !active) continue;
        return Map<String, dynamic>.from(r);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _ruleHasPin(Map<String, dynamic>? rule) {
    if (rule == null || rule.isEmpty) return false;
    // check multiple possible keys depending on how you stored it:
    final hasPinField = rule['app_lock_pin'] ??
        rule['appLockPin'] ??
        rule['app_lock_pin_set'] ??
        rule['appLockPinSet'] ??
        rule['pin_code'];
    if (hasPinField == null) return false;
    if (hasPinField is bool) return hasPinField;
    if (hasPinField is String) return hasPinField.trim().isNotEmpty;
    return true;
  }

  Future<String?> _showPinInputDialog(BuildContext context) async {
    final pinController = TextEditingController();
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Set App PIN', textAlign: TextAlign.center),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: '4-digit PIN',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final pin = pinController.text.trim();
                if (pin.length != 4 || int.tryParse(pin) == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('PIN must be 4 digits'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.of(ctx).pop(pin);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onLockApp(Map<String, dynamic> app) async {
    final appName = (app['appName'] ?? 'Unknown').toString();
    String? packageName = (app['packageName'] as String?)?.trim();

    if (packageName == null || packageName.isEmpty) {
      try {
        packageName = await SupabaseRules.getPackageName(appName);
      } catch (_) {
        packageName = null;
      }
    }

    if (widget.deviceId == null || widget.deviceId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('❌ No device selected'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Ask parent to set a PIN for this app
    final pin = await _showPinInputDialog(context);
    if (pin == null) return; // cancelled

    final supabase = Supabase.instance.client;
    final parentId = supabase.auth.currentUser?.id;
    if (parentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('❌ Please log in first'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('🔒 Adding app lock...'),
            duration: Duration(seconds: 1)),
      );
    }

    try {
      final success = await SupabaseRules.addRule(
        deviceId: widget.deviceId!,
        parentId: parentId,
        ruleType: 'App Lock',
        title: '$appName Lock',
        subtitle: 'App locked - PIN required',
        appCategory: null,
        appName: appName,
        appPackageName: packageName,
        timeLimitMinutes: 0,
        bedtimeStart: null,
        bedtimeEnd: null,
        isActive: true,
        appLockPin: pin,
      );

      if (mounted) {
        if (success) {
          await _fetchRulesFromDatabase();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ App locked successfully'),
                backgroundColor: Color(0xFF58C16D)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('❌ Failed to lock app'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e, st) {
      print('❌ Error adding app lock: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  IconData _getCallTypeIconData(String iconName) {
    switch (iconName) {
      case 'call_received':
        return Icons.call_received;
      case 'call_made':
        return Icons.call_made;
      case 'call_missed':
        return Icons.call_missed;
      case 'call_end':
        return Icons.call_end;
      case 'block':
        return Icons.block;
      case 'voicemail':
        return Icons.voicemail;
      case 'wifi_calling':
        return Icons.wifi_calling;
      case 'phone':
      default:
        return Icons.phone;
    }
  }

  Widget _buildCallsTab() {
    return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: RefreshIndicator(
          onRefresh: _fetchCallLogs,
          color: const Color(0xFF58C16D),
          child: Builder(
            builder: (context) {
              if (_isLoadingCallLogs) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  children: const [
                    SizedBox(height: 40),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF58C16D)),
                          SizedBox(height: 12),
                          Text('Loading call logs...',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    SizedBox(height: 400),
                  ],
                );
              }

              if (_callLogsError != null) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  children: [
                    const SizedBox(height: 40),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_missed,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _callLogsError!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _fetchCallLogs,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF58C16D),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 300),
                  ],
                );
              }

              if (_callLogs.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  children: [
                    const SizedBox(height: 40),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No call logs found',
                              style: GoogleFonts.poppins(
                                  fontSize: 16, color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Pull down to refresh or tap reload',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _fetchCallLogs,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reload'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF58C16D),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 300),
                  ],
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: _callLogs.length + 1,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_callLogs.length} Calls',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          if (_isLoadingCallLogs)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF58C16D),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  final call = _callLogs[index - 1];
                  final iconName =
                      (call['call_type_icon'] as String?) ?? 'phone';
                  final iconData = _getCallTypeIconData(iconName);
                  final callType = call['call_type'] as String? ?? 'Unknown';
                  final number = call['number'] as String? ?? 'Unknown';
                  final name = call['name'] as String? ?? 'Unknown';
                  final duration = call['duration'] is int
                      ? call['duration'] as int
                      : int.tryParse('${call['duration']}') ?? 0;

                  DateTime? timestamp;
                  final ts = call['timestamp'];
                  if (ts is DateTime) {
                    timestamp = ts;
                  } else if (ts is String) {
                    timestamp = DateTime.tryParse(ts);
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 0.0),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE8E8E8),
                      child: Icon(iconData, color: const Color(0xFF1A1A1A)),
                    ),
                    title: Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          number,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              CallLogsService.formatDuration(duration),
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CallLogsService.formatTimestamp(timestamp),
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          callType,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ));
  }

  Widget _buildLocationTab() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Map View',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'Configure Mapbox API key to view location on map',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            FFButtonWidget(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final deviceId = prefs.getString('deviceId');
                if (deviceId != null) {
                  await LocationTrackingService().startTracking(deviceId);
                  await LocationTrackingService().triggerLocationUpdate();
                }
              },
              text: 'Start Location Tracking',
              icon: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 20,
              ),
              options: FFButtonOptions(
                width: double.infinity,
                height: 50,
                color: const Color(0xFF58C16D),
                textStyle: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                elevation: 0,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(child: Text(title, style: const TextStyle(fontSize: 20)));
  }
}
