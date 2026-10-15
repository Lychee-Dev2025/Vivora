import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

import '../../../../core/constants/app_assets.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(
          child: Container(
            width: 84,
            height: 84,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.palette.surface.withValues(alpha: 0.8),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: context.palette.shadow,
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Image.asset(AppAssets.logo, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          'Welcome to Vivora',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Build routines, track growth, and stay in control of your student life.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.palette.textSecondary),
        ),
      ],
    );
  }
}
