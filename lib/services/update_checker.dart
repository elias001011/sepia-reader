import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A release newer than the one running.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.pageUrl,
    required this.notes,
    this.apkUrl,
  });

  /// Version without the leading `v`.
  final String version;

  /// The release page, always available.
  final String pageUrl;

  /// Release notes, as published.
  final String notes;

  /// Direct link to the APK for this device's architecture, when there is
  /// one. Absent on the web, and on a release that published none.
  final String? apkUrl;
}

/// Compares dotted versions numerically: 1.10.0 is newer than 1.9.0, which
/// string comparison gets backwards.
int compareVersions(String a, String b) {
  List<int> parts(String value) => value
      .split(RegExp(r'[.+\-]'))
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final left = parts(a);
  final right = parts(b);
  for (var i = 0; i < left.length || i < right.length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

/// Asks GitHub whether there is a newer release.
///
/// Only ever *asks*. Nothing is downloaded and nothing is installed without
/// the user choosing to, which is the only honest way for a self-installed
/// APK to handle updates: the app cannot silently replace itself, and
/// pretending otherwise would be worse than saying so.
class UpdateChecker {
  UpdateChecker({http.Client? client, this.repository = 'elias001011/sepia-reader'})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String repository;

  static const _lastCheckKey = 'sepia.update.lastcheck.v1';
  static const _minimumInterval = Duration(hours: 6);

  /// Version of the running build.
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Whether enough time has passed to ask again.
  ///
  /// A launch-time check that fired on every launch would be a request per
  /// app open for an answer that changes a few times a month.
  Future<bool> isDueForCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastCheckKey);
    if (raw == null) return true;
    final last = DateTime.tryParse(raw);
    if (last == null) return true;
    return DateTime.now().difference(last) >= _minimumInterval;
  }

  Future<void> _markChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
  }

  /// Returns the newer release, or null when this build is current.
  ///
  /// Throws on a network or parsing failure so a manual check can say what
  /// went wrong; the launch-time check swallows it instead, because a
  /// missing connection is not something to interrupt someone's reading for.
  Future<AppUpdate?> check({bool force = false}) async {
    if (!force && !await isDueForCheck()) return null;
    final uri = Uri.parse(
      'https://api.github.com/repos/$repository/releases/latest',
    );
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpExceptionLike('HTTP ${response.statusCode}');
    }
    await _markChecked();
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const HttpExceptionLike('unexpected response');
    final tag = decoded['tag_name'] as String?;
    if (tag == null) return null;
    final latest = tag.startsWith('v') ? tag.substring(1) : tag;
    if (compareVersions(latest, await currentVersion()) <= 0) return null;

    return AppUpdate(
      version: latest,
      pageUrl:
          decoded['html_url'] as String? ??
          'https://github.com/$repository/releases/latest',
      notes: (decoded['body'] as String? ?? '').trim(),
      apkUrl: _preferredApk(decoded['assets']),
    );
  }

  /// Picks the APK this device can actually install.
  ///
  /// Releases ship one per architecture plus a universal build; handing an
  /// arm64 phone the 134 MB universal APK when a 48 MB one exists would be
  /// a poor trade. The web build gets nothing — there is no APK to install
  /// into a browser.
  String? _preferredApk(Object? assets) {
    if (kIsWeb || assets is! List) return null;
    final names = <String, String>{};
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name'] as String?;
      final url = asset['browser_download_url'] as String?;
      if (name != null && url != null && name.endsWith('.apk')) {
        names[name] = url;
      }
    }
    if (names.isEmpty) return null;
    final wanted = _abiPreference();
    for (final abi in wanted) {
      for (final entry in names.entries) {
        if (entry.key.contains(abi)) return entry.value;
      }
    }
    return names.values.first;
  }

  List<String> _abiPreference() {
    if (defaultTargetPlatform != TargetPlatform.android) return const [];
    // Ordered best-first; the universal build is the last resort.
    return const ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'universal'];
  }
}

/// Small stand-in so this file does not need `dart:io`, which the web build
/// cannot compile.
class HttpExceptionLike implements Exception {
  const HttpExceptionLike(this.message);
  final String message;
  @override
  String toString() => message;
}
