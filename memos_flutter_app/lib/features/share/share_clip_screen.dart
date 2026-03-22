import 'dart:async';

import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';
import '../memos/memo_markdown.dart';
import 'share_capture_engine.dart';
import 'share_capture_inappwebview_engine.dart';
import 'share_clip_controller.dart';
import 'share_clip_models.dart';
import 'share_handler.dart';

class ShareClipScreen extends StatefulWidget {
  const ShareClipScreen({
    super.key,
    required this.payload,
    this.engine,
  });

  final SharePayload payload;
  final ShareCaptureEngine? engine;

  @override
  State<ShareClipScreen> createState() => _ShareClipScreenState();
}

class _ShareClipScreenState extends State<ShareClipScreen> {
  late final ShareClipController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ShareClipController(
      payload: widget.payload,
      engine: widget.engine ?? ShareCaptureInAppWebViewEngine(),
    );
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final state = _controller.state;
        final result = state.result;
        final domain = result?.finalUrl.host ??
            buildShareCaptureRequest(widget.payload)?.url.host ??
            '';
        final title = _resolveTitle(result);
        return Scaffold(
          appBar: AppBar(
            title: Text(context.t.strings.legacy.msg_preview),
            actions: [
              TextButton(
                onPressed: state.phase == ShareClipPhase.composing
                    ? null
                    : () => Navigator.of(context).pop(),
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _HeaderCard(
                    title: title,
                    domain: domain,
                    subtitle: _buildSubtitle(state),
                  ),
                ),
                Expanded(
                  child: switch (state.phase) {
                    ShareClipPhase.loading || ShareClipPhase.composing =>
                      _LoadingBody(stage: state.stage),
                    ShareClipPhase.success => _SuccessBody(
                      previewText: state.previewText ?? state.linkOnlyRequest.text,
                    ),
                    ShareClipPhase.failure => _FailureBody(
                      message: _buildFailureMessage(result),
                      excerpt: result?.excerpt,
                    ),
                  },
                ),
                _ActionBar(
                  phase: state.phase,
                  onSaveMemo: state.phase == ShareClipPhase.success
                      ? () {
                          final request = _controller.saveArticle();
                          if (request == null || !mounted) return;
                          Navigator.of(context).pop(request);
                        }
                      : null,
                  onUseLinkOnly: state.phase == ShareClipPhase.composing
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(_controller.useLinkOnly()),
                  onRetry: state.phase == ShareClipPhase.loading ||
                          state.phase == ShareClipPhase.composing
                      ? null
                      : _controller.retry,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _resolveTitle(ShareCaptureResult? result) {
    return result?.articleTitle ??
        result?.pageTitle ??
        widget.payload.title ??
        buildShareCaptureRequest(widget.payload)?.url.host ??
        '';
  }

  String _buildSubtitle(ShareClipViewState state) {
    return switch (state.phase) {
      ShareClipPhase.loading => _stageLabel(state.stage),
      ShareClipPhase.composing => context.t.strings.legacy.msg_save,
      ShareClipPhase.success => context.t.strings.legacy.msg_preview,
      ShareClipPhase.failure => _buildFailureMessage(state.result),
    };
  }

  String _buildFailureMessage(ShareCaptureResult? result) {
    return switch (result?.failure) {
      ShareCaptureFailure.unsupportedUrl => 'Unsupported URL scheme.',
      ShareCaptureFailure.loadTimeout => 'Timed out while loading the page.',
      ShareCaptureFailure.webViewError => 'WebView failed to load the page.',
      ShareCaptureFailure.domUnavailable => 'Unable to read page content.',
      ShareCaptureFailure.parserEmpty => 'Could not extract readable article content.',
      ShareCaptureFailure.unknown || null =>
        result?.failureMessage ?? 'Unable to clip this page right now.',
    };
  }

  String _stageLabel(ShareCaptureStage stage) {
    return switch (stage) {
      ShareCaptureStage.loadingPage => 'Loading page',
      ShareCaptureStage.waitingForDynamicContent => 'Waiting for dynamic content',
      ShareCaptureStage.parsingArticle => 'Parsing article',
      ShareCaptureStage.buildingPreview => 'Building preview',
    };
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.domain,
    required this.subtitle,
  });

  final String title;
  final String domain;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.isEmpty ? domain : title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            if (domain.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                domain,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.stage});

  final ShareCaptureStage stage;

  @override
  Widget build(BuildContext context) {
    final label = switch (stage) {
      ShareCaptureStage.loadingPage => 'Loading page',
      ShareCaptureStage.waitingForDynamicContent => 'Waiting for dynamic content',
      ShareCaptureStage.parsingArticle => 'Parsing article',
      ShareCaptureStage.buildingPreview => 'Building preview',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.t.strings.legacy.msg_loading),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.previewText});

  final String previewText;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: MemoMarkdown(data: previewText),
    );
  }
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.message, this.excerpt});

  final String message;
  final String? excerpt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 40),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (excerpt != null && excerpt!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                excerpt!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.phase,
    required this.onSaveMemo,
    required this.onUseLinkOnly,
    required this.onRetry,
  });

  final ShareClipPhase phase;
  final VoidCallback? onSaveMemo;
  final VoidCallback? onUseLinkOnly;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            if (phase == ShareClipPhase.success)
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSaveMemo,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(context.t.strings.legacy.msg_save_memo),
                ),
              ),
            if (phase == ShareClipPhase.success) const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: onUseLinkOnly,
                child: Text(_linkOnlyLabel(context)),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.t.strings.legacy.msg_retry),
            ),
          ],
        ),
      ),
    );
  }

  String _linkOnlyLabel(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode.toLowerCase() == 'zh') {
      final script = locale.scriptCode?.toLowerCase();
      final region = locale.countryCode?.toUpperCase();
      final traditional =
          script == 'hant' || region == 'TW' || region == 'HK' || region == 'MO';
      return traditional
          ? '\u50c5\u4fdd\u5b58\u9023\u7d50'
          : '\u4ec5\u4fdd\u5b58\u94fe\u63a5';
    }
    return 'Save Link Only';
  }
}
