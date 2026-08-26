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
  double maxWidth = 480,
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
    // Capping width here, not just in the content inside, is what keeps a
    // wide desktop window from turning the sheet into an edge-to-edge
    // strip: Flutter centers a bottom sheet horizontally on its own once
    // its constraints give it a maxWidth short of the screen.
    constraints: BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: (media.size.height - breathingRoom).clamp(
        lowerBound,
        upperBound,
      ),
    ),
    builder: builder,
  );
}

/// Preferred width for an [AlertDialog]'s `content`, never wider than the
/// screen allows.
///
/// An [AlertDialog] does not scroll sideways, so a body fixed at its
/// preferred width overflows the moment the phone is narrower than that —
/// the dialog's own `insetPadding` (40 logical pixels on each side by
/// default) already eats into what is available before this even runs.
double appDialogWidth(BuildContext context, double preferred) {
  final available = MediaQuery.sizeOf(context).width - 80;
  return available < preferred ? available.clamp(200.0, preferred) : preferred;
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
    this.maxWidth = 400,
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
    this.maxWidth = 400,
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
    20,
    4,
    20,
    16 + MediaQuery.viewInsetsOf(context).bottom,
  );

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    return SafeArea(
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
