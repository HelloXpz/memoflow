import 'package:flutter/foundation.dart';

import 'share_handler.dart';

enum ShareCaptureStatus { success, failure }

enum ShareCaptureFailure {
  unsupportedUrl,
  loadTimeout,
  webViewError,
  domUnavailable,
  parserEmpty,
  unknown,
}

enum ShareCaptureStage {
  loadingPage,
  waitingForDynamicContent,
  parsingArticle,
  buildingPreview,
}

enum ShareClipPhase { loading, success, failure, composing }

@immutable
class ShareCaptureRequest {
  const ShareCaptureRequest({
    required this.payload,
    required this.url,
    required this.sharedTitle,
    required this.sharedText,
  });

  final SharePayload payload;
  final Uri url;
  final String? sharedTitle;
  final String sharedText;
}

@immutable
class ShareCaptureResult {
  const ShareCaptureResult({
    required this.status,
    required this.finalUrl,
    this.pageTitle,
    this.articleTitle,
    this.siteName,
    this.byline,
    this.excerpt,
    this.contentHtml,
    this.textContent,
    this.leadImageUrl,
    this.length = 0,
    this.readabilitySucceeded = false,
    this.failure,
    this.failureMessage,
  });

  const ShareCaptureResult.success({
    required Uri finalUrl,
    String? pageTitle,
    String? articleTitle,
    String? siteName,
    String? byline,
    String? excerpt,
    String? contentHtml,
    String? textContent,
    String? leadImageUrl,
    int length = 0,
    bool readabilitySucceeded = false,
  }) : this(
         status: ShareCaptureStatus.success,
         finalUrl: finalUrl,
         pageTitle: pageTitle,
         articleTitle: articleTitle,
         siteName: siteName,
         byline: byline,
         excerpt: excerpt,
         contentHtml: contentHtml,
         textContent: textContent,
         leadImageUrl: leadImageUrl,
         length: length,
         readabilitySucceeded: readabilitySucceeded,
       );

  const ShareCaptureResult.failure({
    required Uri finalUrl,
    required ShareCaptureFailure failure,
    String? failureMessage,
    String? pageTitle,
    String? articleTitle,
    String? siteName,
    String? excerpt,
    String? textContent,
  }) : this(
         status: ShareCaptureStatus.failure,
         finalUrl: finalUrl,
         failure: failure,
         failureMessage: failureMessage,
         pageTitle: pageTitle,
         articleTitle: articleTitle,
         siteName: siteName,
         excerpt: excerpt,
         textContent: textContent,
       );

  final ShareCaptureStatus status;
  final Uri finalUrl;
  final String? pageTitle;
  final String? articleTitle;
  final String? siteName;
  final String? byline;
  final String? excerpt;
  final String? contentHtml;
  final String? textContent;
  final String? leadImageUrl;
  final int length;
  final bool readabilitySucceeded;
  final ShareCaptureFailure? failure;
  final String? failureMessage;

  bool get isSuccess => status == ShareCaptureStatus.success;

  bool get hasHtmlContent => (contentHtml ?? '').trim().isNotEmpty;

  bool get hasTextContent => (textContent ?? '').trim().isNotEmpty;
}

@immutable
class ShareComposeRequest {
  const ShareComposeRequest({
    required this.text,
    required this.selectionOffset,
    this.attachmentPaths = const [],
  });

  final String text;
  final int selectionOffset;
  final List<String> attachmentPaths;
}

@immutable
class ShareClipViewState {
  const ShareClipViewState({
    required this.phase,
    required this.stage,
    required this.linkOnlyRequest,
    this.result,
    this.previewText,
  });

  const ShareClipViewState.loading({
    required ShareComposeRequest linkOnlyRequest,
    ShareCaptureStage stage = ShareCaptureStage.loadingPage,
  }) : this(
         phase: ShareClipPhase.loading,
         stage: stage,
         linkOnlyRequest: linkOnlyRequest,
       );

  final ShareClipPhase phase;
  final ShareCaptureStage stage;
  final ShareComposeRequest linkOnlyRequest;
  final ShareCaptureResult? result;
  final String? previewText;

  ShareClipViewState copyWith({
    ShareClipPhase? phase,
    ShareCaptureStage? stage,
    ShareComposeRequest? linkOnlyRequest,
    ShareCaptureResult? result,
    String? previewText,
    bool clearResult = false,
    bool clearPreviewText = false,
  }) {
    return ShareClipViewState(
      phase: phase ?? this.phase,
      stage: stage ?? this.stage,
      linkOnlyRequest: linkOnlyRequest ?? this.linkOnlyRequest,
      result: clearResult ? null : (result ?? this.result),
      previewText: clearPreviewText ? null : (previewText ?? this.previewText),
    );
  }
}

ShareCaptureRequest? buildShareCaptureRequest(SharePayload payload) {
  final sharedText = (payload.text ?? '').trim();
  final rawUrl = extractShareUrl(sharedText);
  if (rawUrl == null) return null;
  final url = Uri.tryParse(rawUrl);
  if (url == null) return null;
  return ShareCaptureRequest(
    payload: payload,
    url: url,
    sharedTitle: payload.title,
    sharedText: sharedText,
  );
}
