import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'share_capture_engine.dart';
import 'share_clip_models.dart';

class ShareCaptureInAppWebViewEngine implements ShareCaptureEngine {
  ShareCaptureInAppWebViewEngine({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  static const _readabilityAssetPath = 'third_party/readability/Readability.js';
  static const _bridgeAssetPath = 'assets/share/share_capture_bridge.js';
  static const _pageLoadTimeout = Duration(seconds: 12);
  static const _dynamicWaitWindow = Duration(milliseconds: 2500);
  static const _dynamicPollInterval = Duration(milliseconds: 300);

  final AssetBundle _assetBundle;

  @override
  Future<ShareCaptureResult> capture(
    ShareCaptureRequest request, {
    void Function(ShareCaptureStage stage)? onStageChanged,
  }) async {
    if (!_isSupportedUrl(request.url)) {
      return ShareCaptureResult.failure(
        finalUrl: request.url,
        failure: ShareCaptureFailure.unsupportedUrl,
        failureMessage: 'Only http and https URLs are supported.',
      );
    }

    onStageChanged?.call(ShareCaptureStage.loadingPage);
    final readabilitySource = await _assetBundle.loadString(
      _readabilityAssetPath,
    );
    final bridgeSource = await _assetBundle.loadString(_bridgeAssetPath);

    HeadlessInAppWebView? headlessWebView;
    final controllerCompleter = Completer<InAppWebViewController>();
    final pageReadyCompleter = Completer<void>();
    String? webViewError;

    try {
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri.uri(request.url)),
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
        onWebViewCreated: (controller) {
          if (!controllerCompleter.isCompleted) {
            controllerCompleter.complete(controller);
          }
        },
        onLoadStop: (controller, url) {
          if (!pageReadyCompleter.isCompleted) {
            pageReadyCompleter.complete();
          }
        },
        onReceivedError: (controller, requestInfo, error) {
          if (requestInfo.isForMainFrame ?? true) {
            webViewError = error.description;
            if (!pageReadyCompleter.isCompleted) {
              pageReadyCompleter.complete();
            }
          }
        },
      );

      await headlessWebView.run();
      final controller = await controllerCompleter.future.timeout(
        const Duration(seconds: 5),
      );

      await pageReadyCompleter.future.timeout(_pageLoadTimeout);
      if (webViewError != null) {
        return ShareCaptureResult.failure(
          finalUrl: request.url,
          failure: ShareCaptureFailure.webViewError,
          failureMessage: webViewError,
        );
      }

      onStageChanged?.call(ShareCaptureStage.waitingForDynamicContent);
      await _waitForDynamicContent(controller);

      onStageChanged?.call(ShareCaptureStage.parsingArticle);
      final rawResult = await controller.evaluateJavascript(
        source: _buildCaptureScript(
          readabilitySource: readabilitySource,
          bridgeSource: bridgeSource,
        ),
      );

      onStageChanged?.call(ShareCaptureStage.buildingPreview);
      return _parseCaptureResult(request, rawResult);
    } on TimeoutException {
      return ShareCaptureResult.failure(
        finalUrl: request.url,
        failure: ShareCaptureFailure.loadTimeout,
        failureMessage: 'Timed out while loading the shared page.',
      );
    } catch (error) {
      return ShareCaptureResult.failure(
        finalUrl: request.url,
        failure: ShareCaptureFailure.unknown,
        failureMessage: error.toString(),
      );
    } finally {
      if (headlessWebView != null) {
        await headlessWebView.dispose();
      }
    }
  }

  bool _isSupportedUrl(Uri url) {
    return url.scheme == 'http' || url.scheme == 'https';
  }

