import 'package:supabase_flutter/supabase_flutter.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/services/child_mode_service.dart';
import '/services/permission_service.dart';
import 'splash_screen_model.dart';
export 'splash_screen_model.dart';

class SplashScreenWidget extends StatefulWidget {
  const SplashScreenWidget({super.key});

  static String routeName = 'SplashScreen';
  static String routePath = '/splashScreen';

  @override
  State<SplashScreenWidget> createState() => _SplashScreenWidgetState();
}

class _SplashScreenWidgetState extends State<SplashScreenWidget> {
  late SplashScreenModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SplashScreenModel());

    // Check application state after a short delay for branding
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAppState());
  }

  Future<void> _checkAppState() async {
    print('🚀 SplashScreen: Checking app state...');
    
    // Give Supabase and local storage a moment to initialize
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      // 1. Check for Child Mode (Highest Priority)
      final isChildMode = await ChildModeService.isChildModeActive();
      print('🔍 Is Child Mode Active: $isChildMode');
      
      if (isChildMode) {
        // IMPORTANT: Verify Accessibility Service is enabled if in child mode
        final isAccessibilityEnabled = await PermissionService.isAccessibilityEnabled();
        print('🔍 Accessibility Enabled: $isAccessibilityEnabled');
        
        if (!isAccessibilityEnabled && mounted) {
          // Force user to enable accessibility if it's off
          await _showAccessibilityPrompt();
        }

        final deviceId = await ChildModeService.getChildDeviceId();
        print('📱 Child Device ID: $deviceId');
        
        if (deviceId != null && mounted) {
          // If in child mode, go to the permission/monitoring screen
          context.goNamed(
            ChildDeviceSetup5Widget.routeName,
            queryParameters: {
              'deviceId': deviceId,
              'isReentry': 'true',
            },
          );
          return;
        }
      }

      // 2. Auth Session Check for Parents
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        print('🏠 SplashScreen: Parent session found. Navigating to Dashboard...');
        if (mounted) context.goNamed(ParentDashboardWidget.routeName);
        return;
      }

      // 3. Normal Flow: Go to Login
      print('🔐 SplashScreen: No session. Navigating to Login_Screen...');
      if (mounted) context.goNamed(LoginScreenWidget.routeName);
      
    } catch (e) {
      print('❌ SplashScreen Error: $e');
      if (mounted) {
        context.goNamed(LoginScreenWidget.routeName);
      }
    }
  }

  Future<void> _showAccessibilityPrompt() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Action Required'),
        content: const Text(
          'To keep app locking active, SurakshaApp needs its Accessibility Service enabled.\n\nPlease enable it in the next screen.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.requestAccessibilityPermission();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B242)),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFF00B242),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF00B242),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100.0,
              height: 100.0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  )
                ],
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Color(0xFF00B242),
                size: 70.0,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'SurakshaApp',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your Digital Safety Partner',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
