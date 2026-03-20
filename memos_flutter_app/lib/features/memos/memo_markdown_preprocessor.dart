final RegExp _tagTokenPattern = RegExp(
  r'^#(?!#|\s)[\p{L}\p{N}\p{S}_/\-]{1,100}$',
  unicode: true,
);
final RegExp _tagInlinePattern = RegExp(
  r'#(?!#|\s)([\p{L}\p{N}\p{S}_/\-]{1,100})',
  unicode: true,
);
final RegExp _markdownImagePattern = RegExp(
  r'!\[[^\]]*]\(([^)\s]+)(?:\s+"[^"]*")?\)',
);
final RegExp _codeFencePattern = RegExp(r'^\s*(```|~~~)');
final RegExp _unorderedListMarkerPattern = RegExp(r'^[-*+]\s');
final RegExp _orderedListMarkerPattern = RegExp(r'^\d+[.)]\s');
final RegExp _horizontalRuleLinePattern = RegExp(
  r'^(?:-{3,}|\*{3,}|_{3,})\s*$',
);
final RegExp _setextHeadingUnderlinePattern = RegExp(r'^(?:=+|-+)\s*$');
final RegExp _fullHtmlDoctypeLinePattern = RegExp(
  r'^\s*<!doctype\s+html(?:\s[^>]*)?>\s*$',
  caseSensitive: false,
);
final RegExp _fullHtmlOpenTagLinePattern = RegExp(
  r'^\s*<html(?:\s|>)',
  caseSensitive: false,
);
final RegExp _fullHtmlCloseTagPattern = RegExp(
  r'</html\s*>',
  caseSensitive: false,
);

const String _zeroWidthSpace = '\u200B';

String stripMarkdownImages(String text) {
  if (text.trim().isEmpty) return text;
  final lines = text.split('\n');
  final out = <String>[];
  var inFence = false;

  for (final line in lines) {
    if (_codeFencePattern.hasMatch(line.trimLeft())) {
      inFence = !inFence;
      out.add(line);
      continue;
    }
    if (inFence) {
      out.add(line);
      continue;
    }
    if (line.trim().isEmpty) {
      out.add('');
      continue;
    }
    final cleaned = line.replaceAll(_markdownImagePattern, '').trimRight();
    if (cleaned.trim().isEmpty) continue;
    out.add(cleaned);
  }

  return out.join('\n');
}

String sanitizeMemoMarkdown(String text) {
  final emptyLink = RegExp(r'\[\s*\]\(([^)]*)\)');
  final stripped = text.replaceAllMapped(emptyLink, (match) {
    final start = match.start;
    if (start > 0 && text.codeUnitAt(start - 1) == 0x21) {
      return match.group(0) ?? '';
    }
    final url = match.group(1)?.trim();
    return url?.isNotEmpty == true ? url! : '';
  });
  final protectedHtml = _protectEmbeddedFullHtmlDocuments(stripped);
  final escapedTaskHeadings = _escapeEmptyTaskHeadings(protectedHtml);
  final preservedBlankLines = _preserveParagraphBlankLines(escapedTaskHeadings);
  return _normalizeFencedCodeBlocks(preservedBlankLines);
}

bool looksLikeFullHtmlDocument(String text) {
  final trimmed = text.trimLeft();
  return RegExp(
    r'^(?:<!doctype\s+html(?:\s[^>]*)?>\s*)?<html(?:\s|>)',
    caseSensitive: false,
  ).hasMatch(trimmed);
}

String normalizeMemoTagSpacing(String text) {
  final lines = text.split('\n');
  var idx = 0;
  while (idx < lines.length && lines[idx].trim().isEmpty) {
    idx++;
  }

  var tagEnd = idx;
  while (tagEnd < lines.length && _isTagOnlyLine(lines[tagEnd])) {
    tagEnd++;
  }

  if (tagEnd == idx) return text;

  var blankEnd = tagEnd;
  while (blankEnd < lines.length && lines[blankEnd].trim().isEmpty) {
    blankEnd++;
  }
  if (blankEnd == tagEnd || blankEnd >= lines.length) return text;

  final normalized = <String>[
    ...lines.take(tagEnd),
    '',
    ...lines.skip(blankEnd),
  ];
  return normalized.join('\n');
}

String decorateMemoTagsForHtml(String text) {
  final lines = text.split('\n');
  int? firstLine;
  int? lastLine;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    firstLine ??= i;
    lastLine = i;
  }
  if (firstLine == null || lastLine == null) return text;

  lines[firstLine] = _replaceTagsInLine(lines[firstLine]);
  if (lastLine != firstLine) {
    lines[lastLine] = _replaceTagsInLine(lines[lastLine]);
  }

  return lines.join('\n');
}

