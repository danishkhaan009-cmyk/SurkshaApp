// Language: dart
// File: lib/widgets/app_list_item.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'set_app_pin_dialog.dart';

class AppListItem extends StatefulWidget {
  final String appName;
  final String packageName;
  final String deviceId;
  final bool initiallyLocked;

  const AppListItem({
    super.key,
    required this.appName,
    required this.packageName,
    required this.deviceId,
    this.initiallyLocked = false,
  });

  @override
  State<AppListItem> createState() => _AppListItemState();
}

class _AppListItemState extends State<AppListItem> {
  bool _isLocked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.initiallyLocked;
  }

  Future<void> _enableLock() async {
    final result = await SetAppPinDialog.show(context, packageName: widget.packageName, deviceId: widget.deviceId);
    if (result == true) {
      setState(() { _isLocked = true; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App lock enabled')));
    } else {
      // user cancelled or failed; keep switch off
    }
  }

  Future<void> _disableLock() async {
    setState(() => _busy = true);
    try {
      final supabase = Supabase.instance.client;
      // RPC to deactivate/remove app lock rule for this device+package
      final resp = await supabase.rpc('app_lock_pin', params: {
        'device_id': widget.deviceId,
        'package_name': widget.packageName,
        'pin': '',
        'activate': false,
      });

      if (resp.error == null) {
        setState(() => _isLocked = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App lock disabled')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${resp.error!.message}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to disable lock')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onToggle(bool value) async {
    if (value) {
      await _enableLock();
    } else {
      await _disableLock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.apps),
      title: Text(widget.appName),
      subtitle: Text(widget.packageName),
      trailing: _busy
          ? const SizedBox(width: 48, height: 24, child: Center(child: CircularProgressIndicator()))
          : Switch(value: _isLocked, onChanged: _onToggle),
    );
  }
}
