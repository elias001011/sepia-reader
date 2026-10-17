import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/services/storage_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tokens authenticate writes and never enter synced settings', () async {
    Map<String, dynamic>? sent;
    final storage = StorageService(
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer private-test-token');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(request.body, 200);
      }),
    );
    await storage.saveSyncConfig(
      const SyncConfig(
        enabled: true,
        serverUrl: 'http://example.test',
        token: 'private-test-token',
      ),
    );
    await storage.saveSettings(
      const AppSettings(
        syncEnabled: true,
        syncServerUrl: 'http://example.test',
        syncToken: 'private-test-token',
      ),
    );
    await storage.waitForPendingSync();
    expect(sent, isNotNull);
    expect(sent!.containsKey('syncToken'), isFalse);
    expect(sent!.containsKey('syncServerUrl'), isFalse);
    final reloaded = await storage.loadLocalSettings();
    expect(reloaded.syncToken, 'private-test-token');
  });

  test('connection test checks access on token-protected servers', () async {
    final storage = StorageService(
      client: MockClient((request) async {
        if (request.url.path == '/healthz') {
          return http.Response('{"ok":true,"authentication":true}', 200);
        }
        expect(request.method, 'HEAD');
        return http.Response(
          '',
          request.headers['authorization'] == 'Bearer valid' ? 200 : 401,
        );
      }),
    );
    expect(
      (await storage.testConnection('http://example.test', token: 'wrong')).ok,
      isFalse,
    );
    expect(
      (await storage.testConnection('http://example.test', token: 'valid')).ok,
      isTrue,
    );
  });
}
