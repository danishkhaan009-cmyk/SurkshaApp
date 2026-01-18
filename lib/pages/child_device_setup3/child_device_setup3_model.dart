import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'child_device_setup3_widget.dart' show ChildDeviceSetup3Widget;
import 'package:flutter/material.dart';

class ChildDeviceSetup3Model extends FlutterFlowModel<ChildDeviceSetup3Widget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for child info
  String? childName;
  String? childAge;

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
