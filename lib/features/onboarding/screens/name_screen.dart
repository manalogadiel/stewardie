import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../mascot_stage.dart';
import '../staggered_entrance.dart';

/// Screen 2: What should we call you?
/// One name field, Continue.
/// Accepts real names with spaces and Unicode; trims surrounding whitespace.
/// Supports long names gracefully without shrinking essential text.
class NameScreen extends StatefulWidget {
  const NameScreen({
    super.key,
    required this.initialName,
    required this.onContinue,
  });

  final String initialName;
  final ValueChanged<String> onContinue;

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final trimmed = _nameController.text.trim();
    widget.onContinue(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MascotStage(pose: MascotPose.attentive),
                const SizedBox(height: 20),
                const StaggeredEntrance(
                  order: 1,
                  child: Text(
                    'What should we\ncall you?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: SoftPop.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const StaggeredEntrance(
                  order: 2,
                  child: Text(
                    'This is how other members in your spaces will see you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: SoftPop.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                StaggeredEntrance(
                  order: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        focusNode: _focusNode,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        maxLength: 50,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Your name or nickname',
                          hintText: 'e.g. Maya or Sam',
                          counterText: '',
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            color: SoftPop.secondary,
                          ),
                          filled: true,
                          fillColor: SoftPop.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: SoftPop.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: SoftPop.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: SoftPop.blue,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter what you would like to be called';
                          }
                          if (value.trim().length > 50) {
                            return 'Names must be 50 characters or less';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: SoftPop.blue,
                          foregroundColor: SoftPop.surface,
                          minimumSize: const Size(48, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
