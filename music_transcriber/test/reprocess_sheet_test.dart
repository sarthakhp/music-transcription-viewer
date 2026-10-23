import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/models/audio_content_type.dart';
import 'package:music_transcriber/models/job.dart';
import 'package:music_transcriber/models/job_status.dart';
import 'package:music_transcriber/screens/widgets/reprocess_sheet.dart';

JobListItem _job(AudioContentType type, List<String> instruments) => JobListItem(
      id: 'j1',
      status: JobStatus.completed,
      progress: 100,
      createdAt: DateTime(2026, 10, 20),
      inputFilename: 'a.mp3',
      fileSize: 0,
      duration: 10,
      tempoBpm: 100,
      numFrames: 0,
      numChords: 0,
      userDisplayName: 'My song',
      audioType: type,
      instruments: instruments,
    );

Future<ReprocessChoice?> _open(WidgetTester tester, JobListItem job) async {
  ReprocessChoice? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => result = await showReprocessSheet(context, job),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('starts from the song\'s own type and says the old song stays', (tester) async {
    await _open(tester, _job(AudioContentType.instrumental, const []));
    expect(find.textContaining('stays as it is'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Music only')).selected, isTrue);
  });

  testWidgets('changing the type and confirming returns the new choice', (tester) async {
    ReprocessChoice? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await showReprocessSheet(context, _job(AudioContentType.instrumental, const [])),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Song'));
    await tester.pump();
    await tester.tap(find.text('Process again').last);
    await tester.pumpAndSettle();
    expect(picked?.audioType, AudioContentType.mixed);
  });

  testWidgets('voice only hides the instrument chooser and sends none', (tester) async {
    ReprocessChoice? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await showReprocessSheet(context, _job(AudioContentType.mixed, const ['flute'])),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Instruments'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Voice only'));
    await tester.pump();
    expect(find.text('Instruments'), findsNothing);
    await tester.tap(find.text('Process again').last);
    await tester.pumpAndSettle();
    expect(picked?.audioType, AudioContentType.vocals);
    expect(picked?.instruments, isEmpty);
  });
}
