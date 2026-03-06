import 'package:flutter/material.dart';

import '../../core/memoflow_palette.dart';
import '../../core/tag_badge.dart';
import '../../core/tag_colors.dart';
import '../../state/memos/memos_providers.dart';
import '../../i18n/strings.g.dart';

class TagTreeNode {
  TagTreeNode({
    required this.key,
    required this.path,
    required this.count,
    this.tagId,
    this.parentId,
    this.pinned = false,
    this.colorHex,
    this.effectiveColorHex,
    List<TagTreeNode>? children,
  }) : children = children ?? [];

  final String key;
  final String path;
  final int? tagId;
  final int? parentId;
  final bool pinned;
  final String? colorHex;
  String? effectiveColorHex;
  int count;
  final List<TagTreeNode> children;
}

List<TagTreeNode> buildTagTree(List<TagStat> stats) {
  final cleaned = stats
      .where((s) => s.tag.trim().isNotEmpty)
      .toList(growable: false);
  if (cleaned.isEmpty) return const [];

  final nodesByPath = <String, TagTreeNode>{};
  final nodesById = <int, TagTreeNode>{};

  for (final stat in cleaned) {
    final path = stat.path.trim();
    if (path.isEmpty) continue;
    final key = path.contains('/') ? path.split('/').last : path;
    final existing = nodesByPath[path];
    final node =
        existing ??
        TagTreeNode(
          key: key,
          path: path,
          count: 0,
          tagId: stat.tagId,
          parentId: stat.parentId,
          pinned: stat.pinned,
          colorHex: stat.colorHex,
        );
    if (existing == null) {
      nodesByPath[path] = node;
    }
    node.count = stat.count;
    node.effectiveColorHex ??= stat.colorHex;
    if (stat.tagId != null) {
      nodesById[stat.tagId!] = node;
    }
  }

  final rootNodes = <TagTreeNode>[];
  final attached = <String>{};

  for (final node in nodesById.values) {
    final parentId = node.parentId;
    if (parentId != null && nodesById.containsKey(parentId)) {
      nodesById[parentId]!.children.add(node);
    } else {
      rootNodes.add(node);
    }
    attached.add(node.path);
  }

  for (final node in nodesByPath.values) {
    if (attached.contains(node.path)) continue;
    _attachByPath(node, nodesByPath, rootNodes, attached);
  }

  _applyInheritedColors(rootNodes, null);
  _sortNodes(rootNodes);
  return rootNodes;
}

void _sortNodes(List<TagTreeNode> nodes) {
  nodes.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return a.key.compareTo(b.key);
  });
  for (final node in nodes) {
    if (node.children.isNotEmpty) {
      _sortNodes(node.children);
    }
  }
}

void _attachByPath(
  TagTreeNode node,
  Map<String, TagTreeNode> nodesByPath,
  List<TagTreeNode> rootNodes,
  Set<String> attached,
) {
  if (attached.contains(node.path)) return;
  if (!node.path.contains('/')) {
    rootNodes.add(node);
    attached.add(node.path);
    return;
  }
  final parentPath = node.path.substring(0, node.path.lastIndexOf('/'));
  final parentNode = nodesByPath.putIfAbsent(
    parentPath,
    () => TagTreeNode(
      key: parentPath.split('/').last,
      path: parentPath,
      count: 0,
    ),
  );
  parentNode.children.add(node);
  attached.add(node.path);
  if (!attached.contains(parentNode.path)) {
    _attachByPath(parentNode, nodesByPath, rootNodes, attached);
  }
}

void _applyInheritedColors(List<TagTreeNode> nodes, String? inheritedHex) {
  for (final node in nodes) {
    final own = node.colorHex;
    final resolved = own != null && own.trim().isNotEmpty ? own : inheritedHex;
    node.effectiveColorHex = resolved;
    if (node.children.isNotEmpty) {
      _applyInheritedColors(node.children, resolved);
    }
  }
}

class TagTreeList extends StatelessWidget {
  const TagTreeList({
    super.key,
    required this.nodes,
    required this.onSelect,
    required this.textMain,
    required this.textMuted,
    this.showCount = false,
    this.initiallyExpanded = true,
    this.compact = false,
    this.onEdit,
    this.selectedPath,
  });

