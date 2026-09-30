import 'package:flutter/material.dart';

import 'external_launcher.dart';
import 'online_backend.dart';
import 'online_moments.dart';
import 'task_completion_prompt_sheet.dart';

/// Draggable task detail modal bottom sheet with seamless auto-save.
class OnlineTaskDetailSheet extends StatefulWidget {
  const OnlineTaskDetailSheet({
    super.key,
    required this.backend,
    required this.spaceId,
    required this.task,
    required this.members,
    required this.momentStore,
    required this.onChanged,
  });

  final OnlineBackend backend;
  final String spaceId;
  final Map<String, dynamic> task;
  final List<Map<String, dynamic>> members;
  final OnlineMomentsStore momentStore;
  final VoidCallback onChanged;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required String spaceId,
    required Map<String, dynamic> task,
    required List<Map<String, dynamic>> members,
    required OnlineMomentsStore momentStore,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => OnlineTaskDetailSheet(
        backend: backend,
        spaceId: spaceId,
        task: task,
        members: members,
        momentStore: momentStore,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<OnlineTaskDetailSheet> createState() => _OnlineTaskDetailSheetState();
}

class _OnlineTaskDetailSheetState extends State<OnlineTaskDetailSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _destinationController;
  late final TextEditingController _newSubtaskController;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _noteFocus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();

  String? _selectedAssignee;
  bool _busy = false;
  bool _helpNeeded = false;
  late List<Map<String, dynamic>> _subtasks;
  late List<Map<String, dynamic>> _activity;

