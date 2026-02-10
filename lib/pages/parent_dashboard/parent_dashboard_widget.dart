import 'package:without_database/flutter_flow/flutter_flow_util.dart';
import 'package:without_database/index.dart';
import 'package:without_database/services/database_service.dart';
import 'package:without_database/services/device_status_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'parent_dashboard_model.dart';
export 'parent_dashboard_model.dart';

class ParentDashboardWidget extends StatefulWidget {
  const ParentDashboardWidget({super.key});

  static String routeName = 'Parent_Dashboard';
  static String routePath = '/parentDashboard';

  @override
  State<ParentDashboardWidget> createState() => _ParentDashboardWidgetState();
}

class _ParentDashboardWidgetState extends State<ParentDashboardWidget> {
  late ParentDashboardModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ParentDashboardModel());
    // Wire up model updates to trigger widget rebuilds
    _model.setOnUpdate(
      onUpdate: () {
        if (mounted) setState(() {});
      },
      updateOnChange: true,
    );
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
          toolbarHeight: 70,
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
                  context.pushNamed(SelectModeWidget.routeName);
                },
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Good Evening, Parent',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Builder(
                builder: (context) {
                  final deviceCount = _model.devices.length;
                  final activeCount = _model.devices
                      .where((d) => DeviceStatusService.isDeviceActive(d))
                      .length;
                  return Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: activeCount > 0
                              ? const Color(0xFF58C16D)
                              : Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$activeCount of $deviceCount device${deviceCount != 1 ? 's' : ''} active',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Builder(
            builder: (context) {
              if (_model.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_model.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Error loading devices: ${_model.error}',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                );
              }

              final devices = _model.devices;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Add Child Device Button
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF58C16D),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF58C16D).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            context.pushNamed(LinkChildDeviceWidget.routeName);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 18.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Add Child Device',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28.0),

                    // Connected Devices
                    if (devices.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60.0),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.devices_other_outlined,
                                  size: 56,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No devices connected',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add a child device to get started',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 16),
                            child: Text(
                              'Connected Devices',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          ...devices.map((device) => Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.08),
                                        blurRadius: 20,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        context.pushNamed(
                                          ChildsDeviceWidget.routeName,
                                          queryParameters: {
                                            'deviceId': device['id'] ?? '',
                                            'childName':
                                                device['child_name'] ?? 'Child',
                                            'childAge':
                                                (device['child_age'] ?? 12)
                                                    .toString(),
                                          }.withoutNulls,
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF58C16D),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  child: const Icon(
                                                    Icons.person_rounded,
                                                    color: Colors.white,
                                                    size: 28,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        device['child_name'] ??
                                                            'Child Device',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: const Color(
                                                              0xFF1A1A1A),
                                                          letterSpacing: -0.5,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.cake_outlined,
                                                            size: 14,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            '${device['child_age'] ?? 'N/A'} years old',
                                                            style: GoogleFonts
                                                                .inter(
                                                              fontSize: 13,
                                                              color: Colors
                                                                  .grey[600],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () async {
                                                    await _showDeleteDialog(
                                                        context, device);
                                                  },
                                                  icon: Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red[400],
                                                    size: 24,
                                                  ),
                                                  tooltip: 'Delete device',
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF8F9FA),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Icon(
                                                    Icons.arrow_forward_ios,
                                                    size: 16,
                                                    color: Colors.grey[400],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Builder(
                                              builder: (context) {
                                                final isActive =
                                                    DeviceStatusService
                                                        .isDeviceActive(device);
                                                // Prefer last_active (guaranteed column)
                                                final lastActiveStr = (device[
                                                            'last_active']
                                                        as String?) ??
                                                    (device['last_active_at']
                                                        as String?);
                                                String statusText;
                                                if (isActive) {
                                                  statusText = 'Active Now';
                                                } else if (lastActiveStr !=
                                                    null) {
                                                  try {
                                                    final lastActive =
                                                        DateTime.parse(
                                                            lastActiveStr);
                                                    final elapsed =
                                                        DateTime.now()
                                                            .toUtc()
                                                            .difference(
                                                                lastActive);
                                                    if (elapsed.inMinutes <
                                                        60) {
                                                      statusText =
                                                          'Last seen ${elapsed.inMinutes}m ago';
                                                    } else if (elapsed.inHours <
                                                        24) {
                                                      statusText =
                                                          'Last seen ${elapsed.inHours}h ago';
                                                    } else {
                                                      statusText = 'Inactive';
                                                    }
                                                  } catch (e) {
                                                    statusText = 'Inactive';
                                                  }
                                                } else {
                                                  statusText =
                                                      'Never connected';
                                                }
                                                return Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isActive
                                                        ? const Color(
                                                            0xFFE8F5E9)
                                                        : const Color(
                                                            0xFFFFF3E0),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: isActive
                                                              ? const Color(
                                                                  0xFF58C16D)
                                                              : const Color(
                                                                  0xFFFF9800),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        statusText,
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: isActive
                                                              ? const Color(
                                                                  0xFF58C16D)
                                                              : const Color(
                                                                  0xFFFF9800),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(
      BuildContext context, Map<String, dynamic> device) async {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_outlined,
                  color: Colors.red[400],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Delete Device',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${device['child_name']}"\'s device?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This action cannot be undone.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xFF666666),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _deleteDevice(device);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteDevice(Map<String, dynamic> device) async {
    try {
      await DatabaseService.deleteDevice(device['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Device deleted successfully',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF58C16D),
            duration: const Duration(seconds: 2),
          ),
        );

        // Refresh the page
        await _model.refreshDevices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete device: ${e.toString()}',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
