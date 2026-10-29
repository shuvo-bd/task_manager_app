import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_assignment/utils/location_formatters.dart';

void main() {
  group('formatCoordinates', () {
    test('formats latitude and longitude to six decimal places', () {
      expect(
        formatCoordinates(latitude: 23.7216771, longitude: 90.4165835),
        '23.721677, 90.416584',
      );
    });

    test('keeps negative coordinates readable', () {
      expect(
        formatCoordinates(latitude: -33.8688, longitude: 151.2093),
        '-33.868800, 151.209300',
      );
    });
  });
}
