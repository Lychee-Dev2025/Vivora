import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/vivora_palette.dart';

/// Circle with the user's initials (no photo upload exists, so no fake
/// camera control).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 64});

  final String name;
  final double size;

  static String initialsOf(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final String first = parts.first.characters.first;
    final String last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Avatar for ${name.isEmpty ? 'user' : name}',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.buttonGradient,
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.18),
          child: FittedBox(
            child: Text(
              initialsOf(name),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled group of rows on a card (Profile, Settings).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final VivoraPalette p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: Space.xs, bottom: Space.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: p.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: p.border),
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, indent: 56, color: p.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row inside a [SectionCard]: icon, title, optional value/subtitle.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.trailing,
    this.color,
  });

  final IconData icon;
  final String title;

  /// Shown under the title (wraps); "Not set" style when empty.
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final VivoraPalette p = context.palette;
    final Color iconColor = color ?? Theme.of(context).colorScheme.primary;
    final bool empty = value != null && value!.trim().isEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md,
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color ?? p.textPrimary,
                      ),
                    ),
                    if (value != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        empty ? 'Not set' : value!,
                        style: TextStyle(
                          color: p.textSecondary,
                          fontStyle: empty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: Space.sm),
                trailing!,
              ] else if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: p.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty or error message with an optional action (e.g. Retry).
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  const StateMessage.error({
    super.key,
    required this.message,
    this.onAction,
    this.actionLabel = 'Retry',
  }) : icon = Icons.cloud_off_rounded,
       title = 'Something went wrong',
       isError = true;

  final IconData icon;
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final VivoraPalette p = context.palette;
    final Color accent = isError
        ? p.danger
        : Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: isError ? p.danger.withValues(alpha: 0.4) : p.border,
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: accent, size: 32),
          if (title != null) ...<Widget>[
            const SizedBox(height: Space.sm),
            Text(
              title!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: Space.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: Space.md),
            TextButton.icon(
              onPressed: onAction,
              icon: Icon(
                isError ? Icons.refresh_rounded : Icons.arrow_forward_rounded,
              ),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
