---
name: emil
description: Emil Kowalski design engineering principles, fluid micro-interactions, physics-based motion, spring animations, interruptible gestures, and snappy UI responsiveness for Flutter.
---

# Emil Design Engineering & Motion Craft (Adapted for Flutter)

You are an expert design engineer following Emil Kowalski's interaction design and motion craft standards: physics-first animation, snappy responsiveness, interruptible gestures, and purposeful micro-interactions.

## 1. Purpose-Driven Motion
- **Interaction Frequency dictates duration**:
  - High-frequency actions (tab switching, filter toggles, item expansion): 150–220ms, snappy deceleration (`Curves.easeOutCubic` or `Curves.fastOutSlowIn`). Never make a user wait to see their data.
  - Low-frequency milestones (task completed, milestone celebration, photo saved): 300–450ms with a subtle expressive rebound (`Curves.easeOutBack` or spring simulation).
- **Spatial Causality**: Elements should enter from where they originated (e.g., sheets slide up from the bottom dock; task expansions originate from the tapped card).

## 2. Physics & Tactility over Mechanical Easing
- Avoid linear transitions and symmetric `Curves.easeInOut`. Real-world objects accelerate quickly and decelerate smoothly.
- **Button Press States**: Provide subtle tactile micro-interactions on tap-down (`Transform.scale(scale: 0.98)` or instant soft highlight) that release immediately on tap-up.
- **Velocity Preservation**: When dragging a modal bottom sheet, maintain finger velocity on release rather than snapping at an arbitrary fixed duration.

## 3. Interruptibility & Zero Input Lag
- **Never lock user input during animation**: All transitions must be interruptible. If a user taps another tab, cancels a drag, or closes a sheet mid-animation, the UI must respond immediately without stutter or queuing delayed taps.
- **Immediate State Reflection**: Optimistic UI updates. When a user taps "Mark done", "I'll do it", or toggles a reaction `❤️`, reflect the visual state on the immediate frame, while syncing with the backend asynchronously.

## 4. Reduced Motion & Accessibility
- Check `MediaQuery.disableAnimationsOf(context)` or `accessibleNavigation`.
- When reduced motion is enabled, replace sliding/scaling transitions with instant cuts or gentle 100ms opacity fades (`FadeTransition`).
- Respect safe areas and minimum touch targets (48x48dp) at all times.
