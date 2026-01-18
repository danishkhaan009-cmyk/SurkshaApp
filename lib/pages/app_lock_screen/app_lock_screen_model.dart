import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

class AppLockScreenModel extends FlutterFlowModel {
  late TextEditingController pinController;

  @override
  void initState(BuildContext context) {
    pinController = TextEditingController();
  }

  @override
  void dispose() {
    pinController.dispose();
  }
}
