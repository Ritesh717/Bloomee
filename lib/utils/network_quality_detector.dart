import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

enum ConnectionQuality {
  unknown,
  poor, // < 150 kbps (2G/Slow 3G)
  moderate, // 150-500 kbps (3G)
  good, // 500kbps - 2Mbps
  excellent // > 2Mbps (4G/5G/WiFi)
}

class NetworkQualityDetector {
  static final NetworkQualityDetector _instance =
      NetworkQualityDetector._internal();
  factory NetworkQualityDetector() => _instance;
  NetworkQualityDetector._internal();

  ConnectionQuality _lastKnownQuality = ConnectionQuality.unknown;
  DateTime? _lastCheckTime;
  // Cache check result for 5 minutes unless forced
  static const Duration _cacheDuration = Duration(minutes: 5);

  ConnectionQuality get currentQuality => _lastKnownQuality;

  /// Estimates the connection speed by downloading a small file
  /// Returns approximate speed in kbps
  Future<double> estimateSpeedInKbps() async {
    // Avoid frequent checks
    if (_lastKnownQuality != ConnectionQuality.unknown &&
        _lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < _cacheDuration) {
      return _qualityToKbps(_lastKnownQuality);
    }

    try {
      final stopwatch = Stopwatch()..start();
      // Download a small, reliable file (e.g. 100KB test image or similar)
      // Using Google's favicon or a lightweight asset is a common trick
      // Here we check a small endpoint, measuring response time + body download
      final url = Uri.parse('https://www.google.com/favicon.ico');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final fileSizeInBits = (response.bodyBytes.length) * 8;
        final durationInSeconds = stopwatch.elapsedMilliseconds / 1000;

        if (durationInSeconds == 0) return 99999; // Instant (cached or local)

        final speedKbps = (fileSizeInBits / durationInSeconds) / 1000;
        _updateQuality(speedKbps);
        return speedKbps;
      }
    } catch (_) {
      // On error/timeout, assume poor connection or keep last known
    }

    // Fallback if check fails but we have connectivity
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        // We have internet but speed test failed/timed out -> assume moderate/good backup
        if (_lastKnownQuality == ConnectionQuality.unknown) {
          _lastKnownQuality = ConnectionQuality.moderate;
        }
        return _qualityToKbps(_lastKnownQuality);
      }
    } catch (_) {}

    _lastKnownQuality = ConnectionQuality.unknown;
    return 0;
  }

  void _updateQuality(double kbps) {
    _lastCheckTime = DateTime.now();
    if (kbps < 150) {
      _lastKnownQuality = ConnectionQuality.poor;
    } else if (kbps < 500) {
      _lastKnownQuality = ConnectionQuality.moderate;
    } else if (kbps < 2000) {
      _lastKnownQuality = ConnectionQuality.good;
    } else {
      _lastKnownQuality = ConnectionQuality.excellent;
    }
    debugPrint(
        'Network Speed Estimate: ${kbps.toStringAsFixed(0)} kbps (${_lastKnownQuality.name})');
  }

  double _qualityToKbps(ConnectionQuality q) {
    switch (q) {
      case ConnectionQuality.poor:
        return 100;
      case ConnectionQuality.moderate:
        return 300;
      case ConnectionQuality.good:
        return 1000;
      case ConnectionQuality.excellent:
        return 5000;
      case ConnectionQuality.unknown:
        return 0;
    }
  }

  bool get shouldPreferOffline =>
      _lastKnownQuality == ConnectionQuality.poor ||
      _lastKnownQuality == ConnectionQuality.unknown;

  bool get shouldUseLowQualityStreaming =>
      _lastKnownQuality == ConnectionQuality.moderate;
}
