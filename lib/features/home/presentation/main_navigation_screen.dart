import 'package:flutter/material.dart';

import '../../analytics/presentation/analytics_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../reports/presentation/reports_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, this.tabs});

  /// Overrides the four tab pages (used by layout tests).
  final List<Widget>? tabs;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  static const List<Widget> _defaultTabs = <Widget>[
    DashboardScreen(),
    AnalyticsScreen(),
    ReportsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: widget.tabs ?? _defaultTabs,
      ),
      bottomNavigationBar: _FittedLabels(
        labels: _labels,
        child: DecoratedBox(
          // Hairline separator so the bar reads as a surface in both themes.
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: <NavigationDestination>[
              for (int i = 0; i < _labels.length; i++)
                NavigationDestination(
                  icon: Icon(_icons[i]),
                  selectedIcon: Icon(_selectedIcons[i]),
                  label: _labels[i],
                  tooltip: _labels[i],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<String> _labels = <String>[
    'Home',
    'Analytics',
    'Reports',
    'Profile',
  ];
  static const List<IconData> _selectedIcons = <IconData>[
    Icons.dashboard_rounded,
    Icons.insights_rounded,
    Icons.description_rounded,
    Icons.person_rounded,
  ];
  static const List<IconData> _icons = <IconData>[
    Icons.dashboard_outlined,
    Icons.insights_outlined,
    Icons.description_outlined,
    Icons.person_outline_rounded,
  ];
}

/// Navigation labels cannot wrap (each item gets a fixed quarter of the
/// width). This keeps the user's font scale wherever the longest label fits
/// its slot and, only where it would be cut ("Analy…" on a narrow phone with a
/// large font), lowers the scale just enough for it to fit.
class _FittedLabels extends StatelessWidget {
  const _FittedLabels({required this.labels, required this.child});

  final List<String> labels;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final ThemeData theme = Theme.of(context);
    final TextStyle style =
        (theme.navigationBarTheme.labelTextStyle?.resolve(<WidgetState>{
                  WidgetState.selected,
                }) ??
                const TextStyle())
            .copyWith(fontSize: 14);
    double widest = 0;
    for (final String label in labels) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      widest = widest > painter.width ? widest : painter.width;
      painter.dispose();
    }
    final double slot = media.size.width / labels.length - 12;
    final double userScale = media.textScaler.scale(14) / 14;
    final double fitScale = widest <= 0 ? userScale : slot / widest;
    if (userScale <= fitScale) {
      return child;
    }
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(fitScale)),
      child: child,
    );
  }
}
