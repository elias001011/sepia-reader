import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sepia_reader/services/update_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Client releaseClient(Map<String, dynamic> body, {int status = 200}) =>
    MockClient((request) async => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ));

Map<String, dynamic> release(String tag) => {
  'tag_name': tag,
  'html_url': 'https://github.com/elias001011/sepia-reader/releases/tag/$tag',
  'body': 'Novidades desta versão.',
  'assets': [
    {
      'name': 'sepia-${tag.substring(1)}-android-universal.apk',
      'browser_download_url': 'https://example.com/universal.apk',
    },
    {
      'name': 'sepia-${tag.substring(1)}-android-arm64-v8a.apk',
      'browser_download_url': 'https://example.com/arm64.apk',
    },
    {
      'name': 'sepia-${tag.substring(1)}-web.tar.gz',
      'browser_download_url': 'https://example.com/web.tar.gz',
    },
  ],
};

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Sépia',
      packageName: 'digital.connectabr.sepia',
      version: '2.0.0',
      buildNumber: '11',
      buildSignature: '',
    );
  });

  group('compareVersions', () {
    test('compara número a número, não texto a texto', () {
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('1.9.0', '1.10.0'), lessThan(0));
      expect(compareVersions('2.0.0', '2.0.0'), 0);
      expect(compareVersions('2.0.1', '2.0.0'), greaterThan(0));
      expect(compareVersions('2.0', '2.0.0'), 0);
      expect(compareVersions('2.0.0+11', '2.0.0+10'), greaterThan(0));
    });
  });

  test('uma release mais nova é reportada', () async {
    final checker = UpdateChecker(client: releaseClient(release('v2.1.0')));
    final update = await checker.check(force: true);
    expect(update, isNotNull);
    expect(update!.version, '2.1.0');
    expect(update.notes, 'Novidades desta versão.');
    expect(update.pageUrl, contains('v2.1.0'));
  });

  test('a mesma versão, ou mais velha, não é reportada', () async {
    expect(
      await UpdateChecker(client: releaseClient(release('v2.0.0')))
          .check(force: true),
      isNull,
    );
    expect(
      await UpdateChecker(client: releaseClient(release('v1.9.9')))
          .check(force: true),
      isNull,
    );
  });

  test('um erro do servidor é reportado, não engolido', () async {
    final checker = UpdateChecker(
      client: releaseClient(const {}, status: 503),
    );
    await expectLater(
      checker.check(force: true),
      throwsA(isA<HttpExceptionLike>()),
    );
  });

  test('não pergunta de novo antes da hora', () async {
    final checker = UpdateChecker(client: releaseClient(release('v2.1.0')));
    expect(await checker.isDueForCheck(), isTrue);
    await checker.check(force: true);
    expect(
      await checker.isDueForCheck(),
      isFalse,
      reason: 'uma consulta por abertura de app seria pedir demais por uma '
          'resposta que muda poucas vezes por mês',
    );
    // But an explicit "check now" always goes through.
    expect(await checker.check(force: true), isNotNull);
    expect(await checker.check(), isNull);
  });

  test('a versão em execução vem do pacote', () async {
    expect(await UpdateChecker(client: releaseClient(const {})).currentVersion(),
        '2.0.0');
  });
}
