import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/utils/friendly_error.dart';
import 'package:vivora/core/widgets/ui_kit.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import 'package:vivora/core/widgets/app_bar_title.dart';

import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/responsive_card_grid.dart';
import '../../analytics/data/analytics_calculator.dart';
import '../../insights/services/insights_service.dart';
import '../data/badge_service.dart';

/// Loads earned badges, then renders [BadgesView].
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _badgeService = BadgeService();
  Map<String, DateTime>? _unlocked;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await InsightsService.instance.ensureLoaded();
      if (snapshot == null) {
        if (mounted) setState(() => _unlocked = const <String, DateTime>{});
        return;
      }
      final unlocked = await _badgeService.sync(user.uid, snapshot.history);
      if (mounted) setState(() => _unlocked = unlocked);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = friendlyError(error, action: 'load your badges'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => BadgesView(
    unlocked: _unlocked,
    error: _error,
    onRetry: () {
      setState(() => _error = null);
      _load();
    },
  );
}

/// The Badges layout. [unlocked] is null while loading.
class BadgesView extends StatelessWidget {
  const BadgesView({
    super.key,
    required this.unlocked,
    this.error,
    this.onRetry,
  });

  final Map<String, DateTime>? unlocked;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final Map<String, DateTime>? unlocked = this.unlocked;
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle('Badges')),
      body: GradientBackground(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: <Widget>[
            Text(
              'Achievements',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              unlocked == null
                  ? 'Checking your records…'
                  : '${unlocked.length} of ${BadgeService.all.length} unlocked. Badges are awarded from your saved logs, focus sessions and measured usage.',
            ),
            if (error != null) ...[
              const SizedBox(height: Space.md),
              StateMessage.error(message: error!, onAction: onRetry),
            ],
            if (unlocked != null && unlocked.isEmpty && error == null) ...[
              const SizedBox(height: Space.md),
              const StateMessage(
                icon: Icons.emoji_events_outlined,
                title: 'No badges yet',
                message:
                    'Save your first daily log or finish a Focus Mode session to earn your first badge.',
              ),
            ],
            const SizedBox(height: 20),
            if (unlocked == null)
              const LinearProgressIndicator()
            else
              // Content-sized rows instead of a fixed 210 px grid cell; two
              // columns while they fit, one column on narrow screens or with
              // large fonts.
              ResponsiveCardGrid(
                spacing: 14,
                minCardWidth: 150,
                maxColumns: 3,
                children: <Widget>[
                  for (final BadgeDefinition badge in BadgeService.all)
                    BadgeCard(badge: badge, unlockedAt: unlocked[badge.id]),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// One achievement: icon, full title, full requirement, status and date.
/// Height follows the content; no text is truncated. Status is written out
/// (not shown by colour alone).
class BadgeCard extends StatelessWidget {
  const BadgeCard({super.key, required this.badge, required this.unlockedAt});

  final BadgeDefinition badge;
  final DateTime? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final VivoraPalette p = context.palette;
    final bool unlocked = unlockedAt != null;
    final Color accent = unlocked ? badge.color : p.textSecondary;
    return Semantics(
      label: '${badge.title}, ${unlocked ? 'unlocked' : 'locked'}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.lg,
        ),
        decoration: BoxDecoration(
          color: unlocked
              ? Color.alphaBlend(badge.color.withValues(alpha: 0.08), p.surface)
              : p.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: unlocked ? badge.color.withValues(alpha: 0.55) : p.border,
            width: unlocked ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(Space.md),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: unlocked ? 0.18 : 0.10),
                  ),
                  child: Icon(
                    badge.icon,
                    size: 34,
                    color: unlocked
                        ? badge.color
                        : p.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.surface,
                    ),
                    child: Icon(
                      unlocked
                          ? Icons.check_circle_rounded
                          : Icons.lock_rounded,
                      size: 18,
                      color: unlocked ? p.success : p.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              softWrap: true,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: Space.xs),
            Text(
              badge.requirement,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontSize: 12.5,
                color: p.textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: Space.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (unlocked ? p.success : p.textSecondary).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Text(
                unlocked
                    ? 'Unlocked ${AnalyticsCalculator.formatDate(unlockedAt!)}'
                    : 'Locked',
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontSize: 12,
                  color: unlocked ? p.success : p.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
