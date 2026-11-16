import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';

/// The widest the content of a panel gets, however wide the window is.
const double kSheetContentMaxWidth = 880;

/// Opens a bottom sheet that stops short of the top of the screen.
///
/// A scroll-controlled sheet will otherwise grow until it covers everything,
/// including the notch and the front camera, which on a phone reads as the
/// app having swallowed the screen rather than as a panel over it. Leaving
/// the status bar and a finger's width above it visible keeps it a panel.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool enableDrag = true,
}) {
  final media = MediaQuery.of(context);
  final breathingRoom = media.padding.top + 28;
  // On desktop/web, cap at 80 % of the viewport so sheets feel like a panel,
  // not a full-screen takeover.
  final upperBound = media.size.height * 0.8;
  // The floor has to bend with the ceiling too: `clamp` throws outright when
  // its lower limit exceeds its upper one, so a viewport shorter than 220
  // logical pixels (a keyboard-squeezed phone, a tiny desktop window) would
  // otherwise crash every sheet on open — 220 stopped being a safe floor the
  // moment the ceiling could itself fall under 220.
  final lowerBound = math.min(220.0, upperBound);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // Dragging a sheet down calls Navigator.pop directly, which does not
    // consult PopScope — so a sheet holding unsaved changes must not be
    // draggable, or they vanish without the question being asked. The
    // handle goes with it, since it is what promises the gesture.
    enableDrag: enableDrag,
    showDragHandle: enableDrag,
    // The panel spans the whole window, as a bottom sheet does on a phone;
    // Material 3 would otherwise cap it at 640 px and float a narrow card
    // in the middle of a wide screen. What is capped is the content inside
    // (see SheetScaffold), so it never stretches across an enormous window.
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    constraints: BoxConstraints(
      maxWidth: double.infinity,
      maxHeight: (media.size.height - breathingRoom).clamp(
        lowerBound,
        upperBound,
      ),
    ),
    // The keyboard inset is applied once, here: the sheet itself grows above
    // the keyboard instead of the fields scooting up inside a sheet that is
    // still sitting behind it.
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: builder(sheetContext),
    ),
  );
}

/// Asks a yes/no question in the shared panel. Resolves to false when the
/// sheet is closed without answering.
Future<bool> showSheetConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final confirmed = await showAppSheet<bool>(
    context: context,
    builder: (sheetContext) => SheetPrompt(
      title: title,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(sheetContext, false),
          child: Text(cancelLabel ?? sheetContext.l10n.cancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(sheetContext).colorScheme.error,
                  foregroundColor: Theme.of(sheetContext).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(sheetContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A short confirmation or a small form in the same panel as the rest of the
/// app: the bookmarks list, the settings, a rename, a delete.
///
/// [actions] go in the footer, where they stay reachable however long the body
/// is; leave it empty for a sheet that only shows something.
class SheetPrompt extends StatelessWidget {
  const SheetPrompt({
    super.key,
    required this.title,
    required this.content,
    this.description,
    this.actions = const [],
  });

  final String title;
  final String? description;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: title,
    description: description,
    footer: actions.isEmpty
        ? null
        : OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            children: actions,
          ),
    children: [content],
  );
}

/// Shared frame for the app's bottom sheets: a title, an optional line of
/// explanation, a close button, and a scrolling body that never grows wider
/// than a comfortable measure.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.footer,
    this.onClose,
    this.maxWidth = kSheetContentMaxWidth,
  }) : itemCount = null,
       itemBuilder = null;

  /// A sheet whose body is a long list, built lazily.
  ///
  /// A chapter picker for a book-length document has hundreds of entries,
  /// and a Column inside a scroll view builds every one of them in the frame
  /// the sheet opens.
  const SheetScaffold.list({
    super.key,
    required this.title,
    required int this.itemCount,
    required Widget? Function(BuildContext, int) this.itemBuilder,
    this.description,
    this.footer,
    this.onClose,
    this.maxWidth = kSheetContentMaxWidth,
  }) : children = const [];

  final String title;
  final String? description;
  final List<Widget> children;
  final int? itemCount;
  final Widget? Function(BuildContext, int)? itemBuilder;

  /// Pinned below the scrolling body — a save button stays reachable however
  /// long the content is.
  final Widget? footer;

  /// Runs instead of popping, for a sheet that needs to ask something first
  /// (unsaved changes, most obviously).
  final Future<void> Function()? onClose;
  final double maxWidth;

  static const _bodyPadding = EdgeInsets.fromLTRB(20, 4, 20, 16);

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    // Escape closes on a desktop keyboard. The modal barrier is the pointer
    // equivalent; both end up in the same place, including the unsaved-changes
    // question when there is one.
    void close() {
      final askFirst = onClose;
      if (askFirst != null) {
        askFirst();
      } else {
        Navigator.pop(context);
      }
    }

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
      child: SafeArea(
        top: false,
        // `heightFactor: 1.0` matters: given a bounded height (the sheet's
        // own maxHeight), plain `Center` sizes itself to fill all of it
        // before centering its child — Flutter says so explicitly in its own
        // docs — which is what left a slab of empty sheet below any content
        // shorter than that cap. `heightFactor` pins Center's height to the
        // child's instead. Width is left alone: expanding-then-capping via
        // the `ConstrainedBox` below is exactly what centers it, and a
        // `Row` here (tried first) does the capping wrong — a Row hands
        // non-flex children an *unbounded* main axis, so the ConstrainedBox
        // renders at its full maxWidth and overflows on anything narrower.
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonLabel,
                        onPressed: close,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Flexible(
                  child: itemBuilder == null
                      ? SingleChildScrollView(
                          padding: _bodyPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: children,
                          ),
                        )
                      : ListView.builder(
                          padding: _bodyPadding,
                          shrinkWrap: true,
                          itemCount: itemCount,
                          itemBuilder: itemBuilder!,
                        ),
                ),
                if (footer != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: footer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
