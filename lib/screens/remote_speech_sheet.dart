import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../services/tts/remote_speech_client.dart';
import '../services/tts/remote_speech_config.dart';
import '../services/tts/remote_tts_engine.dart';
import '../services/tts/tts_engine.dart';
import '../widgets/sheet_scaffold.dart';

class RemoteSpeechSheet extends StatefulWidget {
  const RemoteSpeechSheet({
    super.key,
    required this.store,
    required this.syncUrl,
    required this.syncToken,
  });
  final RemoteSpeechStore store;
  final String syncUrl, syncToken;
  @override
  State<RemoteSpeechSheet> createState() => _RemoteSpeechSheetState();
}

class _RemoteSpeechSheetState extends State<RemoteSpeechSheet> {
  final _key = TextEditingController(),
      _region = TextEditingController(),
      _voice = TextEditingController();
  final _model = TextEditingController(),
      _language = TextEditingController(),
      _url = TextEditingController();
  String _provider = 'azure';
  bool _ready = false,
      _busy = false,
      _consent = false,
      _prefetch = false,
      _showKey = false;
  List<TtsVoice> _voices = [];
  String? _error;
  RemoteTtsEngine? _preview;
  RemoteSpeechClient? _client;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final config = await widget.store.load();
      if (!mounted) return;
      _provider = config.provider;
      _key.text = config.apiKey;
      _region.text = config.region;
      _voice.text = config.voice;
      _model.text = config.model;
      _language.text = config.language;
      _url.text = config.serverUrl;
      setState(() {
        _ready = true;
        _consent = config.consent;
        _prefetch = config.prefetch;
      });
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.remoteStorageError);
    }
  }

  RemoteSpeechConfig get _config => RemoteSpeechConfig(
    provider: _provider,
    apiKey: _key.text.trim(),
    region: _region.text.trim(),
    voice: _voice.text.trim(),
    model: _model.text.trim(),
    language: _language.text.trim(),
    serverUrl: _url.text.trim(),
    consent: _consent,
    prefetch: _prefetch,
  );

  String _message(Object error) {
    if (error is! RemoteSpeechException) {
      return context.l10n.remoteConnectionError;
    }
    return switch (error.code) {
      'authentication' ||
      'missing-api-key' => context.l10n.remoteAuthenticationError,
      'quota-or-busy' => context.l10n.remoteQuotaError,
      'configure-remote-speech' => context.l10n.remoteConsent,
      'server-tts-disabled' ||
      'unavailable' => context.l10n.remoteServerUnavailable,
      'missing-voice' => context.l10n.remoteVoiceRequired,
      _ => context.l10n.remoteConnectionError,
    };
  }

  Future<void> _listVoices() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = _client = RemoteSpeechClient(
      _config,
      syncUrl: widget.syncUrl,
      syncToken: widget.syncToken,
    );
    try {
      final voices = await client.voices();
      if (!mounted) return;
      setState(() {
        _voices = voices;
        if (voices.isNotEmpty && !voices.any((v) => v.id == _voice.text)) {
          _voice.text = voices.first.id;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enableServer() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = _client = RemoteSpeechClient(
      _config,
      syncUrl: widget.syncUrl,
      syncToken: widget.syncToken,
    );
    try {
      await client.enableServer();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _listen() async {
    final sample = context.l10n.ttsPreviewText;
    final engine = _preview = RemoteTtsEngine(
      loadConfig: () async => _config,
      syncUrl: widget.syncUrl,
      syncToken: widget.syncToken,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await engine.prepare();
      await engine.speak(sample);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      await engine.release();
      if (identical(_preview, engine)) _preview = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final client = RemoteSpeechClient(
      _config,
      syncUrl: widget.syncUrl,
      syncToken: widget.syncToken,
    );
    try {
      client.validate();
      setState(() {
        _busy = true;
        _error = null;
      });
      await widget.store.save(_config);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is RemoteSpeechException
              ? _message(error)
              : context.l10n.remoteStorageError,
        );
      }
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forget() async {
    try {
      await widget.store.clear();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.remoteStorageError);
    }
  }

  @override
  void dispose() {
    _client?.close();
    unawaited(_preview?.release());
    for (final controller in [_key, _region, _voice, _model, _language, _url]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      enabled: !_busy,
      autocorrect: false,
      enableSuggestions: false,
      obscureText: secret && !_showKey,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperMaxLines: 4,
        suffixIcon: secret
            ? IconButton(
                tooltip: _showKey
                    ? context.l10n.remoteHideKey
                    : context.l10n.remoteShowKey,
                onPressed: () => setState(() => _showKey = !_showKey),
                icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
              )
            : null,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: context.l10n.remoteTitle,
    description: context.l10n.remotePrivacy,
    footer: FilledButton(
      onPressed: _ready && !_busy ? _save : null,
      child: Text(context.l10n.apply),
    ),
    children: [
      if (!_ready && _error == null)
        const Center(child: CircularProgressIndicator()),
      if (_ready) ...[
        DropdownButtonFormField<String>(
          initialValue: _provider,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.l10n.remoteProvider),
          items: [
            const DropdownMenuItem(value: 'azure', child: Text('Azure Speech')),
            const DropdownMenuItem(
              value: 'elevenlabs',
              child: Text('ElevenLabs'),
            ),
            DropdownMenuItem(
              value: 'sepia',
              child: Text(context.l10n.remoteSepiaServer),
            ),
          ],
          onChanged: _busy
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _provider = value;
                    _consent = false;
                    _key.clear();
                    _voices = [];
                    _voice.text = value == 'azure'
                        ? 'pt-BR-AntonioNeural'
                        : value == 'sepia'
                        ? 'M2'
                        : '';
                  });
                },
        ),
        const SizedBox(height: 12),
        if (_provider == 'azure') _field(_region, context.l10n.remoteRegion),
        if (_provider == 'sepia')
          _field(
            _url,
            context.l10n.remoteServerUrl,
            hint: context.l10n.remoteServerUrlHint,
          ),
        _field(
          _key,
          _provider == 'sepia'
              ? context.l10n.remoteServerToken
              : context.l10n.remoteApiKey,
          hint: _provider == 'sepia'
              ? context.l10n.remoteServerTokenHint
              : null,
          secret: true,
        ),
        _field(_voice, context.l10n.remoteVoiceId),
        if (_provider == 'elevenlabs') _field(_model, context.l10n.remoteModel),
        _field(_language, context.l10n.language),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          onChanged: _busy
              ? null
              : (value) => setState(() => _consent = value ?? false),
          title: Text(context.l10n.remoteConsent),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _prefetch,
          onChanged: _busy
              ? null
              : (value) => setState(() => _prefetch = value),
          title: Text(context.l10n.remotePrefetch),
          subtitle: Text(context.l10n.remotePrefetchHint),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: !_busy && _consent ? _listVoices : null,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.remoteLoadVoices),
            ),
            OutlinedButton.icon(
              onPressed: !_busy && _consent ? _listen : null,
              icon: const Icon(Icons.volume_up),
              label: Text(context.l10n.ttsPreview),
            ),
            if (_busy && _preview != null)
              TextButton(
                onPressed: () => _preview?.stop(),
                child: Text(context.l10n.ttsStop),
              ),
          ],
        ),
        if (_provider == 'sepia')
          TextButton(
            onPressed: !_busy && _consent ? _enableServer : null,
            child: Text(context.l10n.remoteEnableServer),
          ),
        if (_voices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<String>(
              key: ValueKey(_voices.map((v) => v.id).join(',')),
              isExpanded: true,
              initialValue: _voices.any((v) => v.id == _voice.text)
                  ? _voice.text
                  : null,
              decoration: InputDecoration(labelText: context.l10n.ttsVoice),
              items: [
                for (final voice in _voices)
                  DropdownMenuItem(
                    value: voice.id,
                    child: Text(
                      '${voice.name} · ${voice.locale}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) setState(() => _voice.text = value);
                    },
            ),
          ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 12),
        Text(
          kIsWeb
              ? context.l10n.remoteSessionOnly
              : context.l10n.remoteSecureStorage,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse(switch (_provider) {
              'azure' => 'https://azure.microsoft.com/pricing/details/speech/',
              'elevenlabs' => 'https://elevenlabs.io/pricing/api',
              _ => 'https://github.com/elias001011/sepia-reader/blob/main/docs/TTS-REMOTO.md',
            }),
          ),
          child: Text(
            _provider == 'sepia'
                ? context.l10n.remoteSetupGuide
                : context.l10n.remotePricing,
          ),
        ),
        TextButton(
          onPressed: !_busy ? _forget : null,
          child: Text(context.l10n.remoteForget),
        ),
      ],
      if (!_ready && _error != null)
        TextButton(onPressed: _forget, child: Text(context.l10n.remoteForget)),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );
}
