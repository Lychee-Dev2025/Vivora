import 'package:flutter/material.dart';

/// AppBar title that never ends in an ellipsis.
///
/// An AppBar has room for one line beside the back button. When the user's
/// font size makes the title wider than that, it is scaled down only as far as
/// needed to fit; otherwise it is shown at full size.
class AppBarTitle extends StatelessWidget {
  const AppBarTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}
