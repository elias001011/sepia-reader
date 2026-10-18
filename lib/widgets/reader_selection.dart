import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';

/// Keep visited blocks alive during a drag selection. Recycling a selected
/// render paragraph invalidates the native selection handles and copy menu.
/// Release them as soon as the selection is cleared, preserving normal culling.
class ReaderSelection extends StatefulWidget {
  const ReaderSelection({
    super.key,
    required this.source,
    required this.builder,
  });
  final String source;
  final Widget Function(ValueListenable<bool> selecting) builder;

  @override
  State<ReaderSelection> createState() => _ReaderSelectionState();
}

class _ReaderSelectionState extends State<ReaderSelection> {
  final _selecting = ValueNotifier(false);

  @override
  void dispose() {
    _selecting.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionArea(
    onSelectionChanged: (selection) {
      final active = selection != null && selection.plainText.isNotEmpty;
      if (_selecting.value != active) _selecting.value = active;
    },
    contextMenuBuilder: (context, state) =>
        AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            // Select all on a lazy list only selects realized blocks, and can
            // invalidate the menu while off-screen blocks register/dispose.
            // Copy the full source directly instead, without expanding the list.
            for (final item in state.contextMenuButtonItems)
              if (item.type != ContextMenuButtonType.selectAll)
                item.type == ContextMenuButtonType.copy
                    ? ContextMenuButtonItem(
                        type: item.type,
                        label: item.label,
                        onPressed: () {
                          item.onPressed?.call();
                          state.clearSelection();
                        },
                      )
                    : item,
            ContextMenuButtonItem(
              label: context.l10n.copyDocument,
              onPressed: () async {
                state.hideToolbar();
                try {
                  await Clipboard.setData(ClipboardData(text: widget.source));
                  if (mounted) state.clearSelection();
                  if (context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(content: Text(context.l10n.copiedDocument)),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(content: Text(context.l10n.copyFailed)),
                    );
                  }
                }
              },
            ),
          ],
        ),
    child: widget.builder(_selecting),
  );
}

class SelectionBlock extends StatefulWidget {
  const SelectionBlock({
    super.key,
    required this.selecting,
    required this.child,
  });
  final ValueListenable<bool> selecting;
  final Widget child;

  @override
  State<SelectionBlock> createState() => _SelectionBlockState();
}

class _SelectionBlockState extends State<SelectionBlock>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.selecting.value;

  @override
  void initState() {
    super.initState();
    widget.selecting.addListener(_changed);
  }

  void _changed() {
    // Selection notifications may arrive during layout. KeepAlive mutates
    // the sliver's parent data, so schedule it after that frame completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) updateKeepAlive();
    });
  }

  @override
  void didUpdateWidget(covariant SelectionBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selecting != widget.selecting) {
      oldWidget.selecting.removeListener(_changed);
      widget.selecting.addListener(_changed);
      _changed();
    }
  }

  @override
  void dispose() {
    widget.selecting.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
