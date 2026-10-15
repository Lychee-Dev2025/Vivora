import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

import 'word_safe_text.dart';

/// One row of a usage list:
///
/// ```
/// [icon]  WhatsApp            13m
///         Neutral
/// ```
///
/// The name and secondary line share the flexible left column and may wrap;
/// the value has its own right-aligned column that is never squeezed, so
/// durations stay aligned and nothing overlaps.
class SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final String? iconBase64;
  final String? subtitle;

  const SummaryTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconBase64,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: UsageRow(
        label: label,
        value: value,
        subtitle: subtitle,
        leading: icon == null && iconBase64 == null
            ? null
            : Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: iconBase64 == null
                    ? Icon(icon, color: context.brand, size: 20)
                    : Image.memory(
                        base64Decode(iconBase64!),
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          icon ?? Icons.apps_rounded,
                          color: context.brand,
                          size: 20,
                        ),
                      ),
              ),
      ),
    );
  }
}

/// Name (+ optional secondary line) on the left, value right-aligned.
class UsageRow extends StatelessWidget {
  const UsageRow({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.leading,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (leading != null) ...<Widget>[leading!, const SizedBox(width: 14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              WordSafeText(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                WordSafeText(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 15,
            color: context.palette.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