String _preserveParagraphBlankLines(String text) {
  final lines = text.split('\n');
  if (lines.length < 3) return text;

  var inFence = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_codeFencePattern.hasMatch(line.trimLeft())) {
      inFence = !inFence;
      continue;
    }
    if (inFence || line.trim().isNotEmpty) continue;

    var prev = i - 1;
    while (prev >= 0 && lines[prev].trim().isEmpty) {
      prev--;
    }
    if (prev < 0) continue;

    var next = i + 1;
    while (next < lines.length && lines[next].trim().isEmpty) {
      next++;
    }
    if (next >= lines.length) continue;

    if (!_isParagraphLikeTextLine(lines[prev])) continue;
    if (!_isParagraphLikeTextLine(lines[next])) continue;

    lines[i] = _zeroWidthSpace;
  }

  return lines.join('\n');
}

bool _isParagraphLikeTextLine(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith('<')) return false;
  if (trimmed.startsWith('#')) return false;
  if (trimmed.startsWith('>')) return false;
  if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) return false;
  if (trimmed.startsWith('|')) return false;
  if (_unorderedListMarkerPattern.hasMatch(trimmed)) return false;
  if (_orderedListMarkerPattern.hasMatch(trimmed)) return false;
  if (_horizontalRuleLinePattern.hasMatch(trimmed)) return false;
  if (_setextHeadingUnderlinePattern.hasMatch(trimmed)) return false;
  return true;
}

String _protectEmbeddedFullHtmlDocuments(String text) {
  final lines = text.split('\n');
  if (lines.isEmpty) return text;

  final output = <String>[];
  var index = 0;
  var inFence = false;

  while (index < lines.length) {
    final line = lines[index];
    if (_codeFencePattern.hasMatch(line.trimLeft())) {
      inFence = !inFence;
      output.add(line);
      index++;
      continue;
    }

    if (!inFence && _isEmbeddedFullHtmlDocumentStart(lines, index)) {
      final end = _findEmbeddedFullHtmlDocumentEnd(lines, index);
      if (end >= index) {
        if (output.isNotEmpty && output.last.trim().isNotEmpty) {
          output.add('');
        }
        output.add('```html');
        output.addAll(lines.getRange(index, end + 1));
        output.add('```');
        if (end + 1 < lines.length && lines[end + 1].trim().isNotEmpty) {
          output.add('');
        }
        index = end + 1;
        continue;
      }
    }

    output.add(line);
    index++;
  }

  return output.join('\n');
}

bool _isEmbeddedFullHtmlDocumentStart(List<String> lines, int index) {
  final line = lines[index].trimLeft();
  if (_fullHtmlOpenTagLinePattern.hasMatch(line)) {
    return true;
  }
  if (!_fullHtmlDoctypeLinePattern.hasMatch(line)) {
    return false;
  }
  for (var i = index + 1; i < lines.length; i++) {
    final next = lines[i].trimLeft();
    if (next.isEmpty) continue;
    return _fullHtmlOpenTagLinePattern.hasMatch(next);
  }
  return false;
}

int _findEmbeddedFullHtmlDocumentEnd(List<String> lines, int start) {
  for (var i = start; i < lines.length; i++) {
    final line = lines[i];
    if (_fullHtmlCloseTagPattern.hasMatch(line)) {
      return i;
    }
    if (_codeFencePattern.hasMatch(line.trimLeft())) {
      return -1;
    }
  }
  return -1;
}

String _escapeEmptyTaskHeadings(String text) {
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final match = RegExp(
      r'^(\s*[-*+]\s+\[(?: |x|X)\]\s*)(#{1,6})\s*$',
    ).firstMatch(lines[i]);
    if (match == null) continue;
    final prefix = match.group(1) ?? '';
    final hashes = match.group(2) ?? '';
    final escaped = List.filled(hashes.length, r'\#').join();
    lines[i] = '$prefix$escaped';
  }
  return lines.join('\n');
}

String _normalizeFencedCodeBlocks(String text) {
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty) continue;
    var index = 0;
    while (index < line.length) {
      final codeUnit = line.codeUnitAt(index);
      if (codeUnit == 0x20 || codeUnit == 0x09 || codeUnit == 0x3000) {
        index++;
        continue;
      }
      break;
    }
    if (index == 0) continue;
    final trimmed = line.substring(index);
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      final indent = index > 3 ? 3 : index;
      lines[i] = '${''.padLeft(indent)}$trimmed';
    }
  }
  return lines.join('\n');
}

bool _isTagOnlyLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  final parts = trimmed.split(RegExp(r'\s+'));
  for (final part in parts) {
    if (!_tagTokenPattern.hasMatch(part)) return false;
  }
  return true;
}

String _replaceTagsInLine(String line) {
  final matches = _tagInlinePattern.allMatches(line);
  if (matches.isEmpty) return line;

  final buffer = StringBuffer();
  var last = 0;
  for (final match in matches) {
    buffer.write(line.substring(last, match.start));
    final tag = match.group(1);
    if (tag == null || tag.isEmpty) {
      buffer.write(match.group(0));
    } else {
      final escaped = _escapeHtmlAttribute(tag);
      buffer.write('<span class="memotag" data-tag="$escaped">#$tag</span>');
    }
    last = match.end;
  }
  buffer.write(line.substring(last));
  return buffer.toString();
}

String _escapeHtmlAttribute(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
