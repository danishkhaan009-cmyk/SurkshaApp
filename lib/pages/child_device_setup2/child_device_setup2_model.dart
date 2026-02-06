import 'package:without_database/flutter_flow/flutter_flow_util.dart';
import 'package:without_database/index.dart';
import 'child_device_setup2_widget.dart' show ChildDeviceSetup2Widget;
import 'package:flutter/material.dart';

class ChildDeviceSetup2Model extends FlutterFlowModel<ChildDeviceSetup2Widget> {
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
