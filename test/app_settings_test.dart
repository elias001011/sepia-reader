import 'package:flutter/material.dart';
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
    expect(restored.amoledTheme, isFalse);
    expect(restored.readerFollowsTheme, isFalse);
    expect(restored.autoHideReaderControls, isFalse);
  });

  test('preserva AMOLED, fundo escuro e integração do leitor', () {
    const settings = AppSettings(
      amoledTheme: true,
      darkAppBackground: Color(0xFF102030),
      readerFollowsTheme: true,
      autoHideReaderControls: true,
    );

    final restored = AppSettings.fromJson(settings.toJson());

    expect(restored.amoledTheme, isTrue);
    expect(restored.darkAppBackground, const Color(0xFF102030));
    expect(restored.readerFollowsTheme, isTrue);
    expect(restored.autoHideReaderControls, isTrue);
  });
}
