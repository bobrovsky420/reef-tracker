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
    // Each section is a `SliverMainAxisGroup` with a *pinned* label sliver:
    // the label sticks below the app bar while any of its section is still on
    // screen, then the next section's label pushes it out.
    return CustomScrollView(
      slivers: [
        for (var i = 0; i < sections.length; i++) ...[
          if (!cupertino && i > 0)
            SliverToBoxAdapter(
              child: Container(
                height: 1,
                color: tokens.surfaceBorder,
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          SliverMainAxisGroup(
            slivers: [
              if (sections[i].label case final label?)
                _StickySectionLabel(label: label, cupertino: cupertino)
              else if (cupertino)
                const SliverToBoxAdapter(child: SizedBox(height: 22)),
              SliverToBoxAdapter(child: sections[i]._content(context)),
            ],
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// One settings group: an optional localized [label] over its [children] rows.
/// Cupertino: label 12.5 w500 `textFaint` uppercase + inset r14 card with
/// hairline dividers between rows; M3: label 12 w700 `primary` uppercase +
/// full-width rows (the divider between sections is [ReefSettingsList]'s).
/// Inside a [ReefSettingsList] the label is rendered by the list as a sticky
/// sliver; [build] keeps the plain in-flow label + content for box usage
/// (the import-sources screen's plain `ListView`).
class ReefSettingsSection extends StatelessWidget {
  const ReefSettingsSection({super.key, this.label, required this.children});

  final String? label;
  final List<Widget> children;

  /// The section body without its label: the Cupertino inset card of
  /// hairline-divided rows / the M3 full-width row column.
  Widget _content(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final cupertino = reefCupertinoDialect(Theme.of(context).platform);
    if (cupertino) {
      return ReefCard(
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
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final cupertino = reefCupertinoDialect(Theme.of(context).platform);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: cupertino
                ? const EdgeInsets.fromLTRB(32, 22, 32, 8)
                : const EdgeInsets.fromLTRB(20, 22, 20, 10),
            child: Text(
              label!.toUpperCase(),
              style: _sectionLabelStyle(tokens, cupertino),
            ),
          )
        else if (cupertino)
          const SizedBox(height: 22),
        _content(context),
      ],
    );
  }
}

/// The dialect section-label typography (§A.7), shared by the in-flow and
/// sticky renderings.
TextStyle _sectionLabelStyle(
  ReefTokens tokens,
  bool cupertino, {
  double? height,
}) => cupertino
    ? TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.38, // 0.03 em of 12.5 px
        height: height,
        color: tokens.textFaint,
      )
    : TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6, // 0.05 em of 12 px
        height: height,
        color: tokens.primary,
      );

/// The sticky section label: pins below the app bar while its
/// [SliverMainAxisGroup] section is on screen. Fixed extent = 22 top gap +
/// dialect bottom gap + one text line (explicit line height so the extent
/// stays exact under any system text scale).
class _StickySectionLabel extends StatelessWidget {
  const _StickySectionLabel({required this.label, required this.cupertino});

  final String label;
  final bool cupertino;

  static const _lineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final fontSize = cupertino ? 12.5 : 12.0;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickySectionLabelDelegate(
        label: label,
        cupertino: cupertino,
        extent: 22 + (cupertino ? 8 : 10) + scaler.scale(fontSize) * _lineHeight,
      ),
    );
  }
}

class _StickySectionLabelDelegate extends SliverPersistentHeaderDelegate {
  const _StickySectionLabelDelegate({
    required this.label,
    required this.cupertino,
    required this.extent,
  });

  final String label;
  final bool cupertino;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final tokens = ReefTokens.of(context);
    // Pinned over scrolled rows once the label's own scroll offset is
    // consumed (`shrinkOffset` > 0; `overlapsContent` alone only reports
    // overlap from *preceding* slivers, e.g. a pinned app bar).
    final pinnedOverRows = shrinkOffset > 0 || overlapsContent;
    return Container(
      // Opaque only while rows scroll beneath — at rest the app-wide
      // background gradient shows through, matching the in-flow label.
      color: pinnedOverRows ? tokens.scaffoldBody : null,
      padding: cupertino
          ? const EdgeInsetsDirectional.only(start: 32, end: 32, bottom: 8)
          : const EdgeInsetsDirectional.only(start: 20, end: 20, bottom: 10),
      alignment: AlignmentDirectional.bottomStart,
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _sectionLabelStyle(
          tokens,
          cupertino,
          height: _StickySectionLabel._lineHeight,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickySectionLabelDelegate oldDelegate) =>
      label != oldDelegate.label ||
      cupertino != oldDelegate.cupertino ||
      extent != oldDelegate.extent;
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
