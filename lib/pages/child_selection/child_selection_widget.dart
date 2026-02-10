import 'package:without_database/flutter_flow/flutter_flow_util.dart';
import 'package:without_database/index.dart';
import 'package:without_database/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Screen to select which child profile to enter child mode for
class ChildSelectionWidget extends StatefulWidget {
  const ChildSelectionWidget({super.key});

  static String routeName = 'Child_Selection';
  static String routePath = '/childSelection';

  @override
  State<ChildSelectionWidget> createState() => _ChildSelectionWidgetState();
}

class _ChildSelectionWidgetState extends State<ChildSelectionWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

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
          title: Text(
            'Select Child Profile',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Text
                  Text(
                    'Choose which child profile to activate',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Device List
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: DatabaseService.getUserDevices(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(
                              color: Color(0xFF58C16D),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading devices',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.red[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final devices = snapshot.data ?? [];

                      if (devices.isEmpty) {
                        return Center(
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
                                    Icons.person_off_outlined,
                                    size: 56,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'No child profiles found',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Set up a child device first',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    context.pushNamed(
                                        ChildDeviceSetup1Widget.routeName);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF58C16D),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    'Set Up Child Device',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Show child cards
                      return Column(
                        children: devices.map((device) {
                          return Padding(
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
                                    // Navigate to setup5 with device info
                                    context.pushNamed(
                                      ChildDeviceSetup5Widget.routeName,
                                      queryParameters: {
                                        'deviceId': device['id'] ?? '',
                                        'childName':
                                            device['child_name'] ?? 'Child',
                                        'childAge': (device['child_age'] ?? 12)
                                            .toString(),
                                        'pairingCode':
                                            device['pairing_code'] ?? '',
                                        'isReentry':
                                            'true', // Flag to indicate re-entry mode
                                      }.withoutNulls,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF58C16D),
                                                Color(0xFF4CAF50),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF58C16D)
                                                    .withOpacity(0.3),
                                                blurRadius: 12,
                                                spreadRadius: 0,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.person_rounded,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Child Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                device['child_name'] ?? 'Child',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xFF1A1A1A),
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.cake_outlined,
                                                    size: 15,
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '${device['child_age'] ?? 'N/A'} years old',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF58C16D)
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'Tap to activate',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    color:
                                                        const Color(0xFF58C16D),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Arrow Icon
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8F9FA),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.arrow_forward_ios,
                                            size: 18,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // New Device Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF58C16D).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          context.pushNamed(ChildDeviceSetup1Widget.routeName);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_circle_outline,
                                color: Color(0xFF58C16D),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Set Up New Child Device',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF58C16D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
