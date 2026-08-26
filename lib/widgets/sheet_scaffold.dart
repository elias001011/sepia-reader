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
}) {
  final media = MediaQuery.of(context);
  final breathingRoom = media.padding.top + 28;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: (media.size.height - breathingRoom).clamp(
        220.0,
        media.size.height,
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
  });

  final String title;
  final String? description;
  final List<Widget> children;

  /// Pinned below the scrolling body — a save button stays reachable however
  /// long the content is.
  final Widget? footer;

  /// Runs instead of popping, for a sheet that needs to ask something first
  /// (unsaved changes, most obviously).
  final Future<void> Function()? onClose;
  final double maxWidth;

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
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    4,
                    24,
                    16 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
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
