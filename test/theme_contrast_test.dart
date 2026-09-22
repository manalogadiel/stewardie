import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/theme.dart';

double contrast(Color a, Color b) {
  final values = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (values.last + .05) / (values.first + .05);
}

void main() {
  test('Soft Pop text and control color pairs have sufficient contrast', () {
    for (final background in [
      SoftPop.surface,
      SoftPop.canvas,
      SoftPop.blueSoft,
      SoftPop.warm,
      const Color(0xFFF1EEE7),
      const Color(0xFFF9EEE9),
      const Color(0xFFF0F2FE),
      const Color(0xFFF0EFEA),
    ]) {
      expect(contrast(SoftPop.ink, background), greaterThanOrEqualTo(4.5));
      expect(
        contrast(SoftPop.secondary, background),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(contrast(SoftPop.surface, SoftPop.blue), greaterThanOrEqualTo(4.5));
    expect(contrast(SoftPop.blue, SoftPop.blueSoft), greaterThanOrEqualTo(4.5));
    expect(
      contrast(SoftPop.controlBorder, SoftPop.surface),
      greaterThanOrEqualTo(3),
    );
  });
}
