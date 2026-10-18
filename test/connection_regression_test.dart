import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/services/storage_service.dart';
import 'package:sepia_reader/services/server_connection.dart';

class ChangeDuringRequest extends StorageService {
  ChangeDuringRequest(http.Client client) : super(client: client);
  int reads = 0;
  @override
  Future<SyncConfig> loadSyncConfig() async {
    final captured = await super.loadSyncConfig();
    if (++reads == 1) {
      await saveSyncConfig(
        const SyncConfig(
          enabled: true,
          serverUrl: 'http://server-b.test',
          token: 'dummy-token-b',
        ),
      );
    }
    return captured;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('URL and bearer always come from the same configuration', () async {
    SharedPreferences.setMockInitialValues({});
    http.Request? captured;
    final storage = ChangeDuringRequest(
      MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      }),
    );
    await storage.saveSyncConfig(
      const SyncConfig(
        enabled: true,
        serverUrl: 'http://server-a.test',
        token: 'dummy-token-a',
      ),
    );
    await storage.saveSettings(const AppSettings());
    await storage.waitForPendingSync();
    expect(captured!.url.host, 'server-a.test');
    expect(captured!.headers['authorization'], 'Bearer dummy-token-a');
  });
  test('API requests never follow redirects', () async {
    final client = MockClient((request) async {
      expect(request.followRedirects, isFalse);
      return http.Response('', 302, headers: {'location': 'http://other.test'});
    });
    expect(
      (await serverRequest(
        client,
        'GET',
        Uri.parse('http://server.test/api/documents'),
      )).statusCode,
      302,
    );
  });
  test('server address rejects embedded credentials and non-HTTP schemes', () {
    expect(serverUri('https://user:secret@server.test', '/healthz'), isNull);
    expect(serverUri('file:///tmp/data', '/healthz'), isNull);
    expect(
      serverUri('sepia.example:8888/', '/healthz')!.toString(),
      'http://sepia.example:8888/healthz',
    );
  });
}
