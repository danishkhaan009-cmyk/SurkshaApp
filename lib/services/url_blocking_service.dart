import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// Service to handle URL blocking enforcement on child devices
class UrlBlockingService {
  static final UrlBlockingService _instance = UrlBlockingService._internal();
  factory UrlBlockingService() => _instance;
  UrlBlockingService._internal();

  static const platform = MethodChannel('parental_control/permissions');

  // Cached blocked URLs for quick lookup
  Set<String> _blockedUrls = {};
  Set<String> _blockedDomains = {};
  String? _deviceId;
  Timer? _syncTimer;
  bool _isInitialized = false;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Get all blocked URLs
  Set<String> get blockedUrls => _blockedUrls;

  /// Initialize the URL blocking service for a device
  Future<void> initialize(String deviceId) async {
    _deviceId = deviceId;
    print('🔒 Initializing URL Blocking Service for device: $deviceId');
    await _loadBlockedUrls();
    await _initializeNativeService();
    // Force immediate sync after initialization
    await _syncNative();
    _setupRealtimeSubscription();
    _startPeriodicSync();
    _isInitialized = true;
    print(
        '🔒 URL Blocking Service initialized with ${_blockedUrls.length} URLs');
  }

  /// Initialize the native Android URL blocking service
  Future<void> _initializeNativeService() async {
    try {
      // Hardcode the Supabase credentials since headers might not have them
      const supabaseUrl = 'https://myxdypywnifdsaorlhsy.supabase.co';
      const supabaseKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8';

      print('🔑 Initializing native URL service with deviceId: $_deviceId');
      print('🔑 Supabase URL: $supabaseUrl');
      print('🔑 Key length: ${supabaseKey.length}');

      await platform.invokeMethod('initUrlBlockService', {
        'deviceId': _deviceId,
        'supabaseUrl': supabaseUrl,
        'supabaseKey': supabaseKey,
      });

      print('✅ Native URL blocking service initialized');
    } catch (e) {
      print('❌ Failed to initialize native URL blocking: $e');
    }
  }

  /// Trigger native sync
  Future<void> _syncNative() async {
    try {
      await platform.invokeMethod('syncBlockedUrls');
      print('🔄 Triggered native URL sync');
    } catch (e) {
      print('⚠️ Failed to trigger native sync: $e');
    }
  }

  /// Load blocked URLs from Supabase
  Future<void> _loadBlockedUrls() async {
    if (_deviceId == null) return;

    try {
      print('📡 Fetching blocked URLs for device ID: $_deviceId');

      // Debug: Check what blocked URLs exist in the database
      try {
        final allBlockedUrls = await Supabase.instance.client
            .from('blocked_urls')
            .select('device_id, url, is_active')
            .eq('is_active', true)
            .limit(20);
        print('🔍 DEBUG - All active blocked URLs in database:');
        for (var item in allBlockedUrls) {
          print('   Device: ${item['device_id']} -> URL: ${item['url']}');
        }
        print('🔍 DEBUG - Current child device ID: $_deviceId');
      } catch (e) {
        print('⚠️ Debug query failed: $e');
      }

      final response = await Supabase.instance.client
          .from('blocked_urls')
          .select('url')
          .eq('device_id', _deviceId!)
          .eq('is_active', true);

      print('📡 Supabase response: $response');
      print('📡 Found ${response.length} blocked URLs for this device');

      _blockedUrls.clear();
      _blockedDomains.clear();

      for (var item in response) {
        final url = item['url'] as String;
        _blockedUrls.add(url.toLowerCase());
        print('🚫 Blocked URL added: $url');

        // Extract domain for domain-level blocking
        final domain = _extractDomain(url);
        if (domain != null) {
          _blockedDomains.add(domain.toLowerCase());
        }
      }

      // Cache locally for offline access
      await _cacheBlockedUrls();

      // Sync with native service
      await _syncNative();

      print(
          '✅ Loaded ${_blockedUrls.length} blocked URLs for device: $_deviceId');
    } catch (e) {
      print('❌ Failed to load blocked URLs: $e');
      // Try to load from cache
      await _loadFromCache();
    }
  }

