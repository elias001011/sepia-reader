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

  test('preserva as preferências de sincronização', () {
    const settings = AppSettings(
      syncEnabled: false,
      syncServerUrl: 'http://192.168.2.5:8888',
    );

    final restored = AppSettings.fromJson(settings.toJson());

    expect(restored.syncEnabled, isFalse);
    expect(restored.syncServerUrl, 'http://192.168.2.5:8888');
  });

  test('sincronização vem desligada por padrão', () {
    final restored = AppSettings.fromJson(const {});

    expect(restored.syncEnabled, isFalse);
    expect(restored.syncServerUrl, isEmpty);
  });

  test('preferência de sincronização já salva é preservada', () {
    // Mudar o padrão não pode desligar o sync de quem já o havia ligado: a
    // chave está presente no payload salvo desses aparelhos.
    final restored = AppSettings.fromJson(const {
      'syncEnabled': true,
      'syncServerUrl': 'http://192.168.2.5:8888',
    });

    expect(restored.syncEnabled, isTrue);
    expect(restored.syncServerUrl, 'http://192.168.2.5:8888');
  });
}
