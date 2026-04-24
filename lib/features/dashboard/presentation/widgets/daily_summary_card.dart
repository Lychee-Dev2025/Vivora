import 'package:flutter/material.dart';

import '../../../../core/widgets/info_card.dart';

class DailySummaryCard extends StatelessWidget {
  const DailySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Daily Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          Text(
            'You stayed focused for 3h 10m and reduced app switching by 18% compared to yesterday.',
          ),
        ],
      ),
    );
  }
}
