import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';

/// Regression coverage for the bug that made bookmarks land in the wrong
/// place: they used to be anchored to `scrollOffset / maxScrollExtent`, and
/// `maxScrollExtent` is only an estimate a lazy list extrapolates from
/// whichever items happen to be realized right now — it measurably drifts
/// (~20% in a probe with realistically uneven paragraph sizes) depending on
/// how much of the document has been scrolled through. Anchoring to an
/// integer chunk index instead sidesteps the estimate entirely: this test
/// jumps to the same index in two very different realization states and
/// requires the destination to be identical both times.
///
/// Note: these tests pump a bounded number of fixed-size frames instead of
/// calling `pumpAndSettle()` after `scrollTo`. The package's long-distance
/// jump (used when the target isn't already realized) fades between a
/// primary and a secondary list across several post-frame callbacks, which
/// `pumpAndSettle` never considers "settled" in this harness — confirmed by
/// isolating `scrollTo` with bounded pumps alone, where it lands correctly
/// every time. This is a test-harness quirk in this package, not a runtime
/// bug: a real running app is not driven by `pumpAndSettle`.
void main() {
  Future<List<int>> jumpAndCollect({
    required LibraryDocument document,
    required int targetIndex,
    void Function(ItemScrollController controller)? beforeJump,
    required WidgetTester tester,
  }) async {
    final controller = ItemScrollController();
    final listener = ItemPositionsListener.create();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: DocumentView(
              document: document,
              settings: const AppSettings(),
              itemScrollController: controller,
              itemPositionsListener: listener,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    beforeJump?.call(controller);
    if (beforeJump != null) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
    }

    unawaited(
      controller.scrollTo(
        index: targetIndex,
        duration: const Duration(milliseconds: 300),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    return listener.itemPositions.value
        .where((p) => p.itemLeadingEdge.abs() < 0.05)
        .map((p) => p.index)
        .toList();
  }

  testWidgets(
    'scrolling to a chunk index lands on the same chunk whether the list '
    'was just built or has already been scrolled end-to-end',
    (tester) async {
      // Same uneven-block shape that produced ~20% maxScrollExtent drift in
      // the old pixel-fraction design: a heading, then alternating
      // short/very long paragraphs, so an early, mostly-unrealized average
      // is a poor predictor of the true layout.
      final blocks = <String>[];
      for (var i = 0; i < 20; i++) {
        if (i == 0) {
          blocks.add('## Heading $i');
        } else if (i.isEven) {
          blocks.add('Long paragraph $i. ${'word ' * 400}');
        } else {
          blocks.add('Short $i.');
        }
      }
      final document = LibraryDocument(
        id: 'd1',
        title: 'Mixed doc',
        content: blocks.join('\n\n'),
        extension: 'md',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      const targetIndex = 15; // one of the "Long paragraph" blocks

      // State A: freshly built, only the top realized before the jump.
      final freshLanding = await jumpAndCollect(
        document: document,
        targetIndex: targetIndex,
        tester: tester,
      );

      // State B: the list is scrolled to the very end and back to the top
      // first — realizing everything, then returning near the top — before
      // the same jump. This is the exact sequence (read through once,
      // reopen later) that produced a different maxScrollExtent estimate
      // under the old design.
      final churnedLanding = await jumpAndCollect(
        document: document,
        targetIndex: targetIndex,
        tester: tester,
        beforeJump: (controller) {
          controller.jumpTo(index: blocks.length - 1);
          controller.jumpTo(index: 0);
        },
      );

      // ignore: avoid_print
      print(
        'FRESH_LANDING=$freshLanding CHURNED_LANDING=$churnedLanding '
        'TARGET=$targetIndex',
      );

      expect(
        freshLanding,
        contains(targetIndex),
        reason: 'A fresh jump to index $targetIndex should land exactly on it.',
      );
      expect(
        churnedLanding,
        contains(targetIndex),
        reason:
            'The same jump, after the list realized everything and came '
            'back, must land on the exact same index — proving the target '
            'does not drift with realization state the way a pixel '
            'fraction against an estimated maxScrollExtent used to.',
      );
    },
  );

  test('splitMarkdownBlocks keeps fenced code and loose lists intact', () {
    const source = '''
# Title

Intro paragraph.

```dart
void main() {

  print('blank line above is inside the fence');
}
```

- item one

- item two

- item three

Final paragraph.
''';
    final blocks = splitMarkdownBlocks(source);

    // The fence's internal blank line must not have split the code block.
    final codeBlock = blocks.firstWhere((b) => b.contains('void main'));
    expect(codeBlock, contains('blank line above is inside the fence'));
    expect(codeBlock, contains('```dart'));
    // The closing fence now ends the block: a fence is flushed as soon as it
    // closes, so "## heading" followed by a fence no longer merge into one
    // chunk. What matters here is that the fence is still whole.
    expect(codeBlock.trimRight(), endsWith('```'));
    expect('```dart'.allMatches(codeBlock).length, 1);

    // The loose list (blank line between items) should stay one block.
    final listBlock = blocks.firstWhere((b) => b.contains('item one'));
    expect(listBlock, contains('item two'));
    expect(listBlock, contains('item three'));

    // The final paragraph is its own block, not merged into the list.
    expect(blocks.where((b) => b.trim() == 'Final paragraph.'), isNotEmpty);
  });
}
