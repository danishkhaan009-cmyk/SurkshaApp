import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'link_child_device_widget.dart' show LinkChildDeviceWidget;
import 'package:flutter/material.dart';

class LinkChildDeviceModel extends FlutterFlowModel<LinkChildDeviceWidget> {
  ///  State fields for stateful widgets in this page.

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
