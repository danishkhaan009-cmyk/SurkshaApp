import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/child_mode_service.dart';
import '/services/location_tracking_service.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'app_lock_screen_model.dart';
export 'app_lock_screen_model.dart';

class AppLockScreenWidget extends StatefulWidget {


  const AppLockScreenWidget({super.key});


  static const routePath = '/appLockScreen';
  static const routeName = 'App_Lock_Screen';


  @override
  State<AppLockScreenWidget> createState() => _AppLockScreenWidgetState();
}

class _AppLockScreenWidgetState extends State<AppLockScreenWidget> {
  late AppLockScreenModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();



  @override
  void initState() {
    super.initState();

    // App Lock screen should NEVER appear on web platform
    // Redirect back if accidentally navigated here on web
    if (kIsWeb) {
      print('⚠️ App Lock screen accessed on web - redirecting back');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
      return;
    }

    _model = createModel(context, () => AppLockScreenModel());
    _model.pinController = TextEditingController();

    // Prevent back button
    SystemChannels.platform.setMethodCallHandler((call) async {
      if (call.method == 'SystemNavigator.pop') {
        // Block back button
        return;
      }
    });
  }

  @override
  void dispose() {
    _model.dispose();
    SystemChannels.platform.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final enteredPin = _model.pinController.text.trim();

    if (enteredPin.length != 4) {
      _showError('Please enter 4-digit PIN');
      return;
    }

    // Fetch current PIN from database (not local storage)
    // This ensures we use the latest PIN even if parent changed it
    String? correctPin;
    try {
      final deviceId = await ChildModeService.getChildDeviceId();
      if (deviceId == null) {
        _showError('Device not found');
        return;
      }

      final supabase = Supabase.instance.client;

      // Get parent ID from device
      final deviceResponse = await supabase
          .from('devices')
          .select('user_id')
          .eq('id', deviceId)
          .single();

      final userId = deviceResponse['user_id'] as String?;
      if (userId == null) {
        _showError('Parent not found');
        return;
      }

      // Get current PIN from parent's profile
      final profileResponse = await supabase
          .from('profiles')
          .select('pin')
          .eq('id', userId)
          .single();

      correctPin = profileResponse['pin'] as String?;

      // Trim whitespace from database PIN
      if (correctPin != null) {
        correctPin = correctPin.trim();
      }

      if (correctPin == null || correctPin.isEmpty) {
        _showError('No PIN set in parent account');
        return;
      }

      // Debug logging
      print('🔐 PIN Verification Debug:');
      print('   Device ID: $deviceId');
      print('   User ID: $userId');
      print('   Entered PIN: $enteredPin');
      print('   Correct PIN: $correctPin');
      print('   Match: ${enteredPin == correctPin}');
    } catch (e) {
      print('❌ Error fetching PIN: $e');
      _showError('Error fetching PIN: ${e.toString()}');
      return;
    }

    if (enteredPin == correctPin) {
      // Correct PIN - deactivate child mode
      try {
        // Stop location tracking
        final deviceId = await ChildModeService.getChildDeviceId();
        if (deviceId != null) {
          await LocationTrackingService().stopTracking();
        } // Deactivate child mode
        await ChildModeService.deactivateChildMode();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Child mode deactivated - Device unlocked'),
              backgroundColor: Color(0xFF58C16D),
              duration: Duration(seconds: 2),
            ),
          );

          // Navigate to parent dashboard
          context.goNamed('Parent_Dashboard');
        }
      } catch (e) {
        _showError('Error unlocking: ${e.toString()}');
      }
    } else {
      // Wrong PIN - shake animation and clear
      _model.pinController.clear();
      _showError('❌ Incorrect PIN - Try again');

      // Vibrate if available
      HapticFeedback.heavyImpact();
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Web platform check - show error message
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F1419),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_rounded,
                color: Colors.orange,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'App Lock Not Available',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'App Lock only works on Android devices with the APK installed.\nThis feature is not available on web.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFF0F1419),
        body: SafeArea(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F1419),
                  Color(0xFF1A2332),
                ],
                stops: [0.0, 1.0],
                begin: AlignmentDirectional(0.0, -1.0),
                end: AlignmentDirectional(0, 1.0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3441),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFF58C16D),
                    size: 60,
                  ),
                ),

                const SizedBox(height: 40),

                // Title
                Text(
                  'Device Locked',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'This device is in child mode.\nEnter parent PIN to unlock.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // PIN Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A3441),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 15,
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: _model.pinController,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 24,
                          letterSpacing: 8,
                        ),
                        counterText: '',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onSubmitted: (_) => _verifyPin(),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Unlock Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton(
                    onPressed: _verifyPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF58C16D),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      'Unlock Device',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Info Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    '🔒 Apps and settings are restricted',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
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
}
