import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle location tracking and syncing to Supabase
/// Now with persistent background tracking that survives app kills and device restarts
class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  // Method channel for native Android service communication
  static const MethodChannel _channel =
      MethodChannel('parental_control/permissions');

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _periodicTimer;
  String? _deviceId;
  bool _isTracking = false;
  int _locationUpdateCount = 0;

  // Track last saved location to prevent duplicates
  DateTime? _lastSaveTime;
  double? _lastSavedLat;
  double? _lastSavedLng;

  // Minimum interval between saves (10 minutes)
  static const int _minSaveIntervalSeconds = 60;
  // Minimum distance change to save (100 meters)
  static const double _minDistanceChange = 100.0;
  // Periodic update interval (10 minutes)
  static const Duration _periodicUpdateInterval = Duration(minutes: 1);

  /// Check if location tracking is currently active
  bool get isTracking => _isTracking;

  /// Initialize and restore tracking if it was active before
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDeviceId = prefs.getString('tracking_device_id');
      final wasTracking = prefs.getBool('is_tracking') ?? false;

      // Check if native service is running (for Android)
      if (Platform.isAndroid) {
        final isNativeRunning = await isNativeServiceRunning();
        if (isNativeRunning) {
          final nativeDeviceId = await getNativeServiceDeviceId();
          if (nativeDeviceId != null) {
            _deviceId = nativeDeviceId;
            _isTracking = true;
            print(
                '🔄 Native location service already running for device: $nativeDeviceId');
            return;
          }
        }
      }

      if (wasTracking && savedDeviceId != null) {
        print('🔄 Restoring location tracking for device: $savedDeviceId');
        await startTracking(savedDeviceId);
      }
    } catch (e) {
      print('⚠️ Failed to restore tracking state: $e');
    }
  }

  /// Start tracking location and syncing to Supabase
  /// On Android, this uses a foreground service that survives app kills and device restarts
  Future<void> startTracking(String deviceId) async {
    if (_isTracking && _deviceId == deviceId) {
      print('⚠️ Location tracking already active for device: $deviceId');
      return;
    }

    // Stop any existing tracking
    if (_isTracking) {
      await stopTracking();
    }

    _deviceId = deviceId;

    try {
      // Save tracking state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tracking_device_id', deviceId);
      await prefs.setBool('is_tracking', true);

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        throw Exception(
            'Location services are disabled. Please enable location in settings.');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permissions are denied');
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permissions are permanently denied');
        throw Exception('Location permissions are permanently denied');
      }

      print('🚀 Starting location tracking for device: $deviceId');
      print('📍 Permission status: $permission');

      // On Android, use native foreground service for persistent tracking
      if (Platform.isAndroid) {
        await _startNativeLocationService(deviceId);
        _isTracking = true;
        print('✅ Native location service started successfully!');
        print(
            '📊 Location tracking will continue even if app is killed or device restarts');
        return;
      }

      // For non-Android platforms, use Flutter-based tracking
      // Get initial position and save it immediately
      try {
        Position currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(minutes: 1),
        );
        await _saveLocation(currentPosition, forceUpdate: true);
        print('✅ Initial location saved');
      } catch (e) {
        print('⚠️ Failed to get initial position: $e');
      }

      // Start listening to position updates - 100 meter distance filter
      // Use platform-specific settings for background tracking (sleep mode)
      late LocationSettings locationSettings;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100, // Update every 100 meters
          activityType: ActivityType.other,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100, // Update every 100 meters
        );
      }

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _locationUpdateCount++;
          print('📍 Location update #$_locationUpdateCount received');
          _saveLocation(position); // Will be deduplicated
        },
        onError: (error) {
          print('❌ Location tracking stream error: $error');
        },
        cancelOnError: false,
      );

      // Set up a periodic timer for guaranteed updates every 10 minutes
      // This ensures location is refreshed even in sleep mode
      _periodicTimer = Timer.periodic(_periodicUpdateInterval, (timer) async {
        print('⏰ 10-minute periodic location update triggered');
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 30),
          );
          await _saveLocation(position,
              forceUpdate: true); // Force save on periodic update
        } catch (e) {
          print('❌ Periodic update failed: $e');
        }
      });

      _isTracking = true;
      print('✅ Location tracking started successfully!');
      print('📊 Update count will be logged for monitoring');
    } catch (e) {
      print('❌ Failed to start location tracking: $e');

      // Clear tracking state on failure
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_tracking');

      rethrow;
    }
  }

  /// Save location to Supabase database with deduplication
  Future<void> _saveLocation(Position position,
      {bool forceUpdate = false}) async {
    if (_deviceId == null) {
      print('⚠️ Cannot save location: deviceId is null');
      return;
    }

    final now = DateTime.now();

    // Check if we should skip this save (deduplication)
    if (!forceUpdate && _lastSaveTime != null) {
      final secondsSinceLastSave = now.difference(_lastSaveTime!).inSeconds;

      // Skip if less than minimum interval
      if (secondsSinceLastSave < _minSaveIntervalSeconds) {
        print(
            '⏳ Skipping save: only ${secondsSinceLastSave}s since last save (min: ${_minSaveIntervalSeconds}s)');
        return;
      }

      // Skip if location hasn't changed significantly
      if (_lastSavedLat != null && _lastSavedLng != null) {
        final distance = Geolocator.distanceBetween(
          _lastSavedLat!,
          _lastSavedLng!,
          position.latitude,
          position.longitude,
        );

        if (distance < _minDistanceChange &&
            secondsSinceLastSave < _minSaveIntervalSeconds) {
          // Less than 100 meters and less than 10 minutes
          print(
              '📍 Skipping save: location changed only ${distance.toStringAsFixed(1)}m (min: ${_minDistanceChange}m)');
          return;
        }
      }
    }

    try {
      print('💾 Saving location for device: $_deviceId');
      print('📍 Coordinates: ${position.latitude}, ${position.longitude}');

      // Get address from coordinates (reverse geocoding)
      String address = await _getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      print("address:  $address");
      final locationData = {
        'device_id': _deviceId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
        'recorded_at': now.toIso8601String(),
      };

      print('📦 Location data to insert: $locationData');

      // Insert into Supabase
      final response = await Supabase.instance.client
          .from('locations')
          .insert(locationData)
          .select();

      // Update last save tracking
      _lastSaveTime = now;
      _lastSavedLat = position.latitude;
      _lastSavedLng = position.longitude;

      print(
          '✅ Location saved successfully: ${position.latitude}, ${position.longitude}');
      print('💾 Database response: $response');
      if (kDebugMode) {
        print('📍 Address: $address');
      }
    } catch (e) {
      print('❌ Failed to save location: $e');
      print('🔍 Error type: ${e.runtimeType}');
      if (e is PostgrestException) {
        print('🔍 Postgrest error details: ${e.message}');
        print('🔍 Postgrest error code: ${e.code}');
      }
    }
  }

  /// Get address from coordinates using reverse geocoding
  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      // Try HTTP-based reverse geocoding first (works on all platforms including web)
      final address = await _getAddressFromNominatim(lat, lng);
      if (address != null && address.isNotEmpty) {
        print('📍 Resolved address (Nominatim): $address');
        return address;
      }

      // Fallback to geocoding package (may not work on web)
      if (!kIsWeb) {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;

          // Build a complete, readable address
          List<String> addressParts = [];

          if (place.name != null &&
              place.name!.isNotEmpty &&
              place.name != place.street) {
            addressParts.add(place.name!);
          }
          if (place.street != null && place.street!.isNotEmpty) {
            addressParts.add(place.street!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }
          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            addressParts.add(place.postalCode!);
          }
          if (place.country != null && place.country!.isNotEmpty) {
            addressParts.add(place.country!);
          }

          // Remove duplicates
          List<String> uniqueParts = [];
          for (String part in addressParts) {
            if (!uniqueParts.contains(part)) {
              uniqueParts.add(part);
            }
          }

          String fullAddress = uniqueParts.join(', ');
          print('📍 Resolved address (Package): $fullAddress');
          return fullAddress.isNotEmpty ? fullAddress : 'Unknown location';
        }
      }

      return 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
    } catch (e) {
      print('⚠️ Failed to get address: $e');
      // Fallback to coordinates if geocoding fails
      return 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
    }
  }

  /// Reverse geocoding using OpenStreetMap Nominatim API (works on web and mobile)
  Future<String?> _getAddressFromNominatim(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SurakshaApp/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Get the display_name which is a complete address
        if (data['display_name'] != null) {
          return data['display_name'] as String;
        }

        // Or build from address components
        if (data['address'] != null) {
          final addr = data['address'] as Map<String, dynamic>;
          List<String> parts = [];

          // Add address components in order
          if (addr['house_number'] != null) parts.add(addr['house_number']);
          if (addr['road'] != null) parts.add(addr['road']);
          if (addr['neighbourhood'] != null) parts.add(addr['neighbourhood']);
          if (addr['suburb'] != null) parts.add(addr['suburb']);
          if (addr['city'] != null) parts.add(addr['city']);
          if (addr['town'] != null && !parts.contains(addr['town'])) {
            parts.add(addr['town']);
          }
          if (addr['village'] != null && !parts.contains(addr['village'])) {
            parts.add(addr['village']);
          }
          if (addr['state'] != null) parts.add(addr['state']);
          if (addr['postcode'] != null) parts.add(addr['postcode']);
          if (addr['country'] != null) parts.add(addr['country']);

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Nominatim API error: $e');
      return null;
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    if (!_isTracking) {
      print('⚠️ Location tracking is not active');
      return;
    }

    // On Android, stop the native foreground service
    if (Platform.isAndroid) {
      await _stopNativeLocationService();
    }

    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    _periodicTimer?.cancel();
    _periodicTimer = null;

    _deviceId = null;
    _isTracking = false;
    _locationUpdateCount = 0;

    // Clear deduplication state
    _lastSaveTime = null;
    _lastSavedLat = null;
    _lastSavedLng = null;

    // Clear tracking state
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_tracking');
    await prefs.remove('tracking_device_id');

    print('🛑 Location tracking stopped');
  }

  // ==================== NATIVE ANDROID SERVICE METHODS ====================

  /// Start the native Android location foreground service + WorkManager
  Future<void> _startNativeLocationService(String deviceId) async {
    try {
      final supabase = Supabase.instance.client;
      final supabaseUrl = supabase.rest.url.replaceAll('/rest/v1', '');
      const supabaseKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8';

      // Start the foreground service
      await _channel.invokeMethod('startLocationService', {
        'deviceId': deviceId,
        'supabaseUrl': supabaseUrl,
        'supabaseKey': supabaseKey,
      });
      print('✅ Native location service started');

      // Schedule WorkManager for additional reliability
      await _channel.invokeMethod('scheduleLocationWorker');
      print('✅ WorkManager location worker scheduled');
    } catch (e) {
      print('❌ Failed to start native location service: $e');
      rethrow;
    }
  }

  /// Stop the native Android location foreground service + WorkManager
  Future<void> _stopNativeLocationService() async {
    try {
      await _channel.invokeMethod('stopLocationService');
      print('✅ Native location service stopped');

      // Cancel WorkManager
      await _channel.invokeMethod('cancelLocationWorker');
      print('✅ WorkManager location worker cancelled');
    } catch (e) {
      print('❌ Failed to stop native location service: $e');
    }
  }

  /// Check if WorkManager is scheduled
  Future<bool> isLocationWorkerScheduled() async {
    if (!Platform.isAndroid) return false;
    try {
      final result =
          await _channel.invokeMethod<bool>('isLocationWorkerScheduled');
      return result ?? false;
    } catch (e) {
      print('⚠️ Failed to check WorkManager status: $e');
      return false;
    }
  }

  /// Check if the native Android location service is running
  Future<bool> isNativeServiceRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      final result =
          await _channel.invokeMethod<bool>('isLocationServiceRunning');
      return result ?? false;
    } catch (e) {
      print('⚠️ Failed to check native service status: $e');
      return false;
    }
  }

  /// Get the device ID from the native Android location service
  Future<String?> getNativeServiceDeviceId() async {
    if (!Platform.isAndroid) return null;
    try {
      final result =
          await _channel.invokeMethod<String>('getLocationServiceDeviceId');
      return result;
    } catch (e) {
      print('⚠️ Failed to get native service device ID: $e');
      return null;
    }
  }

  /// Request battery optimization exemption (important for persistent background service)
  Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestBatteryOptimizationExemption');
      print('📱 Requested battery optimization exemption');
    } catch (e) {
      print('⚠️ Failed to request battery optimization exemption: $e');
    }
  }

  /// Check if battery optimization is disabled for this app
  Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      return result ?? false;
    } catch (e) {
      print('⚠️ Failed to check battery optimization status: $e');
      return false;
    }
  }

  /// Open background location permission settings (Android 10+)
  Future<void> requestBackgroundLocationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestBackgroundLocationPermission');
      print('📱 Opened background location settings');
    } catch (e) {
      print('⚠️ Failed to open background location settings: $e');
    }
  }

  /// Get current location once (without continuous tracking)
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('❌ Location permissions denied');
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(minutes: 1),
      );
      return position;
    } catch (e) {
      print('❌ Failed to get current location: $e');
      return null;
    }
  }

  /// Manually trigger a location update (useful for testing)
  Future<void> triggerLocationUpdate() async {
    if (!_isTracking || _deviceId == null) {
      print('⚠️ Cannot trigger update: tracking not active');
      return;
    }

    try {
      print('🔄 Triggering manual location update...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(minutes: 1),
      );
      await _saveLocation(position);
      print('✅ Manual location update completed');
    } catch (e) {
      print('❌ Failed to trigger location update: $e');
    }
  }

  /// Get tracking statistics
  Map<String, dynamic> getTrackingStats() {
    return {
      'isTracking': _isTracking,
      'deviceId': _deviceId,
      'updateCount': _locationUpdateCount,
      'hasStream': _positionStreamSubscription != null,
      'hasTimer': _periodicTimer != null,
      'isAndroid': Platform.isAndroid,
    };
  }

  /// Get extended tracking statistics including native service status (async)
  Future<Map<String, dynamic>> getTrackingStatsAsync() async {
    final isNativeRunning =
        Platform.isAndroid ? await isNativeServiceRunning() : false;
    final nativeDeviceId =
        Platform.isAndroid ? await getNativeServiceDeviceId() : null;
    final batteryOptimizationDisabled =
        Platform.isAndroid ? await isBatteryOptimizationDisabled() : true;

    return {
      'isTracking': _isTracking,
      'deviceId': _deviceId,
      'updateCount': _locationUpdateCount,
      'hasStream': _positionStreamSubscription != null,
      'hasTimer': _periodicTimer != null,
      'isAndroid': Platform.isAndroid,
      'isNativeServiceRunning': isNativeRunning,
      'nativeServiceDeviceId': nativeDeviceId,
      'batteryOptimizationDisabled': batteryOptimizationDisabled,
    };
  }

  // ==================== DATABASE FETCH METHODS (FOR PARENT DASHBOARD) ====================

  static final _supabase = Supabase.instance.client;

  /// Fetches the most recent location for a device from the database (For Parent App)
  static Future<Map<String, dynamic>?> fetchLatestLocation(
      String deviceId) async {
    try {
      print('📡 Fetching latest location for device: $deviceId');
      final response = await _supabase
          .from('locations')
          .select()
          .eq('device_id', deviceId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Error fetching latest location: $e');
      return null;
    }
  }

  /// Fetches location history for a device from the database (For Parent App)
  static Future<List<Map<String, dynamic>>> fetchLocationHistory(
      String deviceId,
      {int limit = 10}) async {
    try {
      print('📡 Fetching location history for device: $deviceId');
      final response = await _supabase
          .from('locations')
          .select()
          .eq('device_id', deviceId)
          .order('recorded_at', ascending: false)
          .limit(limit);

      print('✅ Fetched ${response.length} location entries from database.');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching location history: $e');
      return [];
    }
  }

  /// Subscribes to real-time location changes for a device (For Parent App)
  static Stream<Map<String, dynamic>?> watchLatestLocation(String deviceId) {
    print('👁️ Setting up real-time location watch for device: $deviceId');
    return _supabase
        .from('locations')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .order('recorded_at', ascending: false)
        .map((data) {
          if (data.isNotEmpty) {
            print(
                '📡 Real-time location update received: ${data.first['address']}');
            return data.first;
          }
          return null;
        });
  }

  /// Subscribes to real-time location history changes for a device (For Parent App)
  static Stream<List<Map<String, dynamic>>> watchLocationHistory(
      String deviceId,
      {int limit = 10}) {
    print(
        '👁️ Setting up real-time location history watch for device: $deviceId');
    return _supabase
        .from('locations')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .order('recorded_at', ascending: false)
        .map((data) {
          print(
              '📡 Real-time location history update received: ${data.length} entries');
          return List<Map<String, dynamic>>.from(data.take(limit));
        });
  }
}