  /// Extract domain from URL
  String? _extractDomain(String url) {
    try {
      Uri uri = Uri.parse(url);
      if (uri.host.isNotEmpty) {
        // Remove 'www.' prefix if present
        String domain = uri.host;
        if (domain.startsWith('www.')) {
          domain = domain.substring(4);
        }
        return domain;
      }

      // If no scheme, try to parse as domain
      if (!url.contains('://')) {
        String domain = url.split('/').first;
        if (domain.startsWith('www.')) {
          domain = domain.substring(4);
        }
        return domain;
      }
    } catch (e) {
      print('⚠️ Failed to extract domain from: $url');
    }
    return null;
  }

  /// Cache blocked URLs locally
  Future<void> _cacheBlockedUrls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blocked_urls', _blockedUrls.toList());
      await prefs.setStringList('blocked_domains', _blockedDomains.toList());
      print('💾 Cached ${_blockedUrls.length} blocked URLs locally');
    } catch (e) {
      print('⚠️ Failed to cache blocked URLs: $e');
    }
  }

  /// Load blocked URLs from local cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUrls = prefs.getStringList('blocked_urls') ?? [];
      final cachedDomains = prefs.getStringList('blocked_domains') ?? [];

      _blockedUrls = cachedUrls.toSet();
      _blockedDomains = cachedDomains.toSet();

      print('📦 Loaded ${_blockedUrls.length} blocked URLs from cache');
    } catch (e) {
      print('⚠️ Failed to load from cache: $e');
    }
  }

  /// Start periodic sync with Supabase
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadBlockedUrls();
    });
  }

  /// Check if a URL is blocked
  bool isUrlBlocked(String url) {
    if (!_isInitialized) return false;

    final lowerUrl = url.toLowerCase();

    // Check exact URL match
    if (_blockedUrls.contains(lowerUrl)) {
      print('🚫 URL blocked (exact match): $url');
      return true;
    }

    // Check domain match
    final domain = _extractDomain(url);
    if (domain != null && _blockedDomains.contains(domain.toLowerCase())) {
      print('🚫 URL blocked (domain match): $url -> $domain');
      return true;
    }

    // Check if URL contains any blocked domain
    for (final blockedDomain in _blockedDomains) {
      if (lowerUrl.contains(blockedDomain)) {
        print('🚫 URL blocked (contains domain): $url -> $blockedDomain');
        return true;
      }
    }

    return false;
  }

  /// Record a URL visit to search history
  Future<void> recordUrlVisit(String url, {String? title}) async {
    if (_deviceId == null) return;

    try {
      // Clean URL
      String cleanUrl = url.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }

      // Check if entry exists
      final existing = await Supabase.instance.client
          .from('search_history')
          .select('id, visit_count')
          .eq('device_id', _deviceId!)
          .eq('url', cleanUrl)
          .maybeSingle();

      if (existing != null) {
        // Update visit count
        await Supabase.instance.client.from('search_history').update({
          'visit_count': (existing['visit_count'] ?? 0) + 1,
          'visited_at': DateTime.now().toIso8601String(),
          'title': title,
        }).eq('id', existing['id']);
      } else {
        // Insert new entry
        await Supabase.instance.client.from('search_history').insert({
          'device_id': _deviceId,
          'url': cleanUrl,
          'title': title ?? cleanUrl,
          'visited_at': DateTime.now().toIso8601String(),
          'visit_count': 1,
        });
      }

      print('📝 Recorded URL visit: $cleanUrl');
    } catch (e) {
      print('⚠️ Failed to record URL visit: $e');
    }
  }

  /// Force refresh blocked URLs
  Future<void> refreshBlockedUrls() async {
    await _loadBlockedUrls();
  }

  /// Dispose the service
  void dispose() {
    _syncTimer?.cancel();
    _isInitialized = false;
    print('🔒 URL Blocking Service disposed');
  }

  void _setupRealtimeSubscription() {
    if (_deviceId == null) return;

    Supabase.instance.client
        .from('blocked_urls')
        .stream(primaryKey: ['id'])
        .eq('device_id', _deviceId!)
        .listen((data) async {
          print('🔴 Real-time: URL list updated, syncing...');
          await _loadBlockedUrls();
          await _syncNative();
        });
  }

  /*void _setupRealtimeSubscription() {
    if (_deviceId == null) return;

    Supabase.instance.client
        .from('blocked_urls')
        .stream(primaryKey: ['id'])
        .eq('device_id', _deviceId as Object)
        .eq('is_active', true)
        .listen((data) async {
          print('🔴 Real-time: URL list updated, syncing...');
          await _loadBlockedUrls();
          await _syncNative();
        });
  }*/
}
