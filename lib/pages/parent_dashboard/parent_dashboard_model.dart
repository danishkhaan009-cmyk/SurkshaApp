import 'dart:async';
import 'package:without_database/flutter_flow/flutter_flow_util.dart';
import 'package:without_database/index.dart';
import 'package:without_database/services/database_service.dart';
import 'package:without_database/services/device_status_service.dart';
import 'package:without_database/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parent_dashboard_widget.dart' show ParentDashboardWidget;
import 'package:flutter/material.dart';

class ParentDashboardModel extends FlutterFlowModel<ParentDashboardWidget> {
  List<Map<String, dynamic>> devices = [];
  bool isLoading = true;
  String? error;
  RealtimeChannel? _realtimeChannel;
  Timer? _refreshTimer;

  @override
  void initState(BuildContext context) {
    _loadDevices();
    _startRealtimeSubscription();
    // Also poll every 30s to catch stale-device transitions
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadDevices();
    });
  }

  Future<void> _loadDevices() async {
    try {
      final result = await DatabaseService.getUserDevices();
      devices = result;
      isLoading = false;
      error = null;
      updatePage(() {});
    } catch (e) {
      error = e.toString();
      isLoading = false;
      updatePage(() {});
    }
  }

  void _startRealtimeSubscription() {
    if (!AuthService.isLoggedIn) return;
    final userId = AuthService.currentUser!.id;

    _realtimeChannel = DeviceStatusService.subscribeToUserDevices(
      userId,
      (updatedDevices) {
        devices = updatedDevices;
        updatePage(() {});
      },
    );
  }

  /// Refresh devices manually (e.g. after delete)
  Future<void> refreshDevices() async {
    await _loadDevices();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _refreshTimer?.cancel();
  }
}
