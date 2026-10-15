import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'word_safe_text.dart';

/// Lays cards out in rows whose column count follows the available width
/// **and** the user's font size.
///
/// * [minCardWidth] is the narrowest a card may be at 1.0 font scale; it grows
///   with the text scale, so a two-column grid becomes one column on a narrow
///   phone with large fonts instead of squeezing text.
/// * Each row is as tall as its tallest card ([EqualHeightRow]), so cards
///   grow with their content instead of overflowing a fixed
///   grid cell (the cause of "BOTTOM OVERFLOWED BY 69 PIXELS" on Badges).
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.minCardWidth = 100,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double spacing;
  final double minCardWidth;
  final int maxColumns;

  /// Column count for [width]; public so layouts and tests can reason about it.
  static int columnsFor({
    required double width,
    required double minCardWidth,
    required double textScale,
    required double spacing,
    required int maxColumns,
    required int itemCount,
  }) {
    final double effectiveMin = minCardWidth * textScale.clamp(1.0, 3.0);
    final int fit = ((width + spacing) / (effectiveMin + spacing)).floor();
    return fit.clamp(1, maxColumns).clamp(1, itemCount < 1 ? 1 : itemCount);
  }

  @override
  Widget build(BuildContext context) {
    final double textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = columnsFor(
          width: constraints.maxWidth,
          minCardWidth: minCardWidth,
          textScale: textScale,
          spacing: spacing,
          maxColumns: maxColumns,
          itemCount: children.length,
        );
        final List<Widget> rows = <Widget>[];
        for (int start = 0; start < children.length; start += columns) {
          final List<Widget> cells = <Widget>[
            for (int i = 0; i < columns; i++)
              start + i < children.length
                  ? children[start + i]
                  : const SizedBox.shrink(),
          ];
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
          rows.add(
            columns == 1
                ? cells.single
                : EqualHeightRow(spacing: spacing, children: cells),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }
}

/// A row of equal-width children that all take the height of the tallest one.
///
/// Unlike `IntrinsicHeight` + `Row`, this lays each child out normally (once to
/// measure, once at the shared height), so children may contain
/// `LayoutBuilder`s such as [WordSafeText].
class EqualHeightRow extends MultiChildRenderObjectWidget {
  const EqualHeightRow({super.key, required super.children, this.spacing = 12});

  final double spacing;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderEqualHeightRow(spacing);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderEqualHeightRow renderObject,
  ) {
    renderObject.spacing = spacing;
  }
}

class _EqualHeightRowParentData extends ContainerBoxParentData<RenderBox> {}

class RenderEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EqualHeightRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EqualHeightRowParentData> {
  RenderEqualHeightRow(this._spacing);

  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EqualHeightRowParentData) {
      child.parentData = _EqualHeightRowParentData();
    }
  }

  @override
  void performLayout() {
    final int count = childCount;
    if (count == 0) {
      size = constraints.constrain(Size.zero);
      return;
    }
    final double width = constraints.maxWidth;
    final double cell = (width - _spacing * (count - 1)) / count;
    double tallest = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: cell), parentUsesSize: true);
      if (child.size.height > tallest) tallest = child.size.height;
      child = childAfter(child);
    }
    double x = 0;
    child = firstChild;
    while (child != null) {
      // A minimum (not tight) height keeps the child from becoming a relayout
      // boundary: if its content changes later, this row is re-laid out and
      // re-measures instead of the child overflowing a stale fixed height.
      child.layout(
        BoxConstraints(minWidth: cell, maxWidth: cell, minHeight: tallest),
        parentUsesSize: true,
      );
      (child.parentData! as _EqualHeightRowParentData).offset = Offset(x, 0);
      x += cell + _spacing;
      child = childAfter(child);
    }
    double height = tallest;
    for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
      if (c.size.height > height) height = c.size.height;
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
