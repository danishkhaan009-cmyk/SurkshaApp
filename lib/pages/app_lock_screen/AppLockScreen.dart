// File: lib/pages/app_lock/app_lock_screen.dart
// Language: dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppLockScreen extends StatefulWidget {
  final String packageName;
  final String? deviceId;
  final VoidCallback? onUnlock;

  const AppLockScreen({super.key, required this.packageName, this.deviceId, this.onUnlock});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() { _error = 'PIN must be 4 digits'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      // Call your server helper to verify/pair PIN for this device+package.
      // Example RPC / function `verify_app_lock_pin` returning boolean.
      final supabase = Supabase.instance.client;
      final resp = await supabase.rpc('verify_app_lock_pin', params: {
        'device_id': widget.deviceId,
        'package_name': widget.packageName,
        'pin': pin,
      });

      final ok = resp.error == null && resp.data == true;
      if (ok) {
        widget.onUnlock?.call();
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() { _error = 'Incorrect PIN'; });
      }
    } catch (e) {
      setState(() { _error = 'Verification failed'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('App Locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Enter 4-digit PIN to open ${widget.packageName}'),
              const SizedBox(height: 12),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(counterText: ''),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _verifyPin,
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
