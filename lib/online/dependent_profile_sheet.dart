import 'package:flutter/material.dart';

import 'online_backend.dart';

/// Modal bottom sheet to create or manage a child or dependent profile.
class DependentProfileSheet extends StatefulWidget {
  const DependentProfileSheet({
    super.key,
    required this.backend,
    required this.spaceId,
    this.memberId,
    this.initialName,
    this.initialRole,
    this.initialColor,
    required this.onSaved,
  });

  final OnlineBackend backend;
  final String spaceId;
  final String? memberId;
  final String? initialName;
  final String? initialRole;
  final String? initialColor;
  final VoidCallback onSaved;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required String spaceId,
    String? memberId,
    String? initialName,
    String? initialRole,
    String? initialColor,
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DependentProfileSheet(
        backend: backend,
        spaceId: spaceId,
        memberId: memberId,
        initialName: initialName,
        initialRole: initialRole,
        initialColor: initialColor,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<DependentProfileSheet> createState() => _DependentProfileSheetState();
}

class _DependentProfileSheetState extends State<DependentProfileSheet> {
  late final TextEditingController _nameController;
  String _selectedRole = 'Child';
  String _selectedColor = 'sky';
  bool _busy = false;

  static const List<String> _roles = [
    'Child',
    'Parent',
    'Guardian',
    'Housemate',
    'Grandparent',
    'Dependent',
  ];

  static const Map<String, Color> _colors = {
    'sky': Color(0xFFCBE3FB),
    'butter': Color(0xFFFBE4A8),
    'rose': Color(0xFFF7CCD7),
    'sage': Color(0xFFD2E8D4),
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedRole = widget.initialRole ?? 'Child';
    _selectedColor = widget.initialColor ?? 'sky';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _busy = true);
    try {
      if (widget.memberId != null) {
        await widget.backend.updateDependentProfile(
          widget.spaceId,
          widget.memberId!,
          name: name,
          familyRole: _selectedRole,
          color: _selectedColor,
        );
      } else {
        await widget.backend.createDependentProfile(
          widget.spaceId,
          name: name,
          familyRole: _selectedRole,
          color: _selectedColor,
        );
      }
      if (mounted) {
        widget.onSaved();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (widget.memberId == null) return;
    setState(() => _busy = true);
    try {
      await widget.backend.deleteDependentProfile(widget.spaceId, widget.memberId!);
      if (mounted) {
        widget.onSaved();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isEditing = widget.memberId != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + media.viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4D0C8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit profile' : 'Add family profile',
                    style: const TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF202633),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF596171)),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Name',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF596171),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 16,
                  color: Color(0xFF202633),
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Leo, Grandma...',
                  hintStyle: const TextStyle(color: Color(0xFF8E95A5)),
                  filled: true,
                  fillColor: const Color(0xFFFFFEFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE5E2DA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE5E2DA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF244BFF)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Family role',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF596171),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _roles.map((role) {
                  final isSelected = _selectedRole == role;
                  return ChoiceChip(
                    label: Text(
                      role,
                      style: TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? const Color(0xFF244BFF) : const Color(0xFF202633),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFFE8EEFF),
                    backgroundColor: const Color(0xFFFFFEFB),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF244BFF) : const Color(0xFFE5E2DA),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _selectedRole = role),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Color theme',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF596171),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _colors.entries.map((entry) {
                  final isSelected = _selectedColor == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () => setState(() => _selectedColor = entry.key),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: entry.value,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF202633) : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 18, color: Color(0xFF202633))
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else ...[
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF244BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Save profile',
                      style: TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (isEditing) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _delete,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                      ),
                      child: const Text(
                        'Remove profile',
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
