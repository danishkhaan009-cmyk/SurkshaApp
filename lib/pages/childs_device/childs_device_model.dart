import '/flutter_flow/flutter_flow_util.dart';
import 'childs_device_widget.dart' show ChildsDeviceWidget;
import 'package:flutter/material.dart';

class ChildsDeviceModel extends FlutterFlowModel<ChildsDeviceWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // State field(s) for Switch widget.
  bool? switchValue;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    tabBarController?.dispose();
  }
}
