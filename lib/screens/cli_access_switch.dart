import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../l10n/l10n.dart';
import '../services/server_connection.dart';

/// The "allow CLI access" switch shown in the server section of the settings.
/// It reads and writes the server's `cliEnabled` flag. The URL and token are
/// read at each request, so the server that gets the change is the one typed.
class CliAccessSwitch extends StatefulWidget {
  const CliAccessSwitch({
    super.key,
    required this.serverUrl,
    required this.token,
  });
  final String serverUrl;
  final String token;

  @override
  State<CliAccessSwitch> createState() => _CliAccessSwitchState();
}

class _CliAccessSwitchState extends State<CliAccessSwitch> {
  bool? _enabled;
  bool _busy = false;
  bool _failed = false;
  final _client = http.Client();
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || widget.serverUrl.trim().isNotEmpty) _request();
  }

  @override
  void didUpdateWidget(covariant CliAccessSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverUrl != widget.serverUrl ||
        oldWidget.token != widget.token) {
      _generation++;
      _enabled = null;
      _failed = false;
      _busy = false;
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _request([bool? enabled]) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final uri = serverUri(widget.serverUrl, '/api/server-config');
      if (uri == null) throw const FormatException();
      final token = widget.token;
      final headers = {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final response =
          await (enabled == null
                  ? serverRequest(_client, 'GET', uri, headers: headers)
                  : serverRequest(
                      _client,
                      'PUT',
                      uri,
                      headers: headers,
                      body: jsonEncode({'cliEnabled': enabled}),
                    ))
              .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw const FormatException();
      final value = (jsonDecode(response.body) as Map)['cliEnabled'];
      if (value is! bool) throw const FormatException();
      if (mounted && generation == _generation) {
        setState(() => _enabled = value);
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Outside the web there is no origin to ask when no server is set, so the
    // switch stays hidden for people who do not use a server.
    if (!kIsWeb && widget.serverUrl.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_enabled == null && !_failed && !_busy)
          OutlinedButton.icon(
            onPressed: _request,
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.serverAccessRefresh),
          ),
        if (_enabled != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.cliEnabled),
            value: _enabled!,
            onChanged: _busy ? null : _request,
          ),
        if (_failed)
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.serverConfigError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _request,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
      ],
    );
  }
}
