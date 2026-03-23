import 'package:flutter/material.dart';

class SmartEnterResult {
  const SmartEnterResult({required this.text, required this.selection});

  final String text;
  final TextSelection selection;
}

class SmartEnterController {
  SmartEnterController(this.controller) {
    _lastText = controller.text;
    controller.addListener(_handleChange);
  }

  final TextEditingController controller;
  late String _lastText;
  bool _applying = false;

  static final RegExp _taskPrefixRegex = RegExp(
    r'^(\s*(?:- \[(?: |x|X)\] |- |\d+\. ))',
  );

  void dispose() {
    controller.removeListener(_handleChange);
  }

  void _handleChange() {
    if (_applying) return;

    final newText = controller.text;
    final result = handleSmartEnter(_lastText, newText);
    if (result != null) {
      _applying = true;
      controller.value = controller.value.copyWith(
        text: result.text,
        selection: result.selection,
        composing: TextRange.empty,
      );
      _applying = false;
    }
    _lastText = controller.text;
  }

  SmartEnterResult? handleSmartEnter(String oldText, String newText) {
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;

    final cursor = selection.baseOffset;
    if (cursor <= 0 || cursor > newText.length) return null;

    if (newText.length != oldText.length + 1) return null;
    if (newText[cursor - 1] != '\n') return null;

    final prevLineStart = newText.lastIndexOf('\n', cursor - 2) + 1;
    final prevLine = newText.substring(prevLineStart, cursor - 1);

    final match = _taskPrefixRegex.firstMatch(prevLine);
    if (match == null) return null;

    final prefix = match.group(1)!;
    final rest = prevLine.substring(prefix.length);
    final isPrefixOnly = rest.trim().isEmpty;

    if (isPrefixOnly) {
      final updated = newText.replaceRange(
        prevLineStart,
        prevLineStart + prefix.length,
        '',
      );
      final newCursor = (cursor - prefix.length).clamp(0, updated.length);
      return SmartEnterResult(
        text: updated,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    final updated = newText.replaceRange(cursor, cursor, prefix);
    final newCursor = cursor + prefix.length;
    return SmartEnterResult(
      text: updated,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}

enum MarkdownBlockStyle {
  unorderedList,
  orderedList,
  taskList,
  heading1,
  heading2,
  heading3,
  quote,
}

@immutable
class MarkdownParagraphRange {
  const MarkdownParagraphRange({required this.start, required this.end});

  final int start;
  final int end;

  int get length => end - start;

  bool containsOffset(int offset) => offset >= start && offset <= end;
}

@immutable
class MarkdownCutResult {
  const MarkdownCutResult({required this.value, required this.copiedText});

  final TextEditingValue value;
  final String copiedText;
}

TextSelection normalizeMarkdownSelection(
  TextSelection selection,
  int textLength,
) {
  if (!selection.isValid) {
    return TextSelection.collapsed(offset: textLength);
  }
  int clampOffset(int offset) => offset.clamp(0, textLength).toInt();
  return selection.copyWith(
    baseOffset: clampOffset(selection.baseOffset),
    extentOffset: clampOffset(selection.extentOffset),
  );
}

TextEditingValue insertInlineSnippet(
  TextEditingValue value,
  String text, {
  int? caretOffset,
}) {
  final selection = normalizeMarkdownSelection(
    value.selection,
    value.text.length,
  );
  final start = selection.start;
  final end = selection.end;
  final nextText = value.text.replaceRange(start, end, text);
  final nextCaret = start + (caretOffset ?? text.length);
  return value.copyWith(
    text: nextText,
    selection: TextSelection.collapsed(offset: nextCaret),
    composing: TextRange.empty,
  );
}

TextEditingValue wrapMarkdownSelection(
  TextEditingValue value, {
  required String prefix,
  required String suffix,
}) {
  final selection = normalizeMarkdownSelection(
    value.selection,
    value.text.length,
  );

  final unwrapMatch = _findInlineWrapMatch(
    value.text,
    selection,
    prefix: prefix,
    suffix: suffix,
  );
  if (unwrapMatch != null) {
    return _unwrapInlineWrap(
      value.copyWith(selection: selection),
      selection,
      unwrapMatch,
    );
  }

  if (selection.isCollapsed) {
    return insertInlineSnippet(
      value,
      '$prefix$suffix',
      caretOffset: prefix.length,
    );
  }

  final selected = value.text.substring(selection.start, selection.end);
  final wrapped = '$prefix$selected$suffix';
  return value.copyWith(
    text: value.text.replaceRange(selection.start, selection.end, wrapped),
    selection: TextSelection(
      baseOffset: selection.start,
      extentOffset: selection.start + wrapped.length,
    ),
    composing: TextRange.empty,
  );
}

_InlineWrapMatch? _findInlineWrapMatch(
  String text,
  TextSelection selection, {
  required String prefix,
  required String suffix,
}) {
  if (selection.isCollapsed) {
    return _findCollapsedInlineWrapMatch(
      text,
      selection.baseOffset,
      prefix: prefix,
      suffix: suffix,
    );
  }

  final wrappedSelection = _matchWrappedSelectedText(
    text,
    selection,
    prefix: prefix,
    suffix: suffix,
  );
  if (wrappedSelection != null) return wrappedSelection;

  return _matchSelectionInsideWrappedText(
    text,
    selection,
    prefix: prefix,
    suffix: suffix,
  );
}

_InlineWrapMatch? _matchWrappedSelectedText(
  String text,
  TextSelection selection, {
  required String prefix,
  required String suffix,
}) {
  if (selection.end - selection.start < prefix.length + suffix.length) {
    return null;
  }
  if (!text.startsWith(prefix, selection.start)) return null;
  final suffixStart = selection.end - suffix.length;
  if (!text.startsWith(suffix, suffixStart)) return null;
  if (!_isValidInlineDelimiterOccurrence(text, selection.start, prefix)) {
    return null;
  }
  if (!_isValidInlineDelimiterOccurrence(text, suffixStart, suffix)) {
    return null;
  }
  return _InlineWrapMatch(
    prefixStart: selection.start,
    contentStart: selection.start + prefix.length,
    contentEnd: suffixStart,
    suffixStart: suffixStart,
    prefixLength: prefix.length,
    suffixLength: suffix.length,
  );
}

_InlineWrapMatch? _matchSelectionInsideWrappedText(
  String text,
  TextSelection selection, {
  required String prefix,
  required String suffix,
}) {
  final prefixStart = selection.start - prefix.length;
  if (prefixStart < 0) return null;
  final suffixStart = selection.end;
  if (suffixStart + suffix.length > text.length) return null;
  if (!text.startsWith(prefix, prefixStart)) return null;
  if (!text.startsWith(suffix, suffixStart)) return null;
  if (!_isValidInlineDelimiterOccurrence(text, prefixStart, prefix)) {
    return null;
  }
  if (!_isValidInlineDelimiterOccurrence(text, suffixStart, suffix)) {
    return null;
  }
  return _InlineWrapMatch(
    prefixStart: prefixStart,
    contentStart: selection.start,
    contentEnd: selection.end,
    suffixStart: suffixStart,
    prefixLength: prefix.length,
    suffixLength: suffix.length,
  );
}

_InlineWrapMatch? _findCollapsedInlineWrapMatch(
  String text,
  int offset, {
  required String prefix,
  required String suffix,
}) {
  final emptyPrefixStart = offset - prefix.length;
  if (emptyPrefixStart >= 0 && offset + suffix.length <= text.length) {
    if (text.startsWith(prefix, emptyPrefixStart) &&
        text.startsWith(suffix, offset)) {
      return _InlineWrapMatch(
        prefixStart: emptyPrefixStart,
        contentStart: offset,
        contentEnd: offset,
        suffixStart: offset,
        prefixLength: prefix.length,
        suffixLength: suffix.length,
      );
    }
  }

  var searchStart = offset - prefix.length;
  while (searchStart >= 0) {
    final prefixStart = text.lastIndexOf(prefix, searchStart);
    if (prefixStart == -1) break;
    if (!_isValidInlineDelimiterOccurrence(text, prefixStart, prefix)) {
      searchStart = prefixStart - 1;
      continue;
    }

    final contentStart = prefixStart + prefix.length;
    var suffixSearchStart = contentStart;
    while (suffixSearchStart <= text.length - suffix.length) {
      final suffixStart = text.indexOf(suffix, suffixSearchStart);
      if (suffixStart == -1) break;
      if (_isValidInlineDelimiterOccurrence(text, suffixStart, suffix) &&
          offset >= contentStart &&
          offset <= suffixStart) {
        return _InlineWrapMatch(
          prefixStart: prefixStart,
          contentStart: contentStart,
          contentEnd: suffixStart,
          suffixStart: suffixStart,
          prefixLength: prefix.length,
          suffixLength: suffix.length,
        );
      }
      suffixSearchStart = suffixStart + 1;
    }

    searchStart = prefixStart - 1;
  }
  return null;
}

bool _isValidInlineDelimiterOccurrence(String text, int index, String token) {
  if (token.isEmpty) return false;
  final scalar = token[0];
  final simpleMarkers = '*~=`';
  if (!simpleMarkers.contains(scalar)) return true;
  if (!token.split('').every((char) => char == scalar)) return true;

  final hasSameBefore = index > 0 && text[index - 1] == scalar;
  final tokenEnd = index + token.length;
  final hasSameAfter = tokenEnd < text.length && text[tokenEnd] == scalar;
  return !hasSameBefore && !hasSameAfter;
}

TextEditingValue _unwrapInlineWrap(
  TextEditingValue value,
  TextSelection originalSelection,
  _InlineWrapMatch match,
) {
  final innerText = value.text.substring(match.contentStart, match.contentEnd);
  final nextText = value.text.replaceRange(
    match.prefixStart,
    match.suffixStart + match.suffixLength,
    innerText,
  );

  final nextSelection = originalSelection.isCollapsed
      ? TextSelection.collapsed(
          offset: (originalSelection.baseOffset - match.prefixLength)
              .clamp(match.prefixStart, match.prefixStart + innerText.length)
              .toInt(),
        )
      : TextSelection(
          baseOffset: match.prefixStart,
          extentOffset: match.prefixStart + innerText.length,
        );

  return value.copyWith(
    text: nextText,
    selection: nextSelection,
    composing: TextRange.empty,
  );
}

TextEditingValue insertBlockSnippet(
  TextEditingValue value,
  String snippet, {
  int? caretOffset,
}) {
  final selection = normalizeMarkdownSelection(
    value.selection,
    value.text.length,
  );
  final start = selection.start;
  final end = selection.end;
  final before = value.text.substring(0, start);
  final after = value.text.substring(end);
  final prefix = _blockBoundaryPrefix(before);
  final suffix = _blockBoundarySuffix(after);
  final replacement = '$prefix$snippet$suffix';
  final nextText = value.text.replaceRange(start, end, replacement);
  final nextCaret = start + prefix.length + (caretOffset ?? snippet.length);
  return value.copyWith(
    text: nextText,
    selection: TextSelection.collapsed(offset: nextCaret),
    composing: TextRange.empty,
  );
}

List<MarkdownParagraphRange> collectLogicalParagraphs(String text) {
  if (text.isEmpty) return const <MarkdownParagraphRange>[];
  final lines = _splitIndexedLines(text);
  final paragraphs = <MarkdownParagraphRange>[];

  var index = 0;
  while (index < lines.length) {
    if (lines[index].text.trim().isEmpty) {
      index++;
      continue;
    }

    final start = lines[index].start;
    var end = lines[index].end;
    index++;
    while (index < lines.length && lines[index].text.trim().isNotEmpty) {
      end = lines[index].end;
      index++;
    }
    paragraphs.add(MarkdownParagraphRange(start: start, end: end));
  }

  return paragraphs;
}

List<MarkdownParagraphRange> selectedLogicalParagraphs(
  String text,
  TextSelection selection,
) {
  final paragraphs = collectLogicalParagraphs(text);
  if (paragraphs.isEmpty) return const <MarkdownParagraphRange>[];

  final normalized = normalizeMarkdownSelection(selection, text.length);
  if (normalized.isCollapsed) {
    final offset = normalized.baseOffset;
    for (final paragraph in paragraphs) {
      if (paragraph.containsOffset(offset)) {
        return <MarkdownParagraphRange>[paragraph];
      }
    }
    if (offset == text.length) {
      final last = paragraphs.last;
      if (text.substring(last.end).trim().isEmpty) {
        return <MarkdownParagraphRange>[last];
      }
    }
    return const <MarkdownParagraphRange>[];
  }

  return paragraphs
      .where(
        (paragraph) =>
            paragraph.end > normalized.start &&
            paragraph.start < normalized.end,
      )
      .toList(growable: false);
}

TextEditingValue toggleBlockStyle(
  TextEditingValue value,
  MarkdownBlockStyle targetStyle,
) {
  final normalizedSelection = normalizeMarkdownSelection(
    value.selection,
    value.text.length,
  );
  if (normalizedSelection.isCollapsed) {
    final inlinePrefix = _collapsedInsertionPrefixForBlockStyle(
      value.text,
      normalizedSelection,
      targetStyle,
    );
    if (inlinePrefix != null) {
      return insertInlineSnippet(
        value.copyWith(selection: normalizedSelection),
        inlinePrefix,
      );
    }
  }

  final paragraphs = selectedLogicalParagraphs(value.text, value.selection);
  if (paragraphs.isEmpty) return value;

  final replacements = <_MarkdownReplacement>[];
  final allAlreadyTarget = paragraphs.every((paragraph) {
    final text = value.text.substring(paragraph.start, paragraph.end);
    return _detectBlockStyle(text) == targetStyle;
  });

  for (final paragraph in paragraphs) {
    final original = value.text.substring(paragraph.start, paragraph.end);
    final next = allAlreadyTarget
        ? _removeBlockStyle(original, targetStyle)
        : _applyBlockStyle(_removeAnyBlockStyle(original), targetStyle);
    if (next == original) continue;
    replacements.add(
      _MarkdownReplacement(
        start: paragraph.start,
        end: paragraph.end,
        originalText: original,
        replacementText: next,
      ),
    );
  }

  if (replacements.isEmpty) return value;
  return _applyReplacements(value, replacements);
}

MarkdownCutResult? cutParagraphs(TextEditingValue value) {
  final paragraphs = selectedLogicalParagraphs(value.text, value.selection);
  if (paragraphs.isEmpty) return null;

  final allParagraphs = collectLogicalParagraphs(value.text);
  if (allParagraphs.isEmpty) return null;

  final first = paragraphs.first;
  final last = paragraphs.last;
  final firstIndex = allParagraphs.indexWhere(
    (paragraph) => paragraph.start == first.start && paragraph.end == first.end,
  );
  final lastIndex = allParagraphs.indexWhere(
    (paragraph) => paragraph.start == last.start && paragraph.end == last.end,
  );
  if (firstIndex == -1 || lastIndex == -1 || firstIndex > lastIndex) {
    return null;
  }

  final copiedText = value.text.substring(first.start, last.end);
  final previous = firstIndex > 0 ? allParagraphs[firstIndex - 1] : null;
  final next = lastIndex + 1 < allParagraphs.length
      ? allParagraphs[lastIndex + 1]
      : null;

  late final String nextText;
  late final int caretOffset;
  if (previous == null && next == null) {
    nextText = '';
    caretOffset = 0;
  } else if (previous == null && next != null) {
    nextText = value.text.substring(next.start);
    caretOffset = 0;
  } else if (previous != null && next == null) {
    nextText = value.text.substring(0, previous.end);
    caretOffset = previous.end;
  } else {
    nextText =
        '${value.text.substring(0, previous!.end)}\n\n${value.text.substring(next!.start)}';
    caretOffset = previous.end;
  }

  return MarkdownCutResult(
    value: value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: caretOffset),
      composing: TextRange.empty,
    ),
    copiedText: copiedText,
  );
}

String _blockBoundaryPrefix(String before) {
  if (before.isEmpty) return '';
  if (before.endsWith('\n\n')) return '';
  if (before.endsWith('\n')) return '\n';
  return '\n\n';
}

String _blockBoundarySuffix(String after) {
  if (after.isEmpty) return '';
  if (after.startsWith('\n\n')) return '';
  if (after.startsWith('\n')) return '\n';
  return '\n\n';
}

MarkdownBlockStyle? _detectBlockStyle(String paragraph) {
  final lines = paragraph.split('\n');
  if (lines.isNotEmpty && lines.every(_isQuotedLine)) {
    return MarkdownBlockStyle.quote;
  }

  final firstLine = lines.isEmpty ? '' : lines.first;
  if (_taskLinePattern.hasMatch(firstLine)) return MarkdownBlockStyle.taskList;
  if (_unorderedListLinePattern.hasMatch(firstLine)) {
    return MarkdownBlockStyle.unorderedList;
  }
  if (_orderedListLinePattern.hasMatch(firstLine)) {
    return MarkdownBlockStyle.orderedList;
  }
  if (_heading3LinePattern.hasMatch(firstLine)) {
    return MarkdownBlockStyle.heading3;
  }
  if (_heading2LinePattern.hasMatch(firstLine)) {
    return MarkdownBlockStyle.heading2;
  }
  if (_heading1LinePattern.hasMatch(firstLine)) {
    return MarkdownBlockStyle.heading1;
  }
  return null;
}

String _removeAnyBlockStyle(String paragraph) {
  final detected = _detectBlockStyle(paragraph);
  if (detected == null) return paragraph;
  return _removeBlockStyle(paragraph, detected);
}

String _removeBlockStyle(String paragraph, MarkdownBlockStyle style) {
  switch (style) {
    case MarkdownBlockStyle.quote:
      return paragraph
          .split('\n')
          .map(
            (line) => line.replaceFirstMapped(
              _quoteLinePattern,
              (match) => match.group(1) ?? '',
            ),
          )
          .join('\n');
    case MarkdownBlockStyle.taskList:
      return _replaceFirstLine(paragraph, _taskLinePattern);
    case MarkdownBlockStyle.orderedList:
      return _replaceFirstLine(paragraph, _orderedListLinePattern);
    case MarkdownBlockStyle.unorderedList:
      return _replaceFirstLine(paragraph, _unorderedListLinePattern);
    case MarkdownBlockStyle.heading1:
      return _replaceFirstLine(paragraph, _heading1LinePattern);
    case MarkdownBlockStyle.heading2:
      return _replaceFirstLine(paragraph, _heading2LinePattern);
    case MarkdownBlockStyle.heading3:
      return _replaceFirstLine(paragraph, _heading3LinePattern);
  }
}

String _applyBlockStyle(String paragraph, MarkdownBlockStyle style) {
  switch (style) {
    case MarkdownBlockStyle.quote:
      return paragraph
          .split('\n')
          .map(
            (line) => line.replaceFirstMapped(
              _leadingWhitespacePattern,
              (match) => '${match.group(1) ?? ''}> ',
            ),
          )
          .join('\n');
    case MarkdownBlockStyle.unorderedList:
      return _prefixFirstLine(paragraph, '- ');
    case MarkdownBlockStyle.orderedList:
      return _prefixFirstLine(paragraph, '1. ');
    case MarkdownBlockStyle.taskList:
      return _prefixFirstLine(paragraph, '- [ ] ');
    case MarkdownBlockStyle.heading1:
      return _prefixFirstLine(paragraph, '# ');
    case MarkdownBlockStyle.heading2:
      return _prefixFirstLine(paragraph, '## ');
    case MarkdownBlockStyle.heading3:
      return _prefixFirstLine(paragraph, '### ');
  }
}

String? _collapsedInsertionPrefixForBlockStyle(
  String text,
  TextSelection selection,
  MarkdownBlockStyle style,
) {
  if (!selection.isCollapsed) return null;
  final offset = selection.baseOffset;
  final lineStart = offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
  final lineEndIndex = text.indexOf('\n', offset);
  final lineEnd = lineEndIndex == -1 ? text.length : lineEndIndex;
  final lineText = text.substring(lineStart, lineEnd);
  if (lineText.trim().isNotEmpty) return null;

  return switch (style) {
    MarkdownBlockStyle.unorderedList => '- ',
    MarkdownBlockStyle.orderedList => '1. ',
    MarkdownBlockStyle.taskList => '- [ ] ',
    MarkdownBlockStyle.heading1 => '# ',
    MarkdownBlockStyle.heading2 => '## ',
    MarkdownBlockStyle.heading3 => '### ',
    MarkdownBlockStyle.quote => '> ',
  };
}

String _prefixFirstLine(String paragraph, String prefix) {
  return paragraph.replaceFirstMapped(
    _leadingWhitespacePattern,
    (match) => '${match.group(1) ?? ''}$prefix',
  );
}

String _replaceFirstLine(String paragraph, RegExp pattern) {
  final lineBreakIndex = paragraph.indexOf('\n');
  if (lineBreakIndex == -1) {
    return paragraph.replaceFirstMapped(
      pattern,
      (match) => match.group(1) ?? '',
    );
  }
  final firstLine = paragraph.substring(0, lineBreakIndex);
  final rest = paragraph.substring(lineBreakIndex);
  return firstLine.replaceFirstMapped(
        pattern,
        (match) => match.group(1) ?? '',
      ) +
      rest;
}

TextEditingValue _applyReplacements(
  TextEditingValue value,
  List<_MarkdownReplacement> replacements,
) {
  final sorted = replacements.toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final buffer = StringBuffer();
  var cursor = 0;
  for (final replacement in sorted) {
    buffer.write(value.text.substring(cursor, replacement.start));
    buffer.write(replacement.replacementText);
    cursor = replacement.end;
  }
  buffer.write(value.text.substring(cursor));
  final nextText = buffer.toString();

  final selection = normalizeMarkdownSelection(
    value.selection,
    value.text.length,
  );
  final nextBase = _mapOffsetThroughReplacements(selection.baseOffset, sorted);
  final nextExtent = _mapOffsetThroughReplacements(
    selection.extentOffset,
    sorted,
  );

  return value.copyWith(
    text: nextText,
    selection: TextSelection(baseOffset: nextBase, extentOffset: nextExtent),
    composing: TextRange.empty,
  );
}

int _mapOffsetThroughReplacements(
  int offset,
  List<_MarkdownReplacement> replacements,
) {
  var delta = 0;
  for (final replacement in replacements) {
    if (offset < replacement.start) {
      return offset + delta;
    }
    if (offset <= replacement.end) {
      final localOffset = offset - replacement.start;
      return replacement.start +
          delta +
          replacement.mapLocalOffset(localOffset);
    }
    delta +=
        replacement.replacementText.length - replacement.originalText.length;
  }
  return offset + delta;
}

List<_IndexedLine> _splitIndexedLines(String text) {
  if (text.isEmpty) return const <_IndexedLine>[];
  final lines = <_IndexedLine>[];
  var start = 0;
  while (start <= text.length) {
    final newlineIndex = text.indexOf('\n', start);
    final end = newlineIndex == -1 ? text.length : newlineIndex;
    lines.add(
      _IndexedLine(start: start, end: end, text: text.substring(start, end)),
    );
    if (newlineIndex == -1) {
      break;
    }
    start = newlineIndex + 1;
    if (start == text.length) {
      lines.add(_IndexedLine(start: start, end: start, text: ''));
      break;
    }
  }
  return lines;
}

bool _isQuotedLine(String line) => _quoteLinePattern.hasMatch(line);

final RegExp _leadingWhitespacePattern = RegExp(r'^(\s*)');
final RegExp _unorderedListLinePattern = RegExp(r'^(\s*)-\s+');
final RegExp _orderedListLinePattern = RegExp(r'^(\s*)1\.\s+');
final RegExp _taskLinePattern = RegExp(r'^(\s*)- \[(?: |x|X)\]\s+');
final RegExp _heading1LinePattern = RegExp(r'^(\s*)#\s+');
final RegExp _heading2LinePattern = RegExp(r'^(\s*)##\s+');
final RegExp _heading3LinePattern = RegExp(r'^(\s*)###\s+');
final RegExp _quoteLinePattern = RegExp(r'^(\s*)>\s?');

@immutable
class _IndexedLine {
  const _IndexedLine({
    required this.start,
    required this.end,
    required this.text,
  });

  final int start;
  final int end;
  final String text;
}

@immutable
class _InlineWrapMatch {
  const _InlineWrapMatch({
    required this.prefixStart,
    required this.contentStart,
    required this.contentEnd,
    required this.suffixStart,
    required this.prefixLength,
    required this.suffixLength,
  });

  final int prefixStart;
  final int contentStart;
  final int contentEnd;
  final int suffixStart;
  final int prefixLength;
  final int suffixLength;
}

@immutable
class _MarkdownReplacement {
  const _MarkdownReplacement({
    required this.start,
    required this.end,
    required this.originalText,
    required this.replacementText,
  });

  final int start;
  final int end;
  final String originalText;
  final String replacementText;

  int mapLocalOffset(int offset) {
    final clamped = offset.clamp(0, originalText.length).toInt();
    final prefixLength = _commonPrefixLength(originalText, replacementText);
    final suffixLength = _commonSuffixLength(
      originalText,
      replacementText,
      prefixLength,
    );

    if (clamped <= prefixLength) {
      return clamped;
    }
    if (clamped >= originalText.length - suffixLength) {
      final distanceFromEnd = originalText.length - clamped;
      return replacementText.length - distanceFromEnd;
    }
    return prefixLength;
  }
}

int _commonPrefixLength(String a, String b) {
  final limit = a.length < b.length ? a.length : b.length;
  var index = 0;
  while (index < limit && a.codeUnitAt(index) == b.codeUnitAt(index)) {
    index++;
  }
  return index;
}

int _commonSuffixLength(String a, String b, int prefixLength) {
  final aMax = a.length - prefixLength;
  final bMax = b.length - prefixLength;
  final limit = aMax < bMax ? aMax : bMax;
  var index = 0;
  while (index < limit &&
      a.codeUnitAt(a.length - 1 - index) ==
          b.codeUnitAt(b.length - 1 - index)) {
    index++;
  }
  return index;
}
