import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:without_database/flutter_flow/flutter_flow_theme.dart';
import 'package:without_database/flutter_flow/flutter_flow_util.dart';
import 'package:without_database/flutter_flow/flutter_flow_widgets.dart';
import 'forgot_password_model.dart';
export 'forgot_password_model.dart';

class ForgotPasswordWidget extends StatefulWidget {
  const ForgotPasswordWidget({super.key});

  static String routeName = 'Forgot_Password';
  static String routePath = '/forgotPassword';

  @override
  State<ForgotPasswordWidget> createState() => _ForgotPasswordWidgetState();
}

class _ForgotPasswordWidgetState extends State<ForgotPasswordWidget> {
  late ForgotPasswordModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ForgotPasswordModel());
    _model.emailController ??= TextEditingController();
    _model.emailFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  /// Generates a random 8-digit numeric password
  String _generatePassword() {
    final random = Random.secure();
    final code = List.generate(8, (_) => random.nextInt(10)).join();
    return code;
  }

  /// Handles the password reset flow
  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _model.isLoading = true);

    final email = _model.emailController!.text.trim();
    final newPassword = _generatePassword();
    final supabase = Supabase.instance.client;

    try {
      // Step 1: Call Supabase RPC to verify email & update password
      final response = await supabase.rpc('reset_user_password', params: {
        'user_email': email,
        'new_password': newPassword,
      });

      if (response is Map && response['success'] == false) {
        throw Exception(response['error'] ?? 'Failed to reset password');
      }

      // Step 2: Send email with new password via Supabase Edge Function
      try {
        await supabase.functions.invoke(
          'send-password-email',
          body: {'email': email, 'password': newPassword},
        );
      } catch (emailError) {
        debugPrint('Email send failed: $emailError');
      }

      if (!mounted) return;

      // Show simple success message — no password shown
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EEE5),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.check_circle_outlined,
                  color: Color(0xFF58C16D),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Password Reset Successful',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your updated password has been sent to your registered email address.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6B6B6B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.pushNamed('Login_Screen');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Text(
                  'Go to Login',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message.contains('not found')
                ? 'No account found with this email address.'
                : 'Something went wrong. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _model.isLoading = false);
    }
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
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 1.0,
                  height: MediaQuery.sizeOf(context).height * 1.0,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF6F6F6),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // Top spacing
                        const SizedBox(height: 16),

                        // Back button row
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  20, 0, 0, 0),
                              child: InkWell(
                                onTap: () => context.safePop(),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10.0),
                                    border: Border.all(
                                      color: const Color(0xFFE3E3E3),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Color(0xFF1A1A1A),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Shield icon — same as login screen
                        Container(
                          width: 80.0,
                          height: 80.0,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: Colors.white,
                            size: 60.0,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // App name
                        Text(
                          'SurakshaApp',
                          textAlign: TextAlign.center,
                          style: FlutterFlowTheme.of(context)
                              .headlineLarge
                              .override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: Colors.black,
                                fontSize: 20.0,
                                letterSpacing: 0.0,
                              ),
                        ),

                        // Subtitle
                        Text(
                          'Reset Your Password',
                          style:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                    ),
                                    color: const Color(0xFF6B6B6B),
                                    letterSpacing: 0.0,
                                    lineHeight: 1.3,
                                  ),
                        ),

                        const SizedBox(height: 20),

                        // Info banner — same style as login screen's green banner
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Align(
                              alignment: const AlignmentDirectional(0.0, 0.0),
                              child: Container(
                                width: MediaQuery.sizeOf(context).width * 0.9,
                                height: 80.0,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5EEE5),
                                  borderRadius: BorderRadius.circular(10.0),
                                  border: Border.all(
                                    color: const Color(0xFFD4E7D4),
                                    width: 1.0,
                                  ),
                                ),
                                child: Align(
                                  alignment:
                                      const AlignmentDirectional(0.0, 0.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Container(
                                        width: 40.0,
                                        height: 40.0,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF58C16D),
                                          borderRadius:
                                              BorderRadius.circular(10.0),
                                        ),
                                        child: const Icon(
                                          Icons.email_outlined,
                                          color: Colors.white,
                                          size: 24.0,
                                        ),
                                      ),
                                      Flexible(
                                        child: Padding(
                                          padding: const EdgeInsetsDirectional
                                              .fromSTEB(0.0, 0.0, 10.0, 0.0),
                                          child: Text(
                                            'Enter your email and we\'ll send a new password to your inbox',
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontWeight,
                                                  ),
                                                  color:
                                                      const Color(0xFF6B6B6B),
                                                  fontSize: 14.0,
                                                  letterSpacing: 0.0,
                                                  lineHeight: 1.5,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ]
                                        .divide(const SizedBox(width: 14.0))
                                        .addToStart(const SizedBox(width: 14.0))
                                        .addToEnd(const SizedBox(width: 0.0)),
                                  ),
                                ),
                              ),
                            ),
                          ]
                              .divide(const SizedBox(width: 20.0))
                              .around(const SizedBox(width: 20.0)),
                        ),

                        const SizedBox(height: 20),

                        // White card container — same as login screen
                        Align(
                          alignment: const AlignmentDirectional(0.0, 0.0),
                          child: Container(
                            width: MediaQuery.sizeOf(context).width * 0.9,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                const SizedBox(height: 20),

                                // Email input — matches login screen style
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Expanded(
                                      child: Form(
                                        key: _formKey,
                                        child: SizedBox(
                                          width: 200.0,
                                          child: TextFormField(
                                            controller: _model.emailController,
                                            focusNode: _model.emailFocusNode,
                                            autofocus: false,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            textInputAction:
                                                TextInputAction.done,
                                            onFieldSubmitted: (_) =>
                                                _handleResetPassword(),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Please enter your email address';
                                              }
                                              final emailRegex = RegExp(
                                                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                              if (!emailRegex
                                                  .hasMatch(value.trim())) {
                                                return 'Please enter a valid email address';
                                              }
                                              return null;
                                            },
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'Email',
                                              labelStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                        ),
                                                        letterSpacing: 0.0,
                                                      ),
                                              hintText:
                                                  'Enter Your Registered Email',
                                              hintStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                        ),
                                                        letterSpacing: 0.0,
                                                      ),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE3E3E3),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10.0),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: const BorderSide(
                                                  color: Color(0xFF1A1A1A),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10.0),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10.0),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10.0),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.poppins(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontWeight,
                                                  ),
                                                  letterSpacing: 0.0,
                                                ),
                                            cursorColor:
                                                FlutterFlowTheme.of(context)
                                                    .primaryText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]
                                      .divide(const SizedBox(width: 10.0))
                                      .around(const SizedBox(width: 10.0)),
                                ),

                                const SizedBox(height: 20),

                                // Send button — matches login button style
                                FFButtonWidget(
                                  onPressed: _model.isLoading
                                      ? null
                                      : () => _handleResetPassword(),
                                  text: _model.isLoading
                                      ? 'Sending...'
                                      : 'Send New Password',
                                  options: FFButtonOptions(
                                    width: 326.72,
                                    height: 55.0,
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            16.0, 0.0, 16.0, 0.0),
                                    iconPadding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            0.0, 0.0, 0.0, 0.0),
                                    color: const Color(0xFF1A1A1A),
                                    textStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                          ),
                                          color: Colors.white,
                                          fontSize: 16.0,
                                          letterSpacing: 0.0,
                                        ),
                                    elevation: 0.0,
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),

                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Back to login link
                        InkWell(
                          onTap: () => context.pushNamed('Login_Screen'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.arrow_back_rounded,
                                color: Color(0xFF1A1A1A),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Back to Login',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF1A1A1A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
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
}
