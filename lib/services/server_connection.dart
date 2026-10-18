import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Shared URL rules for synchronization and server controls.
Uri? serverUri(String base, String path, {bool enabled = true}) {
  if (!enabled) return null;
  base = base.trim();
  if (base.isEmpty) return kIsWeb ? Uri.base.resolve(path) : null;
  if (!base.contains('://')) base = 'http://$base';
  final uri = Uri.tryParse('${base.replaceFirst(RegExp(r'/+$'), '')}$path');
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

/// A bearer token belongs to one origin. API redirects are errors, including
/// on the web, rather than forwarding credentials to a second destination.
Future<http.Response> serverRequest(
  http.Client client,
  String method,
  Uri uri, {
  Map<String, String> headers = const {},
  String? body,
}) async {
  final request = http.Request(method, uri)
    ..followRedirects = false
    ..headers.addAll(headers);
  if (body != null) request.body = body;
  return http.Response.fromStream(await client.send(request));
}
