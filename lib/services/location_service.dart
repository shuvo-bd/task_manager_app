import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationProblem {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  requestTimedOut,
  unknown,
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.problem, this.message);

  final LocationProblem problem;
  final String message;

  @override
  String toString() => message;
}

class LocationService {
  Future<void> requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        LocationProblem.serviceDisabled,
        'Location services are turned off.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException(
        LocationProblem.permissionDenied,
        'Location permission was denied.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        LocationProblem.permissionDeniedForever,
        'Location permission is disabled for this app.',
      );
    }

    if (permission == LocationPermission.unableToDetermine) {
      throw const LocationServiceException(
        LocationProblem.permissionDenied,
        'Could not determine the location permission status.',
      );
    }
  }

  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        LocationProblem.serviceDisabled,
        'Location services are turned off.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      throw const LocationServiceException(
        LocationProblem.requestTimedOut,
        'The location request took too long.',
      );
    }
  }
}
