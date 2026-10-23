import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/models/instrument_catalog.dart';
import 'package:music_transcriber/screens/widgets/upload_shared/instrument_picker.dart';

void main() {
  group('catalogue search', () {
    test('an empty search returns everything', () {
      expect(searchInstruments('  '), hasLength(instrumentCatalog.length));
    });

    test('finds by name, id, family and alias', () {
      expect(searchInstruments('flute').map((o) => o.id), contains('flutes'));
      expect(searchInstruments('bansuri').map((o) => o.id), ['flutes']);
      expect(searchInstruments('harmonium').map((o) => o.id), ['organ']);
      expect(searchInstruments('string ensemble').map((o) => o.id), contains('string_ensemble'));
      expect(searchInstruments('GUITAR').map((o) => o.id),
          containsAll(['acoustic_guitar', 'clean_electric_guitar', 'distorted_electric_guitar']));
    });

    test('nothing matching gives an empty list', () {
      expect(searchInstruments('zzzz'), isEmpty);
    });

    test('ids are unique and never include voice or drums', () {
      final ids = instrumentCatalog.map((o) => o.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, isNot(contains('voice')));
      expect(ids, isNot(contains('drums')));
      expect(instrumentCatalog, hasLength(33));
    });
  });

  group('InstrumentPicker', () {
    Future<Set<String>> pumpPicker(WidgetTester tester, {Set<String> start = const {}}) async {
      var selected = {...start};
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: InstrumentPicker(
                selected: selected,
                enabled: true,
                onChanged: (next) => setState(() => selected = next),
              ),
            ),
          ),
        ),
      ));
      return selected;
    }

    testWidgets('says it decides on its own when nothing is chosen', (tester) async {
      await pumpPicker(tester);
      expect(find.textContaining('work out the instruments on its own'), findsOneWidget);
    });

    testWidgets('search narrows the list and ticking summarises the choice', (tester) async {
      await pumpPicker(tester);
      await tester.tap(find.text('Instruments (optional)'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'bansuri');
      await tester.pump();

      expect(find.text('Flute / bansuri'), findsOneWidget);
      expect(find.text('Piano'), findsNothing);

      await tester.tap(find.text('Flute / bansuri'));
      await tester.pump();
      expect(find.textContaining('Looking only for: Flute / bansuri'), findsOneWidget);
      expect(find.text('Clear all (1 chosen)'), findsOneWidget);

      await tester.tap(find.text('Clear all (1 chosen)'));
      await tester.pump();
      expect(find.textContaining('work out the instruments on its own'), findsOneWidget);
    });

    testWidgets('a search with no match says so', (tester) async {
      await pumpPicker(tester);
      await tester.tap(find.text('Instruments (optional)'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.textContaining('Nothing matches'), findsOneWidget);
    });
  });
}
