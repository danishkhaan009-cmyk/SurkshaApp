import 'package:without_database/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:without_database/services/database_service.dart';
import 'alert_model.dart';
export 'alert_model.dart';

class AlertWidget extends StatefulWidget {
  const AlertWidget({super.key});

  static String routeName = 'Alert';
  static String routePath = '/alert';

  @override
  State<AlertWidget> createState() => _AlertWidgetState();
}

class _AlertWidgetState extends State<AlertWidget> {
  late AlertModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AlertModel());
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      // Fetch all alerts (not just unread) to debug
      final alerts = await DatabaseService.getUnreadAlerts();
      print('Loaded ${alerts.length} alerts');

      setState(() {
        _model.alerts = alerts;
        _model.isLoading = false;
      });
    } catch (e) {
      print('Error loading alerts: $e');
      setState(() {
        _model.isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load alerts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _model.dispose();
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
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: Color(0xFF1A1A1A),
                ),
                onPressed: () {
                  context.safePop();
                },
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safety Alerts',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Monitor and review safety concerns',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Free',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: _model.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _model.alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No alerts yet',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All safety alerts will appear here',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAlerts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20.0),
                        itemCount: _model.alerts.length,
                        itemBuilder: (context, index) {
                          final alert = _model.alerts[index];
                          return _buildAlertCard(alert, index);
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, int index) {
    final alertType = alert['alert_type'] ?? 'unknown';
    final message = alert['alert_message'] ?? 'No message';
    final createdAt = alert['created_at'] != null
        ? DateTime.parse(alert['created_at'])
        : DateTime.now();

    // Get alert icon and color based on type
    IconData icon;
    Color iconColor;
    Color bgColor;

    switch (alertType) {
      case 'child_mode_exit':
        icon = Icons.exit_to_app;
        iconColor = const Color(0xFF2196F3);
        bgColor = const Color(0xFFE3F2FD);
        break;
      case 'inappropriate_content':
        icon = Icons.remove_red_eye_outlined;
        iconColor = const Color(0xFFFF9800);
        bgColor = const Color(0xFFFFF3E0);
        break;
      case 'excessive_usage':
        icon = Icons.timer_outlined;
        iconColor = const Color(0xFFF44336);
        bgColor = const Color(0xFFFFEBEE);
        break;
      case 'app_blocked':
        icon = Icons.block;
        iconColor = const Color(0xFF9C27B0);
        bgColor = const Color(0xFFF3E5F5);
        break;
      default:
        icon = Icons.info_outline;
        iconColor = const Color(0xFF607D8B);
        bgColor = const Color(0xFFECEFF1);
    }

    return Padding(
      padding:
          EdgeInsets.only(bottom: index < _model.alerts.length - 1 ? 16 : 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getAlertTitle(alertType, message),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getAlertSubtitle(alertType, message),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (alertType == 'child_mode_exit')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Info',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAlertTitle(String alertType, String message) {
    // For child_mode_exit, extract child name from message
    if (alertType == 'child_mode_exit') {
      // Message format: "childName exited child mode"
      final parts = message.split(' exited child mode');

      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        return parts[0]; // Return child name
      }
      return 'Child Mode Exited';
    }

    switch (alertType) {
      case 'inappropriate_content':
        return 'Inappropriate Content Detected';
      case 'excessive_usage':
        return 'Excessive Screen Time';
      case 'app_blocked':
        return 'Blocked App Access';
      default:
        return 'Safety Alert';
    }
  }

  String _getAlertSubtitle(String alertType, String message) {
    // For child_mode_exit, show "exited child mode"
    if (alertType == 'child_mode_exit') {
      return 'exited child mode';
    }

    // For other types, show the full message
    return message;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
