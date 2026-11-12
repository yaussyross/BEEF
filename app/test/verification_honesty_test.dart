import 'package:beef/models/grid_profile.dart';
import 'package:beef/widgets/grid_tile.dart' as beef;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('legacy verified status never presents an unsupported assurance', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      width: 220, height: 240,
      child: beef.GridTile(profile: const GridProfile(userId: 'synthetic',
        displayName: 'Fixture', distance: 'nearby', photoVerificationStatus: 'verified'),
        onTap: () {}),
    ))));
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.verified), findsNothing);
    expect(find.text('Certified Cut'), findsNothing);
    expect(find.text('Fixture'), findsOneWidget);
  });
}
