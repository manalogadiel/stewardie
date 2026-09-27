import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'online_backend.dart';

/// Modal bottom sheet for managing recurring routines in a space.
class RoutinesSheet extends StatefulWidget {
  const RoutinesSheet({
    super.key,
    required this.backend,
    required this.spaceId,
    required this.members,
  });

  final OnlineBackend backend;
  final String spaceId;
  final List<Map<String, dynamic>> members;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required String spaceId,
    required List<Map<String, dynamic>> members,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => RoutinesSheet(
        backend: backend,
        spaceId: spaceId,
        members: members,
      ),
    );
  }

  @override
  State<RoutinesSheet> createState() => _RoutinesSheetState();
}

class _RoutinesSheetState extends State<RoutinesSheet> {
  final TextEditingController _titleController = TextEditingController();
  String _cadence = 'daily'; // 'daily', 'weekdays', 'weekly'
  String? _assignedUid;
  bool _busy = false;

  Future<void> _createRoutine() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _busy = true);
    try {
      await widget.backend.call('createRoutine', {
        'spaceId': widget.spaceId,
        'title': title,
        'cadence': _cadence,
        'assignedUid': _assignedUid,
      });
      _titleController.clear();
      setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create routine: $e')),
        );
      }
    }
  }

  Future<void> _deleteRoutine(String routineId) async {
    try {
      await widget.backend.call('deleteRoutine', {
        'spaceId': widget.spaceId,
        'routineId': routineId,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete routine: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

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
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Routines',
                    style: TextStyle(
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
              // Stream of existing routines
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.backend.routines(widget.spaceId),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFEFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E2DA)),
                      ),
                      child: const Center(
                        child: Text(
                          'No routines yet',
                          style: TextStyle(
                            fontFamily: 'NunitoSans',
                            color: Color(0xFF8E95A5),
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final title = data['title'] as String? ?? 'Routine';
                      final cadence = data['cadence'] as String? ?? 'daily';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFEFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E2DA)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontFamily: 'NunitoSans',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF202633),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cadence[0].toUpperCase() + cadence.substring(1),
                                    style: const TextStyle(
                                      fontFamily: 'NunitoSans',
                                      fontSize: 12,
                                      color: Color(0xFF596171),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _deleteRoutine(doc.id),
                              icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFD32F2F)),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'New routine',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF202633),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 15,
                  color: Color(0xFF202633),
                ),
                decoration: InputDecoration(
                  hintText: 'Routine title',
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
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final c in ['daily', 'weekdays', 'weekly'])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              c[0].toUpperCase() + c.substring(1),
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 13,
                                fontWeight: _cadence == c ? FontWeight.w700 : FontWeight.w500,
                                color: _cadence == c ? Colors.white : const Color(0xFF202633),
                              ),
                            ),
                          ),
                          selected: _cadence == c,
                          selectedColor: const Color(0xFF244BFF),
                          backgroundColor: const Color(0xFFFFFEFB),
                          side: BorderSide(
                            color: _cadence == c ? const Color(0xFF244BFF) : const Color(0xFFE5E2DA),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (val) {
                            if (val) setState(() => _cadence = c);
                          },
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _assignedUid,
                decoration: InputDecoration(
                  labelText: 'Assign to (optional)',
                  filled: true,
                  fillColor: const Color(0xFFFFFEFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE5E2DA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE5E2DA)),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Anyone in space'),
                  ),
                  for (final m in widget.members)
                    DropdownMenuItem<String?>(
                      value: m['uid'] as String?,
                      child: Text(m['name'] as String? ?? 'Member'),
                    ),
                ],
                onChanged: (val) => setState(() => _assignedUid = val),
              ),
              const SizedBox(height: 20),
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _createRoutine,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF244BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Create routine',
                      style: TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
