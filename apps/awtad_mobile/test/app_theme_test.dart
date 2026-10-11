import 'package:awtad_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('brand colors match the visual identity', () {
    expect(AppTheme.brand, const Color(0xFF0B5C4D));
    expect(AppTheme.seeds, hasLength(5));
    expect(AppTheme.light(AppTheme.brand).colorScheme.primary, AppTheme.brand);
    expect(AppTheme.dark(AppTheme.brand).brightness, Brightness.dark);
  });
}
