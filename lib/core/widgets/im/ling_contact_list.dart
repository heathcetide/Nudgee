import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';

/// A contact list with A-Z alphabetical index.
///
/// Features:
/// - Alphabetical grouping
/// - A-Z quick index bar
/// - Search
/// - Online status indicator
/// - Tap to start conversation
class LingContactList extends StatefulWidget {
  final List<LingChatUser> contacts;
  final ValueChanged<LingChatUser>? onContactTap;
  final ValueChanged<LingChatUser>? onContactLongPress;
  final String? searchQuery;
  final ValueChanged<String>? onSearchChanged;

  const LingContactList({
    super.key,
    required this.contacts,
    this.onContactTap,
    this.onContactLongPress,
    this.searchQuery,
    this.onSearchChanged,
  });

  @override
  State<LingContactList> createState() => _LingContactListState();
}

class _LingContactListState extends State<LingContactList> {
  final ScrollController _scrollController = ScrollController();
  String _activeLetter = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Group contacts by first letter of pinyin (simplified: use first char uppercased).
  Map<String, List<LingChatUser>> _groupContacts() {
    final filtered = widget.searchQuery != null && widget.searchQuery!.isNotEmpty
        ? widget.contacts
            .where((c) => c.name.toLowerCase().contains(widget.searchQuery!.toLowerCase()))
            .toList()
        : widget.contacts;

    final groups = <String, List<LingChatUser>>{};
    for (final contact in filtered) {
      final letter = _getFirstLetter(contact.name);
      groups.putIfAbsent(letter, () => []).add(contact);
    }
    // Sort groups alphabetically, with '#' at the end
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });
    return {for (final k in sortedKeys) k: groups[k]!};
  }

  String _getFirstLetter(String name) {
    if (name.isEmpty) return '#';
    final char = name.codeUnitAt(0);
    if (char >= 65 && char <= 90 || char >= 97 && char <= 122) {
      return String.fromCharCode(char).toUpperCase();
    }
    // For Chinese characters, simplified: use '#'
    // A real implementation would use lpinyin or similar
    return '#';
  }

  void _scrollToLetter(String letter, Map<String, List<LingChatUser>> groups) {
    final keys = groups.keys.toList();
    final index = keys.indexOf(letter);
    if (index == -1) return;
    // Approximate scroll offset: each header ~ 32px + items ~ 60px
    double offset = 0;
    for (int i = 0; i < index; i++) {
      offset += 32 + groups[keys[i]]!.length * 60.0;
    }
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = _groupContacts();
    final letters = groups.keys.toList();

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          itemCount: groups.length,
          itemBuilder: (context, groupIndex) {
            final letter = letters[groupIndex];
            final contacts = groups[letter]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  child: Text(
                    letter,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Contacts
                for (final contact in contacts)
                  InkWell(
                    onTap: () => widget.onContactTap?.call(contact),
                    onLongPress: () => widget.onContactLongPress?.call(contact),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingMd,
                        vertical: AppConstants.spacingSm,
                      ),
                      child: Row(
                        children: [
                          LingAvatar(
                            imageUrl: contact.avatarUrl,
                            name: contact.name,
                            size: LingAvatarSize.lg,
                            showOnlineStatus: contact.isOnline,
                          ),
                          const SizedBox(width: AppConstants.spacingMd),
                          Expanded(
                            child: Text(
                              contact.name,
                              style: theme.textTheme.bodyLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        // A-Z index bar
        if (letters.isNotEmpty)
          Positioned(
            right: 2,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                final box = context.findRenderObject() as RenderBox;
                final y = details.localPosition.dy;
                final height = box.size.height;
                final letterHeight = height / 26;
                final index = (y / letterHeight).floor().clamp(0, 25);
                final letter = String.fromCharCode(65 + index);
                if (groups.containsKey(letter)) {
                  setState(() => _activeLetter = letter);
                  _scrollToLetter(letter, groups);
                }
              },
              onVerticalDragEnd: (_) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) setState(() => _activeLetter = '');
                });
              },
              child: Container(
                width: 24,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: letters.map((letter) {
                    final isActive = _activeLetter == letter;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _activeLetter = letter);
                        _scrollToLetter(letter, groups);
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted) setState(() => _activeLetter = '');
                        });
                      },
                      child: Container(
                        width: 20,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: isActive
                            ? BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        // Active letter bubble
        if (_activeLetter.isNotEmpty)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _activeLetter,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
