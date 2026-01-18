import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
/// Supabase helper class for device rules
class SupabaseRules {
  static final supabase = Supabase.instance.client;
  static String _hashPin(String pin) {
    // simple SHA256; consider stronger storage (bcrypt) for production
    return sha256.convert(utf8.encode(pin)).toString();
  }

  /// Fetch all rules for a device
  static Future<List<Map<String, dynamic>>> getRulesForDevice(
      String deviceId) async {
    try {
      final response = await supabase
          .from('device_rules')
          .select()
          .eq('device_id', deviceId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching rules: $e');
      return [];
    }
  }

  /// Get parent's PIN from profile
  static Future<String?> getParentPin(String parentId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('pin')
          .eq('id', parentId)
          .single();

      return response['pin'] as String?;
    } catch (e) {
      print('❌ Error fetching parent PIN: $e');
      return null;
    }
  }


  static Future<bool> addRule({
    required String deviceId,
    required String parentId,
    required String ruleType,
    required String title,
    required String subtitle,
    String? appCategory,
    String? appName,
    String? appPackageName,
    int? timeLimitMinutes,
    String? bedtimeStart,
    String? bedtimeEnd,
    bool isActive = true,
    String? appLockPin,
  }) async {
    try {
      // Get parent's PIN from profile (required for all rules)
      String? pinCode = appLockPin;
      if (pinCode == null) {
        pinCode = await getParentPin(parentId);
        if (pinCode == null) {
          print('❌ Cannot create rule - parent PIN not found');
          return false;
        }
      }

      final payload = <String, dynamic>{
        'device_id': deviceId,
        'parent_id': parentId,
        'rule_type': ruleType,
        'title': title,
        'subtitle': subtitle,
        'app_category': appCategory,
        'app_name': appName,
        'app_package_name': appPackageName,
        'time_limit_minutes': timeLimitMinutes,
        'bedtime_start': bedtimeStart,
        'bedtime_end': bedtimeEnd,
        'is_active': isActive,
        'pin_code': pinCode,  // ← ADD THIS - Required for all rules
      };

      payload.removeWhere((k, v) => v == null);

      print('📤 Inserting rule: $payload');

      // Keep response dynamic so we can inspect runtime type safely
      final dynamic res =
      await supabase.from('device_rules').insert([payload]).select();

      if (res == null) {
        print('Supabase insert returned null response');
        return false;
      }

      // If SDK returned a list of inserted rows
      if (res is List) {
        if (res.isNotEmpty) {
          print('✅ Rule added successfully: ${res[0]}');
          return true;
        } else {
          print('Supabase insert returned an empty list');
          return false;
        }
      }

      // If SDK returned a Map-like response
      if (res is Map<String, dynamic>) {
        if (res['error'] != null) {
          print('Supabase insert error: ${res['error']}');
          return false;
        }

        final data = res['data'];
        if (data is List && data.isNotEmpty) return true;
        if (res.containsKey('id')) return true;

        print('Supabase Map response had no data/id: $res');
        return false;
      }

      // Fallback for unexpected shapes
      print('Supabase insert returned unexpected shape (${res.runtimeType}): $res');
      return false;
    } catch (e, st) {
      print('addRule exception: $e\n$st');
      return false;
    }
  }

 

  /// Update a rule
  static Future<bool> updateRule({
    required String ruleId,
    String? title,
    String? subtitle,
    bool? isActive,
    int? timeLimitMinutes,
    String? bedtimeStart,
    String? bedtimeEnd,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (title != null) updateData['title'] = title;
      if (subtitle != null) updateData['subtitle'] = subtitle;
      if (isActive != null) updateData['is_active'] = isActive;
      if (timeLimitMinutes != null) {
        updateData['time_limit_minutes'] = timeLimitMinutes;
      }
      if (bedtimeStart != null) updateData['bedtime_start'] = bedtimeStart;
      if (bedtimeEnd != null) updateData['bedtime_end'] = bedtimeEnd;

      await supabase.from('device_rules').update(updateData).eq('id', ruleId);

      print('✅ Rule updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating rule: $e');
      return false;
    }
  }

  /// Toggle rule active status
  static Future<bool> toggleRule(String ruleId, bool isActive) async {
    try {
      await supabase
          .from('device_rules')
          .update({'is_active': isActive}).eq('id', ruleId);

      print('✅ Rule toggled: $isActive');
      return true;
    } catch (e) {
      print('❌ Error toggling rule: $e');
      return false;
    }
  }

