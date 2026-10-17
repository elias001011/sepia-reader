import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../l10n/l10n.dart';

class ServerAccessSheet extends StatefulWidget {
  const ServerAccessSheet({
    super.key,
    required this.serverUrl,
    required this.token,
  });
  final String serverUrl;
  final String token;

  @override
  State<ServerAccessSheet> createState() => _ServerAccessSheetState();
}

class _ServerAccessSheetState extends State<ServerAccessSheet> {
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
      var base = widget.serverUrl.trim();
      if (base.isEmpty) {
        base = Uri.base.origin;
      } else if (!base.contains('://')) {
        base = 'http://$base';
      }
      final uri = Uri.parse(
        '${base.replaceFirst(RegExp(r'/+$'), '')}/api/server-config',
      );
      final headers = {
        'Content-Type': 'application/json',
        if (widget.token.isNotEmpty) 'Authorization': 'Bearer ${widget.token}',
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.cliSection),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.serverConfigHint),
          if (_busy) const LinearProgressIndicator(),
          if (_enabled != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.cliEnabled),
              value: _enabled!,
              onChanged: _busy ? null : _request,
            ),
          if (_failed)
            Text(
              context.l10n.serverConfigError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      if (_failed)
        TextButton(
          onPressed: _busy ? null : _request,
          child: const Icon(Icons.refresh),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
    ],
  );
}
