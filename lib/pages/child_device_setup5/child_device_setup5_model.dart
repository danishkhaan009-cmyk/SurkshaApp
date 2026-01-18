import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'child_device_setup5_widget.dart' show ChildDeviceSetup5Widget;
import 'package:flutter/material.dart';

class ChildDeviceSetup5Model extends FlutterFlowModel<ChildDeviceSetup5Widget> {
  final pinController = TextEditingController();
  bool isLoading = false;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    pinController.dispose();
  }
}