  final List<TagTreeNode> nodes;
  final ValueChanged<String> onSelect;
  final Color textMain;
  final Color textMuted;
  final bool showCount;
  final bool initiallyExpanded;
  final bool compact;
  final ValueChanged<TagTreeNode>? onEdit;
  final String? selectedPath;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        for (final node in nodes)
          _TagTreeItem(
            node: node,
            depth: 0,
            onSelect: onSelect,
            textMain: textMain,
            textMuted: textMuted,
            showCount: showCount,
            initiallyExpanded: initiallyExpanded,
            compact: compact,
            onEdit: onEdit,
            selectedPath: selectedPath,
          ),
      ],
    );
  }
}

class _TagTreeItem extends StatefulWidget {
  const _TagTreeItem({
    required this.node,
    required this.depth,
    required this.onSelect,
    required this.textMain,
    required this.textMuted,
    required this.showCount,
    required this.initiallyExpanded,
    required this.compact,
    required this.onEdit,
    required this.selectedPath,
  });

  final TagTreeNode node;
  final int depth;
  final ValueChanged<String> onSelect;
  final Color textMain;
  final Color textMuted;
  final bool showCount;
  final bool initiallyExpanded;
  final bool compact;
  final ValueChanged<TagTreeNode>? onEdit;
  final String? selectedPath;

  @override
  State<_TagTreeItem> createState() => _TagTreeItemState();
}

class _TagTreeItemState extends State<_TagTreeItem> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant _TagTreeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.path != widget.node.path) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final hasChildren = node.children.isNotEmpty;
    final indent = widget.compact ? 10.0 : 14.0;
    final vertical = widget.compact ? 8.0 : 10.0;
    final iconSize = widget.compact ? 18.0 : 20.0;
    final label = '#${node.key}';
    final count = widget.showCount && node.count > 1 ? ' (${node.count})' : '';
    final normalizedSelectedPath = widget.selectedPath?.trim();
    final isSelected =
        normalizedSelectedPath != null &&
        normalizedSelectedPath.isNotEmpty &&
        normalizedSelectedPath == node.path;
    final accent = MemoFlowPalette.primary;
    final colors = node.effectiveColorHex == null
        ? null
        : buildTagChipColors(
            baseColor: parseTagColor(node.effectiveColorHex!) ?? accent,
            surfaceColor: Theme.of(context).colorScheme.surface,
            isDark: Theme.of(context).brightness == Brightness.dark,
          );

    final row = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => widget.onSelect(node.path),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: vertical),
        child: Row(
          children: [
            Icon(Icons.tag, size: iconSize, color: widget.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TagBadge(
                  label: '$label$count',
                  colors: colors,
                  compact: widget.compact,
                ),
              ),
            ),
            if (node.pinned)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.push_pin, size: 16, color: widget.textMuted),
              ),
            if (hasChildren)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: AnimatedRotation(
                  turns: _expanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: widget.textMuted,
                  ),
                ),
              ),
            if (node.tagId != null &&
                widget.onEdit != null &&
                (!widget.compact || isSelected))
              IconButton(
                onPressed: () => widget.onEdit?.call(node),
                icon: Icon(Icons.edit, size: 18, color: widget.textMuted),
                tooltip: context.t.strings.legacy.msg_edit_tag,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );

    if (!hasChildren) {
      return Padding(
        padding: EdgeInsets.only(left: widget.depth * indent),
        child: row,
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: widget.depth * indent),
      child: Column(
        children: [
          row,
          if (_expanded)
            Container(
              margin: EdgeInsets.only(left: indent),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: accent.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                ),
              ),
              child: Column(
                children: [
                  for (final child in node.children)
                    _TagTreeItem(
                      node: child,
                      depth: widget.depth + 1,
                      onSelect: widget.onSelect,
                      textMain: widget.textMain,
                      textMuted: widget.textMuted,
                      showCount: widget.showCount,
                      initiallyExpanded: widget.initiallyExpanded,
                      compact: widget.compact,
                      onEdit: widget.onEdit,
                      selectedPath: widget.selectedPath,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
