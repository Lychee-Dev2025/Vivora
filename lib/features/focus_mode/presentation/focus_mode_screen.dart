import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/info_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> {
  bool _sessionActive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Focus Mode')),
      body: GradientBackground(
        child: ListView(
          children: <Widget>[
            Text(
              'Deep Focus Session',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Stay present, block distractions, and finish stronger.',
            ),
            const SizedBox(height: 18),
            InfoCard(
              gradient: AppColors.highlightGradient,
              child: Column(
                children: <Widget>[
                  Text(
                    _sessionActive ? 'Session Running' : 'Ready to Focus',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _sessionActive ? '24:18' : '25:00',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _sessionActive
                        ? 'Keep going. You are in your best focus zone.'
                        : 'Start a session when you are ready.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: PrimaryButton(
                    label: 'Start Focus Session',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _sessionActive
                        ? null
                        : () {
                            setState(() {
                              _sessionActive = true;
                            });
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Stop Session',
              expanded: true,
              onPressed: _sessionActive
                  ? () {
                      setState(() {
                        _sessionActive = false;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 18),
            const InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Blocked Distractions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 10),
                  Text('Social Media Apps (placeholder)'),
                  SizedBox(height: 6),
                  Text('Short Video Apps (placeholder)'),
                  SizedBox(height: 6),
                  Text('Gaming Apps (placeholder)'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Session History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 10),
                  Text('Today  -  2 sessions  -  52m'),
                  SizedBox(height: 4),
                  Text('Yesterday  -  3 sessions  -  1h 18m'),
                  SizedBox(height: 4),
                  Text('Mon  -  1 session  -  25m'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
