import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'reef_card.dart';
import 'reef_menu.dart';

/// Dialect-aware building blocks for the Settings screen (REDESIGN #14/#15,
/// §A.7). The Cupertino dialect renders inset-grouped `surface` cards under
/// uppercase faint section labels; the M3 dialect renders full-width rows
/// under `primary`-colored labels with hairline dividers between sections.
/// All dialect resolution happens in these widgets — the Settings screen
/// itself stays branch-free (CLAUDE.md rule).
class ReefSettingsList extends StatelessWidget {
  const ReefSettingsList({super.key, required this.sections});

  final List<ReefSettingsSection> sections;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final cupertino = reefCupertinoDialect(Theme.of(context).platform);
    return ListView(
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (!cupertino && i > 0)
            Container(
              height: 1,
              color: tokens.surfaceBorder,
              margin: const EdgeInsets.symmetric(vertical: 8),
            ),
          sections[i],
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// One settings group: an optional localized [label] over its [children] rows.
/// Cupertino: label 12.5 w500 `textFaint` uppercase + inset r14 card with
/// hairline dividers between rows; M3: label 12 w700 `primary` uppercase +
/// full-width rows (the divider between sections is [ReefSettingsList]'s).
class ReefSettingsSection extends StatelessWidget {
  const ReefSettingsSection({super.key, this.label, required this.children});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final cupertino = reefCupertinoDialect(Theme.of(context).platform);

    if (cupertino) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 22, 32, 8),
              child: Text(
                label!.toUpperCase(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.38, // 0.03 em of 12.5 px
                  color: tokens.textFaint,
                ),
              ),
            )
          else
            const SizedBox(height: 22),
          ReefCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            radius: 14,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Container(height: 1, color: tokens.surfaceBorder),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
            child: Text(
              label!.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6, // 0.05 em of 12 px
                color: tokens.primary,
              ),
            ),
          ),
        ...children,
      ],
    );
  }
}

/// One settings row: 19 px icon + title (+ optional description) + trailing
/// control. [onTap] makes the whole row a tap target — rows whose trailing is
/// a switch pass the toggle here too, preserving the old `SwitchListTile`
/// full-row behavior.
class ReefSettingsRow extends StatelessWidget {
  const ReefSettingsRow({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.titleColor,
    this.description,
    this.descriptionStyle,
    this.trailing,
    this.onTap,
  });

  final IconData? icon;

  /// Override for the warning rows (backup/sync failures use `error`);
  /// default `textDim`.
  final Color? iconColor;

  final String title;
  final Color? titleColor;
  final String? description;

  /// Override for the description line (the backup rows render their size
  /// sub-line in mono, REDESIGN #23); default 12 px `textFaint`.
  final TextStyle? descriptionStyle;

  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final cupertino = reefCupertinoDialect(Theme.of(context).platform);

    final row = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: cupertino
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 19, color: iconColor ?? tokens.textDim),
            SizedBox(width: cupertino ? 12 : 18),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: titleColor ?? tokens.text,
                  ),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description!,
                      style:
                          descriptionStyle ??
                          TextStyle(fontSize: 12, color: tokens.textFaint),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Trailing "current value + chevron" cluster for rows that push a subscreen
/// (§A.7: value 15 `textDim` on Cupertino / 15 w700 `text` on M3).
class ReefSettingsValue extends StatelessWidget {
  const ReefSettingsValue({super.key, this.value, this.mono = false});

  final String? value;

  /// Renders the value in the bundled mono family (numeric values like the
  /// reminder delivery time, REDESIGN #23).
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final cupertino = reefCupertinoDialect(Theme.of(context).platform);
    final style = cupertino
        ? TextStyle(fontSize: 15, color: tokens.textDim)
        : TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: tokens.text,
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null) ...[
          Text(
            value!,
            style: mono
                ? style.copyWith(fontFamily: ReefTokens.monoFamily)
                : style,
          ),
          const SizedBox(width: 8),
        ],
        Icon(Icons.chevron_right, size: 16, color: tokens.textFaint),
      ],
    );
  }
}

/// Trailing dropdown for the settings rows, styled per dialect: the closed
/// value renders like [ReefSettingsValue] (with a chevron on Cupertino, a
/// caret on M3); the open menu is the frosted [ReefMenuButton] panel with the
/// current choice checkmarked.
class ReefSettingsDropdown<T> extends StatelessWidget {
  const ReefSettingsDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final T value;

  /// `(value, label)` pairs in display order.
  final List<(T, String)> items;

  final ValueChanged<T> onChanged;

  /// When false the control is inert and the value renders dimmed.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final cupertino = reefCupertinoDialect(Theme.of(context).platform);
    var current = '';
    for (final (v, l) in items) {
      if (v == value) current = l;
    }
    final valueStyle = !enabled
        ? TextStyle(fontSize: 15, color: tokens.textFaint)
        : cupertino
        ? TextStyle(fontSize: 15, color: tokens.textDim)
        : TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: tokens.text,
          );
    return ReefMenuButton<T>(
      enabled: enabled,
      entries: [
        for (final (v, label) in items)
          ReefMenuItem(value: v, label: label, selected: v == value),
      ],
      onSelected: onChanged,
      // Matches the old DropdownButton's 48 px closed height so settings-row
      // layouts don't shift.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          // No Flexible here: the trailing slot of a settings row hands the
          // dropdown unbounded width, where flex children are illegal — the
          // closed value sizes intrinsically like the old DropdownButton did.
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current, style: valueStyle),
            const SizedBox(width: 4),
            Icon(
              cupertino ? Icons.chevron_right : Icons.expand_more,
              size: 16,
              color: cupertino ? tokens.textFaint : tokens.textDim,
            ),
          ],
        ),
      ),
    );
  }
}
