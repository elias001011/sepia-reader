import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sepia_reader/services/update_checker.dart';

/// An update checker that never reaches the network.
///
/// Widget tests build the library screen, which checks for updates when it
/// opens. Left alone that is a real HTTP request per test — slow, flaky, and
/// rude to GitHub.
UpdateChecker offlineUpdateChecker() => UpdateChecker(
  client: MockClient((request) async => http.Response('{}', 404)),
);
