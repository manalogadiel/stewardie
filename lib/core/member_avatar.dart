import 'package:flutter/material.dart';

/// A stable identity chip: names may change, but color follows the account UID.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.uid,
    required this.name,
    this.radius = 20,
    this.selected = false,
  });
  final String uid;
  final String name;
  final double radius;
  final bool selected;

  static const colors = [
    Color(0xFFA9CDE8),
    Color(0xFFEAB8C5),
    Color(0xFFF8E7B0),
    Color(0xFFBFD9C1),
    Color(0xFFD4C4EA),
  ];

  static Color colorFor(String uid) {
    var hash = 0;
    for (final code in uid.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return colors[hash % colors.length];
  }

  static String initialsFor(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    return (words.length == 1
            ? words.first.substring(0, 1)
            : '${words.first[0]}${words.last[0]}')
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(selected ? 3 : 0),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: selected
          ? Border.all(color: const Color(0xFF244BFF), width: 2)
          : null,
    ),
    child: CircleAvatar(
      radius: radius,
      backgroundColor: colorFor(uid),
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Center(
          child: Text(
            initialsFor(name),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF202633),
              // height:1 prevents line-box misalignment at small sizes.
              height: 1,
              fontSize: radius.clamp(10.0, 18.0),
            ),
          ),
        ),
      ),
    ),
  );
}
