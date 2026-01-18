// Language: dart
// File: lib/widgets/set_app_pin_dialog.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SetAppPinDialog extends StatefulWidget {
  final String packageName;
  final String deviceId;

  const SetAppPinDialog({super.key, required this.packageName, required this.deviceId});

  /// Returns `true` when PIN was set and lock activated, otherwise `false` or `null`.
  static Future<bool?> show(BuildContext context, {required String packageName, required String deviceId}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(child: SetAppPinDialog(packageName: packageName, deviceId: deviceId)),
    );
  }

  @override
  State<SetAppPinDialog> createState() => _SetAppPinDialogState();
}

class _SetAppPinDialogState extends State<SetAppPinDialog> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    final conf = _confirmCtrl.text.trim();
    if (pin.length != 4 || conf.length != 4) {
      setState(() => _error = 'PIN must be 4 digits');
      return;
    }
    if (pin != conf) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final supabase = Supabase.instance.client;
      // Server RPC should hash and store the PIN securely and activate the rule.
      final resp = await supabase.rpc('app_lock_pin', params: {
        'device_id': widget.deviceId,
        'package_name': widget.packageName,
        'pin': pin,
        'activate': true,
      });

      if (resp.error == null) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => _error = resp.error!.message);
      }
    } catch (e) {
      setState(() => _error = 'Failed to set PIN');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Set PIN for ${widget.packageName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(labelText: '4-digit PIN', counterText: ''),
        ),
        TextField(
          controller: _confirmCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(labelText: 'Confirm PIN', counterText: ''),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
        ]),
      ]),
    );
  }
}
