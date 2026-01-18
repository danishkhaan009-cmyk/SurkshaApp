import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'settings_widget.dart' show SettingsWidget;
import 'package:flutter/material.dart';

class SettingsModel extends FlutterFlowModel<SettingsWidget> {
  // PIN Change controllers
  final currentPinController = TextEditingController();
  final newPinController = TextEditingController();
  final confirmPinController = TextEditingController();

  // Profile controllers
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();

  bool isLoading = false;
  bool isProfileLoading = false;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    currentPinController.dispose();
    newPinController.dispose();
    confirmPinController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
  }
}
