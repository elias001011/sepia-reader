import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';

/// The widest a panel ever gets, however wide the window is.
const double kSheetMaxWidth = 560;

/// The narrowest a panel gets on a window wide enough to have margins.
const double _sheetMinWidth = 360;

/// Below this window width the panel simply spans it, as bottom sheets do on a
/// phone held upright.
const double _sheetFullWidthBelow = 520;

/// Past this many rows a list is built lazily and the panel takes the full
/// [kSheetMaxWidth]: measuring what a hundred chapter titles want is not worth
/// building all of them.
const int _eagerListLimit = 40;

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
  double maxWidth = kSheetMaxWidth,
}) {
  final media = MediaQuery.of(context);
  // A notch or gesture bar on one side of a landscape phone must not push
  // the panel off-center, so the room it takes is reserved on both sides.
  final sideInset = math.max(media.padding.left, media.padding.right);
  final availableWidth = media.size.width - 2 * sideInset;
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
    // This is only the ceiling. Inside it the panel is as wide as its
    // content asks (see SheetScaffold), and Flutter centers a bottom sheet
    // horizontally on its own once the width is short of the screen.
    constraints: BoxConstraints(
      maxWidth: math.min(maxWidth, availableWidth),
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
/// explanation, a close button, and a scrolling body.
///
/// The panel is as wide as its content, between a floor and [kSheetMaxWidth],
/// on every platform; a window narrower than a phone held upright gets the
/// whole width.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.footer,
    this.onClose,
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

    final narrow = MediaQuery.sizeOf(context).width < _sheetFullWidthBelow;
    final lazy = itemBuilder != null && (itemCount ?? 0) > _eagerListLimit;

    Widget body;
    if (itemBuilder == null) {
      body = SingleChildScrollView(
        padding: _bodyPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    } else if (lazy) {
      body = ListView.builder(
        padding: _bodyPadding,
        shrinkWrap: true,
        itemCount: itemCount,
        itemBuilder: itemBuilder!,
      );
    } else {
      // A short list is laid out eagerly: a lazy viewport cannot report how
      // wide its rows want to be, and that is what sizes the panel.
      body = SingleChildScrollView(
        padding: _bodyPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < itemCount!; i++) ?itemBuilder!(context, i),
          ],
        ),
      );
    }

    final column = Column(
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
                tooltip: MaterialLocalizations.of(context).closeButtonLabel,
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
        Flexible(child: body),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: footer,
          ),
      ],
    );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
      // Side insets are not applied here: showAppSheet already keeps the
      // panel clear of them on both sides, so it stays centered.
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        // `heightFactor: 1.0` matters: given a bounded height (the sheet's
        // own maxHeight), plain `Center` sizes itself to fill all of it
        // before centering its child, which left a slab of empty sheet below
        // any content shorter than that cap. `widthFactor: 1.0` does the same
        // for width, so the panel wraps its content instead of spanning the
        // window.
        child: Center(
          heightFactor: 1.0,
          widthFactor: 1.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // A floor equal to the ceiling is clamped to the window by the
              // parent's maximum, which is how a narrow window gets the full
              // width.
              minWidth: narrow || lazy ? kSheetMaxWidth : _sheetMinWidth,
              maxWidth: kSheetMaxWidth,
            ),
            child: lazy ? column : IntrinsicWidth(child: column),
          ),
        ),
      ),
    );
  }
}