  /// Update the is_active state for rules matching deviceId + packageName
  /// If no rule exists for the given package+device, returns false.
  static Future<bool> updateRuleActiveState({
    required String deviceId,
    required String packageName,
    required bool activate,
  }) async {
    try {
      // Try to update rows matching device + package
      final res = await supabase
          .from('device_rules')
          .update({'is_active': activate})
          .eq('device_id', deviceId)
          .eq('app_package_name', packageName);

      // res may be a List of updated rows or a Map depending on client
      if (res == null) {
        print('updateRuleActiveState: update returned null');
        return false;
      }

      if (res is List) {
        if (res.isEmpty) {
          print('updateRuleActiveState: no matching rules to update');
          return false;
        }
        print('updateRuleActiveState: updated ${res.length} rule(s)');
        return true;
      }

      // Map-like response handling
      try {
        final data = (res as dynamic)['data'];
        if (data is List && data.isNotEmpty) return true;
      } catch (_) {}

      // fallback: treat non-empty response as success
      return true;
    } catch (e, st) {
      print('❌ Error updating rule active state: $e\n$st');
      return false;
    }
  }

  /// Delete a rule
  static Future<bool> deleteRule(String ruleId) async {
    try {
      await supabase.from('device_rules').delete().eq('id', ruleId);

      print('✅ Rule deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting rule: $e');
      return false;
    }
  }

  /// Get active rules for enforcement
  static Future<List<Map<String, dynamic>>> getActiveRules(
      String deviceId) async {
    try {
      print('🔍 === RULES QUERY DEBUG ===');
      print('   Querying for device_id: $deviceId');
      print('   Device ID type: ${deviceId.runtimeType}');
      print('   Device ID length: ${deviceId.length}');

      // First, check ALL rules in the table (for debugging)
      final allRules = await supabase.from('device_rules').select();
      print('   📊 Total rules in database: ${(allRules as List).length}');
      if (allRules.isNotEmpty) {
        print('   📋 All device_ids in database:');
        for (var rule in allRules) {
          print(
              '      - ${rule['device_id']} (title: ${rule['title']}, active: ${rule['is_active']})');
        }
      }

      // Now query for this specific device
      final response = await supabase
          .from('device_rules')
          .select()
          .eq('device_id', deviceId)
          .eq('is_active', true);

      print(
          '   ✅ Query returned ${(response as List).length} active rules for this device');

      // Debug: print each rule found
      for (var rule in response) {
        print(
            '   📦 Rule: ${rule['title']} | device_id: ${rule['device_id']} | is_active: ${rule['is_active']} | package: ${rule['package_name']}');
      }

      print('=========================');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching active rules: $e');
      return [];
    }
  }

  /// Get all available apps from app_packages table
  static Future<List<Map<String, dynamic>>> getAvailableApps(
      String category) async {
    try {
      final response = await supabase
          .from('app_packages')
          .select()
          .eq('category', category)
          .order('app_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching apps: $e');
      return [];
    }
  }

  /// Get package name for an app
  static Future<String?> getPackageName(String appName) async {
    try {
      final response = await supabase
          .from('app_packages')
          .select('package_name')
          .eq('app_name', appName)
          .single();

      return response['package_name'] as String?;
    } catch (e) {
      print('❌ Error fetching package name: $e');
      return null;
    }
  }

  /// Verify PIN for a rule
  static Future<bool> verifyRulePin(String ruleId, String enteredPin) async {
    try {
      final response = await supabase
          .from('device_rules')
          .select('pin_code')
          .eq('id', ruleId)
          .single();

      final storedPin = response['pin_code'] as String?;
      return storedPin == enteredPin;
    } catch (e) {
      print('❌ Error verifying PIN: $e');
      return false;
    }
  }


  // If you need to verify an app PIN later, fetch hashed pin and compare hash(input)
  static Future<bool> verifyAppPin(String ruleId, String inputPin) async {
    try {
      final rows = await supabase
          .from('device_rules')
          .select('app_lock_pin')
          .eq('id', ruleId)
          .limit(1);

      if (rows.isEmpty) return false;
      final storedHash = rows.first['app_lock_pin'] as String?;
      if (storedHash == null) return false;
      return _hashPin(inputPin) == storedHash;
    } catch (e) {
      print('SupabaseRules.verifyAppPin error: $e');
      return false;
    }
  }
}
