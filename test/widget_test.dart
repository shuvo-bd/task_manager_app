import 'package:flutter_test/flutter_test.dart';

import 'package:google_map_assignment/main.dart';

void main() {
  testWidgets('shows the location tracker screen', (tester) async {
    await tester.pumpWidget(const LocationTrackerApp());

    expect(find.text('Real-Time Location Tracker'), findsOneWidget);
    expect(find.text('My Current Location'), findsOneWidget);
    expect(find.text('Waiting for your current location...'), findsOneWidget);
  });
}
