import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle location tracking and syncing to Supabase
class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _periodicTimer;
  String? _deviceId;
  bool _isTracking = false;
  int _locationUpdateCount = 0;

  /// Check if location tracking is currently active
  bool get isTracking => _isTracking;

  /// Initialize and restore tracking if it was active before
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDeviceId = prefs.getString('tracking_device_id');
      final wasTracking = prefs.getBool('is_tracking') ?? false;

      if (wasTracking && savedDeviceId != null) {
        print('🔄 Restoring location tracking for device: $savedDeviceId');
        await startTracking(savedDeviceId);
      }
    } catch (e) {
      print('⚠️ Failed to restore tracking state: $e');
    }
  }

  /// Start tracking location and syncing to Supabase
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

      // Get initial position and save it immediately
      try {
        Position currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        await _saveLocation(currentPosition);
        print('✅ Initial location saved');
      } catch (e) {
        print('⚠️ Failed to get initial position: $e');
      }

      // Start listening to position updates with more aggressive settings
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters (more frequent)
        timeLimit: Duration(seconds: 30),
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _locationUpdateCount++;
          print('📍 Location update #$_locationUpdateCount received');
          _saveLocation(position);
        },
        onError: (error) {
          print('❌ Location tracking stream error: $error');
        },
        cancelOnError: false,
      );

      // Also set up a periodic timer to force updates every 5 minutes
      _periodicTimer =
          Timer.periodic(const Duration(minutes: 5), (timer) async {
        print('⏰ Periodic location update triggered');
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          await _saveLocation(position);
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

  /// Save location to Supabase database
  Future<void> _saveLocation(Position position) async {
    if (_deviceId == null) {
      print('⚠️ Cannot save location: deviceId is null');
      return;
    }

    try {
      print('💾 Attempting to save location for device: $_deviceId');
      print('📍 Coordinates: ${position.latitude}, ${position.longitude}');

      // Get address from coordinates (reverse geocoding)
      String address = await _getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final locationData = {
        'device_id': _deviceId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
        'recorded_at': DateTime.now().toIso8601String(),
      };

      print('📦 Location data to insert: $locationData');

      // Insert into Supabase
      final response = await Supabase.instance.client
          .from('locations')
          .insert(locationData)
          .select();

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
  /// For now, returns a formatted coordinate string
  /// TODO: Integrate with a geocoding service for actual addresses
  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      // For now, return formatted coordinates
      // You can integrate Google Maps Geocoding API or other services here
      return 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
    } catch (e) {
      print('⚠️ Failed to get address: $e');
      return 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    if (!_isTracking) {
      print('⚠️ Location tracking is not active');
      return;
    }

    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    _periodicTimer?.cancel();
    _periodicTimer = null;

    _deviceId = null;
    _isTracking = false;
    _locationUpdateCount = 0;

    // Clear tracking state
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_tracking');
    await prefs.remove('tracking_device_id');

    print('🛑 Location tracking stopped');
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
        timeLimit: const Duration(seconds: 10),
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
        timeLimit: const Duration(seconds: 10),
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
    };
  }
}
