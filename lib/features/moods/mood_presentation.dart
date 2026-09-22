import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../timeline/domain/models.dart';

String moodArtName(Mood mood, MoodColor color) {
  if (color == MoodColor.sky) {
    return mood == Mood.calm ? 'mood' : 'mood-${mood.name}';
  }
  return 'mood-${color.name}-${mood.name}';
}

Color moodSurface(MoodColor color) => switch (color) {
  MoodColor.sky => const Color(0xFFF0F6FB),
  MoodColor.butter => const Color(0xFFFFF6DA),
  MoodColor.rose => const Color(0xFFF9EEE9),
};

Color moodSwatch(MoodColor color) => switch (color) {
  MoodColor.sky => SoftPop.sky,
  MoodColor.butter => SoftPop.butter,
  MoodColor.rose => SoftPop.rose,
};
