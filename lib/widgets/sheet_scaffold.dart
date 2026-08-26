import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // Dragging a sheet down calls Navigator.pop directly, which does not
    // consult PopScope — so a sheet holding unsaved changes must not be
    // draggable, or they vanish without the question being asked. The
    // handle goes with it, since it is what promises the gesture.
    enableDrag: enableDrag,
    showDragHandle: enableDrag,
    constraints: BoxConstraints(
      // The lower bound has to bend too: `clamp` throws outright when the
      // lower limit exceeds the upper, so a browser window shorter than the
      // minimum would have crashed every sheet on open.
      maxHeight: (media.size.height - breathingRoom).clamp(
        math.min(220.0, media.size.height),
        // Cap at 700 px so sheets don't swallow the whole browser window
        // on a tall desktop monitor.
        math.min(media.size.height, 700.0),
      ),
    ),
    builder: builder,
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
    this.maxWidth = 560,
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
    this.maxWidth = 560,
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

  static EdgeInsets _bodyPadding(BuildContext context) => EdgeInsets.fromLTRB(
    24,
    4,
    24,
    16 + MediaQuery.viewInsetsOf(context).bottom,
  );

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    return SafeArea(
      top: false,
      child: Center(
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
                      tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                      onPressed: () {
                        final close = onClose;
                        if (close != null) {
                          close();
                        } else {
                          Navigator.pop(context);
                        }
                      },
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
                        padding: _bodyPadding(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      )
                    : ListView.builder(
                        padding: _bodyPadding(context),
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
    );
  }
}