  String get _taskId =>
      widget.task['id'] as String? ?? widget.task['taskId'] as String;
  bool get _completed => widget.task['status'] == 'completed';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.task['title'] as String? ?? '',
    );
    _noteController = TextEditingController(
      text: widget.task['note'] as String? ?? '',
    );
    _destinationController = TextEditingController(
      text: widget.task['destination'] as String? ?? '',
    );
    _newSubtaskController = TextEditingController();
    _selectedAssignee =
        widget.task['requestedUid'] as String? ??
        widget.task['ownerUid'] as String?;
    _helpNeeded =
        widget.task['helpNeeded'] == true ||
        widget.task['status'] == 'needsHelp';
    _subtasks = List<Map<String, dynamic>>.from(
      (widget.task['subtasks'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    _activity = List<Map<String, dynamic>>.from(
      (widget.task['activity'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    _titleFocus.addListener(_onFocusChanged);
    _noteFocus.addListener(_onFocusChanged);
    _destinationFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_titleFocus.hasFocus &&
        !_noteFocus.hasFocus &&
        !_destinationFocus.hasFocus) {
      _autoSave();
    }
  }

  Future<void> _autoSave() async {
    if (_completed) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final note = _noteController.text.trim();
    final destination = _destinationController.text.trim();

    try {
      await widget.backend.call('updateTask', {
        'spaceId': widget.spaceId,
        'taskId': _taskId,
        'title': title,
        'note': note,
        'destination': destination,
        'requestedUid': _selectedAssignee,
      });
      widget.onChanged();
    } catch (_) {}
  }

  Future<void> _toggleSubtask(int index) async {
    setState(() {
      _subtasks[index]['done'] = !(_subtasks[index]['done'] == true);
    });
    try {
      await widget.backend.setSubtasks(widget.spaceId, _taskId, _subtasks);
      widget.onChanged();
    } catch (_) {}
  }

  Future<void> _addSubtask() async {
    final text = _newSubtaskController.text.trim();
    if (text.isEmpty) return;
    _newSubtaskController.clear();
    setState(() {
      _subtasks.add({
        'id': 'sub_${DateTime.now().millisecondsSinceEpoch}',
        'title': text,
        'done': false,
      });
    });
    try {
      await widget.backend.setSubtasks(widget.spaceId, _taskId, _subtasks);
      widget.onChanged();
    } catch (_) {}
  }

  Future<void> _removeSubtask(int index) async {
    setState(() {
      _subtasks.removeAt(index);
    });
    try {
      await widget.backend.setSubtasks(widget.spaceId, _taskId, _subtasks);
      widget.onChanged();
    } catch (_) {}
  }

  Future<void> _requestHelp() async {
    setState(() => _busy = true);
    try {
      await widget.backend.requestHelp(widget.spaceId, _taskId);
      setState(() {
        _helpNeeded = true;
        _activity.insert(0, {
          'action': 'help_requested',
          'uid': widget.backend.auth.currentUser?.uid,
          'name': widget.backend.auth.currentUser?.displayName ?? 'Member',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        _busy = false;
      });
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not request help: $e')));
      }
    }
  }

  Future<void> _takeOverTask() async {
    setState(() => _busy = true);
    try {
      await widget.backend.takeOverTask(widget.spaceId, _taskId);
      setState(() {
        _helpNeeded = false;
        _selectedAssignee = widget.backend.auth.currentUser?.uid;
        _activity.insert(0, {
          'action': 'taken_over',
          'uid': widget.backend.auth.currentUser?.uid,
          'name': widget.backend.auth.currentUser?.displayName ?? 'Member',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        _busy = false;
      });
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not take over task: $e')));
      }
    }
  }

  @override
  void dispose() {
    _autoSave();
    _titleFocus.dispose();
    _noteFocus.dispose();
    _destinationFocus.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _destinationController.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD32F2F),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await widget.backend.call('deleteTask', {
        'spaceId': widget.spaceId,
        'taskId': _taskId,
      });
      if (mounted) {
        widget.onChanged();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  Future<void> _claimTask() async {
    setState(() => _busy = true);
    try {
      await widget.backend.call('acceptTask', {
        'spaceId': widget.spaceId,
        'taskId': _taskId,
      });
      if (mounted) {
        widget.onChanged();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not claim: $e')));
      }
    }
  }

  Future<void> _markDone() async {
    Navigator.of(context).pop();
    TaskCompletionPromptSheet.show(
      context,
      backend: widget.backend,
      spaceId: widget.spaceId,
      taskId: _taskId,
      taskTitle: _titleController.text.trim(),
      momentStore: widget.momentStore,
      onCompleted: widget.onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final status = widget.task['status'] as String? ?? 'unclaimed';
    final myUid = widget.backend.auth.currentUser?.uid;
    final isOwner = widget.task['ownerUid'] == myUid;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + media.viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF244BFF),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF596171)),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                readOnly: _completed,
                controller: _titleController,
                focusNode: _titleFocus,
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF202633),
                ),
                decoration: const InputDecoration(
                  hintText: 'Task title',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                readOnly: _completed,
                controller: _noteController,
                focusNode: _noteFocus,
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 15,
                  color: Color(0xFF202633),
                ),
                decoration: InputDecoration(
                  hintText: 'Add notes...',
                  hintStyle: const TextStyle(color: Color(0xFF8E95A5)),
                  filled: true,
                  fillColor: const Color(0xFFFFFEFB),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      readOnly: _completed,
                      controller: _destinationController,
                      focusNode: _destinationFocus,
                      style: const TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 14,
                        color: Color(0xFF202633),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Destination or address...',
                        hintStyle: const TextStyle(color: Color(0xFF8E95A5)),
                        filled: true,
                        fillColor: const Color(0xFFFFFEFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E2DA),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E2DA),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF244BFF),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_destinationController.text.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        ExternalLauncher.openMapDirections(
                          context,
                          query: _destinationController.text.trim(),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF244BFF),
                      ),
                      child: const Text(
                        'Directions',
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFEFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E2DA)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Assigned to',
                      style: TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 14,
                        color: Color(0xFF596171),
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedAssignee,
                        hint: const Text('Unassigned'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Unassigned'),
                          ),
                          if (_selectedAssignee != null &&
                              !widget.members.any(
                                (member) => member['uid'] == _selectedAssignee,
                              ))
                            DropdownMenuItem<String?>(
                              value: _selectedAssignee,
                              child: const Text('Former member'),
                            ),
                          ...widget.members.map((m) {
                            final uid = m['uid'] as String;
                            final name = m['name'] as String? ?? 'Member';
                            return DropdownMenuItem<String?>(
                              value: uid,
                              child: Text(name),
                            );
                          }),
                        ],
                        onChanged: _completed
                            ? null
                            : (val) {
                                setState(() => _selectedAssignee = val);
                                _autoSave();
                              },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Checklist',
                    style: TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202633),
                    ),
                  ),
                  if (_subtasks.isNotEmpty)
                    Text(
                      '${_subtasks.where((s) => s['done'] == true).length}/${_subtasks.length}',
                      style: const TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8E95A5),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_subtasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'No checklist items yet',
                    style: TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 13,
                      color: const Color(0xFF8E95A5).withValues(alpha: 0.8),
                    ),
                  ),
                )
              else
                ..._subtasks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isDone = item['done'] == true;
                  final title = item['title'] as String? ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _completed
                              ? null
                              : () => _toggleSubtask(index),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? const Color(0xFF244BFF)
                                    : const Color(0xFFFFFEFB),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: isDone
                                      ? const Color(0xFF244BFF)
                                      : const Color(0xFFD4D0C8),
                                  width: 1.5,
                                ),
                              ),
                              child: isDone
                                  ? const Icon(
                                      Icons.check,
                                      size: 15,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'NunitoSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDone
                                  ? const Color(0xFF8E95A5)
                                  : const Color(0xFF202633),
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (!_completed)
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Color(0xFF8E95A5),
                            ),
                            tooltip: 'Remove',
                            onPressed: () => _removeSubtask(index),
                          ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 6),
              if (!_completed)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newSubtaskController,
                        style: const TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 14,
                          color: Color(0xFF202633),
                        ),
                        onSubmitted: (_) => _addSubtask(),
                        decoration: InputDecoration(
                          hintText: 'Add an item...',
                          hintStyle: const TextStyle(color: Color(0xFF8E95A5)),
                          filled: true,
                          fillColor: const Color(0xFFFFFEFB),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E2DA),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E2DA),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF244BFF),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: TextButton(
                        onPressed: _addSubtask,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFE8EEFF),
                          foregroundColor: const Color(0xFF244BFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(
                            fontFamily: 'NunitoSans',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              if (_activity.isNotEmpty) ...[
                const Text(
                  'Activity',
                  style: TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF596171),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFEFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E2DA)),
                  ),
                  child: Column(
                    children: _activity.map((act) {
                      final action = act['action'] as String? ?? '';
                      final name = act['name'] as String? ?? 'Member';
                      final text = switch (action) {
                        'help_requested' => '$name asked for help',
                        'taken_over' => '$name took over',
                        'completed' => '$name marked done',
                        _ => '$name updated task',
                      };
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              text,
                              style: const TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF202633),
                              ),
                            ),
                            const Text(
                              'Just now',
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 11,
                                color: Color(0xFF8E95A5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (status != 'completed') ...[
                  if (_helpNeeded && !isOwner) ...[
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _takeOverTask,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFAE33),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Take over task',
                          style: TextStyle(
                            fontFamily: 'NunitoSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF202633),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (!isOwner && !_helpNeeded)
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _claimTask,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF244BFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "I'll do it",
                          style: TextStyle(
                            fontFamily: 'NunitoSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (isOwner) ...[
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _markDone,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF244BFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Mark done',
                          style: TextStyle(
                            fontFamily: 'NunitoSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (!_helpNeeded) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _requestHelp,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD97706),
                            side: const BorderSide(color: Color(0xFFFDE68A)),
                            backgroundColor: const Color(0xFFFEF3C7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Need help',
                            style: TextStyle(
                              fontFamily: 'NunitoSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                ],
                Center(
                  child: TextButton(
                    onPressed: _deleteTask,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFD32F2F),
                    ),
                    child: const Text(
                      'Delete task',
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
          ),
        ),
      ),
    );
  }
}
