import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../l10n/l10n.dart';

/// The "allow CLI access" switch shown in the server section of the settings.
/// It reads and writes the server's `cliEnabled` flag. The URL and token are
/// read at each request, so the server that gets the change is the one typed.
class CliAccessSwitch extends StatefulWidget {
  const CliAccessSwitch({
    super.key,
    required this.serverUrl,
    required this.token,
  });
  final String Function() serverUrl;
  final String Function() token;

  @override
  State<CliAccessSwitch> createState() => _CliAccessSwitchState();
}

class _CliAccessSwitchState extends State<CliAccessSwitch> {
  bool? _enabled;
  bool _busy = false;
  bool _failed = false;
  final _client = http.Client();

  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _request([bool? enabled]) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      var base = widget.serverUrl().trim();
      if (base.isEmpty) {
        base = Uri.base.origin;
      } else if (!base.contains('://')) {
        base = 'http://$base';
      }
      final uri = Uri.parse(
        '${base.replaceFirst(RegExp(r'/+$'), '')}/api/server-config',
      );
      final token = widget.token();
      final headers = {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final response =
          await (enabled == null
                  ? _client.get(uri, headers: headers)
                  : _client.put(
                      uri,
                      headers: headers,
                      body: jsonEncode({'cliEnabled': enabled}),
                    ))
              .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw const FormatException();
      final value = (jsonDecode(response.body) as Map)['cliEnabled'];
      if (value is! bool) throw const FormatException();
      if (mounted) setState(() => _enabled = value);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Outside the web there is no origin to ask when no server is set, so the
    // switch stays hidden for people who do not use a server.
    if (!kIsWeb && widget.serverUrl().trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_busy) const LinearProgressIndicator(),
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
