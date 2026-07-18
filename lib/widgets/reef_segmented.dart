import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Dialect-styled segmented control (REDESIGN #15, §A.7), replacing the M3
/// [SegmentedButton] app-wide. The Cupertino dialect is a sliding-control
/// look: options sit in a `track` well and the active one rides a raised
/// chip; the M3 dialect is an outlined pill whose active option gets a
/// `healthySoft` fill and a small check icon. The dialect resolves from
/// `Theme.of(context).platform` here and only here — feature code stays
/// branch-free (CLAUDE.md rule).
class ReefSegmented<T> extends StatelessWidget {
  const ReefSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// `(value, label)` pairs in display order.
  final List<(T, String)> options;

  final T selected;

  /// Called with the tapped option's value (taps on the already-selected
  /// option repeat it — call sites treat writes as idempotent).
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final cupertino = reefCupertinoDialect(Theme.of(context).platform);
    return cupertino
        ? _buildCupertino(context, tokens)
        : _buildM3(context, tokens);
  }

  Widget _buildCupertino(BuildContext context, ReefTokens tokens) {
    // The raised chip must read against the `track` well; the dark `surface`
    // token is translucent white that would vanish over it, so dark mode
    // borrows the opaque elevated gray also used for drag proxies.
    final chipColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : tokens.surface;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: tokens.track,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in options)
            Semantics(
              button: true,
              selected: value == selected,
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: value == selected ? chipColor : null,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: value == selected
                        ? const [
                            BoxShadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Color(0x2E000000),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: value == selected ? tokens.text : tokens.textDim,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildM3(BuildContext context, ReefTokens tokens) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: tokens.surfaceBorder, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in options)
            InkWell(
              onTap: () => onChanged(value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                color: value == selected ? tokens.healthySoft : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (value == selected) ...[
                      Icon(Icons.check, size: 12, color: tokens.text),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: value == selected ? tokens.text : tokens.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
