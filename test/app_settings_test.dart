import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/app_settings.dart';

void main() {
  test('preserva a preferência de idioma', () {
    const settings = AppSettings(localeCode: 'en');

    final restored = AppSettings.fromJson(settings.toJson());

    expect(restored.localeCode, 'en');
  });

  test('mantém compatibilidade com configurações antigas', () {
    final restored = AppSettings.fromJson(const {});

    expect(restored.localeCode, 'system');
  });
}
