/// Shared visual and semantic shell for inventory cards.
///
/// Family widgets keep their status/control bodies. This frame only owns the
/// repeated title, overflow affordance, connection state, spacing and card
/// semantics.
library;

import 'package:flutter/material.dart';

class DeviceCardFrame extends StatelessWidget {
  const DeviceCardFrame({
    super.key,
    required this.title,
    required this.menuItems,
    required this.onMenuSelected,
    required this.body,
    this.loading = false,
    this.errorText,
    this.errorContent,
    this.headerTrailing,
  });

  final String title;
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<String> onMenuSelected;
  final Widget body;
  final bool loading;
  final String? errorText;
  final Widget? errorContent;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: textTheme.titleMedium),
                    ),
                  ),
                  ?headerTrailing,
                  PopupMenuButton<String>(
                    onSelected: onMenuSelected,
                    itemBuilder: (_) => menuItems,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else if (errorContent case final content?)
                Semantics(liveRegion: true, child: content)
              else if (errorText case final error?)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: textTheme.bodyMedium?.copyWith(color: colors.error),
                  ),
                )
              else
                body,
            ],
          ),
        ),
      ),
    );
  }
}