  Future<void> _waitForDynamicContent(InAppWebViewController controller) async {
    final deadline = DateTime.now().add(_dynamicWaitWindow);
    _DomMetrics? previousMetrics;
    var stableSamples = 0;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_dynamicPollInterval);
      final metrics = await _readDomMetrics(controller);
      if (metrics == null) continue;
      if (previousMetrics != null && metrics.isStableComparedTo(previousMetrics)) {
        stableSamples += 1;
        if (stableSamples >= 2) return;
      } else {
        stableSamples = 0;
      }
      previousMetrics = metrics;
    }
  }

  Future<_DomMetrics?> _readDomMetrics(InAppWebViewController controller) async {
    final raw = await controller.evaluateJavascript(
      source: '''
(() => {
  const body = document.body || document.documentElement;
  return JSON.stringify({
    textLength: body && body.innerText ? body.innerText.length : 0,
    nodeCount: document.getElementsByTagName('*').length
  });
})()
''',
    );
    if (raw is! String || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return _DomMetrics(
      textLength: (decoded['textLength'] as num?)?.toInt() ?? 0,
      nodeCount: (decoded['nodeCount'] as num?)?.toInt() ?? 0,
    );
  }

  String _buildCaptureScript({
    required String readabilitySource,
    required String bridgeSource,
  }) {
    return '''
(() => {
  const module = undefined;
  const exports = undefined;
  $readabilitySource
  $bridgeSource
  return JSON.stringify(memoflowCapture());
})()
''';
  }

  ShareCaptureResult _parseCaptureResult(
    ShareCaptureRequest request,
    dynamic rawResult,
  ) {
    final decoded = _decodeJsonMap(rawResult);
    if (decoded == null) {
      return ShareCaptureResult.failure(
        finalUrl: request.url,
        failure: ShareCaptureFailure.domUnavailable,
        failureMessage: 'Failed to read page DOM from WebView.',
      );
    }

    final finalUrl =
        Uri.tryParse(decoded['finalUrl']?.toString() ?? '') ?? request.url;
    final contentHtml = _normalizeText(decoded['contentHtml']?.toString());
    final textContent = _normalizeText(decoded['textContent']?.toString());
    final readabilitySucceeded = decoded['readabilitySucceeded'] == true;
    final length = (decoded['length'] as num?)?.toInt() ?? textContent?.length ?? 0;
    final failureMessage = _normalizeText(decoded['error']?.toString());

    if ((contentHtml == null || contentHtml.isEmpty) &&
        (textContent == null || textContent.length < 80)) {
      return ShareCaptureResult.failure(
        finalUrl: finalUrl,
        failure: ShareCaptureFailure.parserEmpty,
        failureMessage: failureMessage ?? 'Could not extract readable content from the shared page.',
        pageTitle: _normalizeText(decoded['pageTitle']?.toString()),
        articleTitle: _normalizeText(decoded['articleTitle']?.toString()),
        siteName: _normalizeText(decoded['siteName']?.toString()),
        excerpt: _normalizeText(decoded['excerpt']?.toString()),
        textContent: textContent,
      );
    }

    return ShareCaptureResult.success(
      finalUrl: finalUrl,
      pageTitle: _normalizeText(decoded['pageTitle']?.toString()),
      articleTitle: _normalizeText(decoded['articleTitle']?.toString()),
      siteName: _normalizeText(decoded['siteName']?.toString()),
      byline: _normalizeText(decoded['byline']?.toString()),
      excerpt: _normalizeText(decoded['excerpt']?.toString()),
      contentHtml: contentHtml,
      textContent: textContent,
      leadImageUrl: _normalizeText(decoded['leadImageUrl']?.toString()),
      length: length,
      readabilitySucceeded: readabilitySucceeded,
    );
  }

  Map<String, dynamic>? _decodeJsonMap(dynamic rawResult) {
    if (rawResult is Map<String, dynamic>) return rawResult;
    if (rawResult is String && rawResult.isNotEmpty) {
      final decoded = jsonDecode(rawResult);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return null;
  }

  String? _normalizeText(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class _DomMetrics {
  const _DomMetrics({required this.textLength, required this.nodeCount});

  final int textLength;
  final int nodeCount;

  bool isStableComparedTo(_DomMetrics other) {
    final textDelta = (textLength - other.textLength).abs();
    final nodeDelta = (nodeCount - other.nodeCount).abs();
    return textDelta <= 40 && nodeDelta <= 4;
  }
}
