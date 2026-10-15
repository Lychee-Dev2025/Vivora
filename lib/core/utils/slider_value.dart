double normalizeSliderValue(
  double value, {
  required double min,
  required double max,
}) {
  if (!value.isFinite) {
    return min;
  }
  return value.clamp(min, max).toDouble();
}
