import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';
import '../utils/location_formatters.dart';

class LocationTrackerScreen extends StatefulWidget {
  const LocationTrackerScreen({super.key});

  @override
  State<LocationTrackerScreen> createState() => _LocationTrackerScreenState();
}

class _LocationTrackerScreenState extends State<LocationTrackerScreen>
    with WidgetsBindingObserver {
  static const Duration _updateInterval = Duration(seconds: 10);
  static const int _maximumRoutePoints = 1000;
  static const LatLng _fallbackLocation = LatLng(23.8103, 90.4125);

  final LocationService _locationService = LocationService();
  final List<LatLng> _routePoints = <LatLng>[];

  GoogleMapController? _mapController;
  Timer? _locationTimer;
  Position? _currentPosition;
  DateTime? _lastUpdated;
  LocationServiceException? _locationError;

  bool _isStarting = false;
  bool _isUpdating = false;
  bool _isLoading = true;
  bool _wasInBackground = false;
  bool _hasCenteredOnUser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startTracking());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasInBackground = true;
      _locationTimer?.cancel();
      _locationTimer = null;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      unawaited(_startTracking());
    }
  }

  Future<void> _startTracking() async {
    if (_isStarting || !mounted) {
      return;
    }

    _isStarting = true;
    setState(() {
      _isLoading = true;
      _locationError = null;
    });

    try {
      await _locationService.requestLocationPermission();
      await _updateLocation();

      if (mounted) {
        _locationTimer?.cancel();
        _locationTimer = Timer.periodic(_updateInterval, (_) {
          unawaited(_updateLocation());
        });
      }
    } on LocationServiceException catch (error) {
      _showLocationError(error);
    } catch (_) {
      _showLocationError(
        const LocationServiceException(
          LocationProblem.unknown,
          'Could not start location tracking. Please try again.',
        ),
      );
    } finally {
      _isStarting = false;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateLocation() async {
    if (_isUpdating || !mounted) {
      return;
    }

    _isUpdating = true;
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) {
        return;
      }

      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = position;
        _lastUpdated = DateTime.now();
        _locationError = null;
        _routePoints.add(point);

        // Keep a useful recent track without letting the list grow forever.
        if (_routePoints.length > _maximumRoutePoints) {
          _routePoints.removeAt(0);
        }
      });

      await _moveCameraTo(point);
    } on LocationServiceException catch (error) {
      _showLocationError(error);
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }

      var problem = LocationProblem.unknown;
      var message = 'Could not get the current location. Please try again.';

      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.deniedForever) {
          problem = LocationProblem.permissionDeniedForever;
          message = 'Location permission is disabled for this app.';
        } else if (permission == LocationPermission.denied) {
          problem = LocationProblem.permissionDenied;
          message = 'Location permission was denied.';
        }
      } catch (_) {
        // Keep the general error when the permission status cannot be checked.
      }

      _showLocationError(LocationServiceException(problem, message));
      return;
    } finally {
      _isUpdating = false;
    }
  }

  void _showLocationError(LocationServiceException error) {
    if (!mounted) {
      return;
    }
    setState(() => _locationError = error);
  }

  Future<void> _moveCameraTo(LatLng point) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    try {
      if (!_hasCenteredOnUser) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: point, zoom: 17),
          ),
          duration: const Duration(milliseconds: 800),
        );
        _hasCenteredOnUser = true;
      } else {
        await controller.animateCamera(
          CameraUpdate.newLatLng(point),
          duration: const Duration(milliseconds: 700),
        );
      }
    } catch (_) {
      // The map may be closing while a location update is in progress.
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    final position = _currentPosition;
    if (position != null) {
      unawaited(_moveCameraTo(LatLng(position.latitude, position.longitude)));
    }
  }

  Future<void> _handleLocationAction() async {
    final problem = _locationError?.problem;

    if (problem == LocationProblem.permissionDeniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    if (problem == LocationProblem.serviceDisabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    await _startTracking();
  }

  String _lastUpdatedText() {
    final updated = _lastUpdated;
    if (updated == null) return 'Waiting for location';

    final hour = updated.hour.toString().padLeft(2, '0');
    final minute = updated.minute.toString().padLeft(2, '0');
    final second = updated.second.toString().padLeft(2, '0');
    return 'Last updated $hour:$minute:$second';
  }

  String _errorText(LocationServiceException error) {
    switch (error.problem) {
      case LocationProblem.serviceDisabled:
        return 'Turn on GPS, then try again.';
      case LocationProblem.permissionDenied:
        return 'Allow location permission to continue.';
      case LocationProblem.permissionDeniedForever:
        return 'Allow location access in your app settings.';
      case LocationProblem.requestTimedOut:
        return 'Location timed out. Check GPS and try again.';
      case LocationProblem.unknown:
        return error.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = _currentPosition;
    final markers = <Marker>{};
    if (position != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: InfoWindow(
            title: 'My current location',
            snippet: formatCoordinates(
              latitude: position.latitude,
              longitude: position.longitude,
            ),
          ),
        ),
      );
    }

    final polylines = <Polyline>{};
    if (_routePoints.length > 1) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('location_track'),
          points: List<LatLng>.unmodifiable(_routePoints),
          color: const Color(0xFF1976D2),
          width: 5,
          geodesic: true,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Real-Time Location Tracker',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 2,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            tooltip: 'Refresh location',
            onPressed: _isStarting ? null : _startTracking,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _fallbackLocation,
              zoom: 13,
            ),
            onMapCreated: _onMapCreated,
            markers: markers,
            polylines: polylines,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            indoorViewEnabled: true,
            trafficEnabled: false,
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: _buildLocationCard(position),
                ),
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: FloatingActionButton.small(
                    heroTag: 'center_map_button',
                    tooltip: 'Center on my location',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1976D2),
                    elevation: 3,
                    onPressed: position == null
                        ? _handleLocationAction
                        : () {
                            unawaited(
                              _moveCameraTo(
                                LatLng(position.latitude, position.longitude),
                              ),
                            );
                          },
                    child: const Icon(Icons.my_location),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: _buildStatusCard(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Position? position) {
    final coordinates = position == null
        ? 'Waiting for your current location...'
        : formatCoordinates(
            latitude: position.latitude,
            longitude: position.longitude,
          );

    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 13, 10, 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFF1976D2),
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'My Current Location',
                    style: TextStyle(
                      color: Color(0xFF202124),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    coordinates,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5F6368),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading && position == null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              )
            else if (_locationError != null)
              IconButton(
                tooltip: 'Fix location access',
                onPressed: _handleLocationAction,
                icon: const Icon(Icons.refresh, color: Color(0xFF1976D2)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final tracking = _locationTimer != null && _locationError == null;
    final error = _locationError;

    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  tracking ? Icons.radio_button_checked : Icons.access_time,
                  size: 18,
                  color: tracking
                      ? const Color(0xFF188038)
                      : const Color(0xFF5F6368),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tracking
                        ? 'Live tracking · every 10 seconds'
                        : 'Location tracking',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF202124),
                    ),
                  ),
                ),
                Text(
                  _lastUpdatedText(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5F6368),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText(error),
                style: const TextStyle(fontSize: 12, color: Color(0xFFB3261E)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _handleLocationAction,
                  icon: const Icon(Icons.settings, size: 16),
                  label: Text(
                    error.problem == LocationProblem.serviceDisabled
                        ? 'Open GPS settings'
                        : error.problem ==
                              LocationProblem.permissionDeniedForever
                        ? 'App settings'
                        : 'Try again',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
