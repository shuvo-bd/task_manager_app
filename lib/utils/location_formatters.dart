String formatCoordinates({
  required double latitude,
  required double longitude,
}) {
  return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}
