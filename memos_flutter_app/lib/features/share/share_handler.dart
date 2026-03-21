import 'dart:async';

import 'package:flutter/services.dart';

enum SharePayloadType { text, images }

class SharePayload {
  const SharePayload({
    required this.type,
    this.text,
    this.title,
    this.paths = const [],
  });

  final SharePayloadType type;
  final String? text;
  final String? title;
  final List<String> paths;

  static SharePayload? fromArgs(Object? args) {
    if (args is! Map) return null;
    final rawType = args['type'];
    final type = _parseType(rawType);
    if (type == null) return null;
    final text = args['text'] as String?;
    final title = _normalizeTitle(args['title'] as String?);
    final rawPaths = args['paths'];
    final paths = <String>[];
    if (rawPaths is List) {
      for (final item in rawPaths) {
        if (item is String && item.trim().isNotEmpty) {
          paths.add(item);
        }
      }
    }
    return SharePayload(type: type, text: text, title: title, paths: paths);
  }

  static SharePayloadType? _parseType(Object? raw) {
    if (raw is! String) return null;
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'images' || normalized == 'image') {
      return SharePayloadType.images;
    }
    if (normalized == 'text' || normalized == 'url') {
      return SharePayloadType.text;
    }
    return null;
  }

  static String? _normalizeTitle(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty || _looksLikeUrl(normalized)) {
      return null;
    }
    return normalized;
  }
}

class ShareTextDraft {
  const ShareTextDraft({required this.text, required this.selectionOffset});

  final String text;
  final int selectionOffset;
}

ShareTextDraft buildShareTextDraft(SharePayload payload) {
  final rawText = (payload.text ?? '').trim();
  final url = extractShareUrl(rawText);
  if (url == null) {
    return ShareTextDraft(text: rawText, selectionOffset: rawText.length);
  }

  final title = _extractShareTitle(
    payload: payload,
    rawText: rawText,
    url: url,
  );
  if (title == null) {
    return ShareTextDraft(text: '[]($url)', selectionOffset: 1);
  }

  final text = '[${_escapeMarkdownLinkText(title)}]($url)';
  return ShareTextDraft(text: text, selectionOffset: text.length);
}

String? extractShareUrl(String raw) {
  final match = RegExp(r'https?://[^\s]+').firstMatch(raw);
  final url = match?.group(0);
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return url;
}

String? _extractShareTitle({
  required SharePayload payload,
  required String rawText,
  required String url,
}) {
  final explicitTitle = SharePayload._normalizeTitle(payload.title);
  if (explicitTitle != null) return explicitTitle;

  final derivedText = rawText.replaceFirst(url, ' ');
  return SharePayload._normalizeTitle(derivedText);
}

String _escapeMarkdownLinkText(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]');
}

bool _looksLikeUrl(String value) {
  return RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(value);
}

class ShareHandlerService {
  static const MethodChannel _channel = MethodChannel('memoflow/share');

  static void setShareHandler(
    FutureOr<void> Function(SharePayload payload) handler,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openShare') return;
      final payload = SharePayload.fromArgs(call.arguments);
      if (payload == null) return;
      await handler(payload);
    });
  }

  static Future<SharePayload?> consumePendingShare() async {
    try {
      final args = await _channel.invokeMethod<Object>('getPendingShare');
      return SharePayload.fromArgs(args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
