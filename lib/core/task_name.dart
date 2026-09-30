String? taskNameError(String? value) {
  final title = value?.trim() ?? '';
  if (title.isEmpty) return 'Give your task a name.';
  if (title.length > 120) return 'Keep the task name within 120 characters.';
  if (RegExp(r'(\S)\1{5,}', caseSensitive: false).hasMatch(title)) {
    return 'Use a clear name without repeated-key spam.';
  }
  return null;
}

String checkedTaskName(String value) {
  final error = taskNameError(value);
  if (error != null) throw ArgumentError(error);
  return value.trim();
}
