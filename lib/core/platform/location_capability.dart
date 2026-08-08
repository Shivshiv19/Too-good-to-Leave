import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';

/// Outcome of a permission check/request, already folded together with the
/// accuracy the OS actually granted (Android 12+/iOS 14+ "approximate"
/// location) — the two are separate OS concepts but §5a.3's branch table
/// treats them as one decision, so the seam matches the screen, not the
/// platform API.
enum LocationPermissionOutcome {
  grantedPrecise,
  grantedApproximate,
  denied,
  deniedPermanently,
}

/// Thrown by [LocationCapability.getCurrentPosition] when the OS does not
/// return a fix within the caller's timeout (§5a.4 — 15 s at the setup
/// screen).
final class LocationTimeoutException implements Exception {
  const LocationTimeoutException();
}

/// Platform capability wrapper over `geolocator` + `permission_handler`
/// (Phase 8 §8.6 — capabilities sit behind a core abstraction, same shape as
/// `SecureStore`/`Prefs`). This is a device fact, not a server stand-in, so
/// there is exactly one implementation, same reasoning as D-19.
abstract interface class LocationCapability {
  Future<LocationPermissionOutcome> checkPermission();

  Future<LocationPermissionOutcome> requestPermission();

  Future<LatLng> getCurrentPosition({required Duration timeout});

  Future<void> openAppSettings();
}

final class LocationCapabilityGeolocator implements LocationCapability {
  const LocationCapabilityGeolocator();

  @override
  Future<LocationPermissionOutcome> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return _resolve(permission);
  }

  @override
  Future<LocationPermissionOutcome> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return _resolve(permission);
  }

  Future<LocationPermissionOutcome> _resolve(
    LocationPermission permission,
  ) async {
    switch (permission) {
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionOutcome.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionOutcome.deniedPermanently;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        // Accuracy is a separate OS axis from the grant itself (Android
        // 12+/iOS 14+). Platforms without the concept report `precise`.
        final accuracy = await Geolocator.getLocationAccuracy();
        return accuracy == LocationAccuracyStatus.reduced
            ? LocationPermissionOutcome.grantedApproximate
            : LocationPermissionOutcome.grantedPrecise;
    }
  }

  @override
  Future<LatLng> getCurrentPosition({required Duration timeout}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(timeLimit: timeout),
      );
      return LatLng(latitude: position.latitude, longitude: position.longitude);
    } on TimeoutException {
      throw const LocationTimeoutException();
    }
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
