import 'package:flutter/material.dart';

/// Registry of stable GlobalKeys and lookup methods for tutorial targets across screens.
class TutorialTargetRegistry {
  TutorialTargetRegistry._();

  static final GlobalKey spaceSelectorTarget =
      GlobalKey(debugLabel: 'tutorial_space_selector');
  static final GlobalKey dayTogetherTarget =
      GlobalKey(debugLabel: 'tutorial_day_together');
  static final GlobalKey tasksTarget =
      GlobalKey(debugLabel: 'tutorial_tasks');
  static final GlobalKey momentsTabTarget =
      GlobalKey(debugLabel: 'tutorial_moments_tab');
  static final GlobalKey spaceTabTarget =
      GlobalKey(debugLabel: 'tutorial_space_tab');
  static final GlobalKey mapButtonTarget =
      GlobalKey(debugLabel: 'tutorial_map_button');
  static final GlobalKey notificationBellTarget =
      GlobalKey(debugLabel: 'tutorial_notification_bell');

  static String spacesKey() => 'space_selector';
  static String dayTogetherKey() => 'day_together';
  static String tasksKey() => 'tasks';
  static String momentsTabKey() => 'moments_tab';
  static String spaceTabKey() => 'space_tab';
  static String mapButtonKey() => 'map_button';
  static String notificationBellKey() => 'notification_bell';

  static GlobalKey? keyForId(String id) => switch (id) {
    'space_selector' => spaceSelectorTarget,
    'day_together' => dayTogetherTarget,
    'tasks' => tasksTarget,
    'moments_tab' => momentsTabTarget,
    'space_tab' => spaceTabTarget,
    'map_button' => mapButtonTarget,
    'notification_bell' => notificationBellTarget,
    _ => null,
  };

  /// Calculates the screen bounds (in logical pixels) for a registered key.
  static Rect? getTargetRect(GlobalKey? key) {
    if (key == null) return null;
    final context = key.currentContext;
    if (context == null) return null;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final translation = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      translation.dx,
      translation.dy,
      renderBox.size.width,
      renderBox.size.height,
    );
  }
}
