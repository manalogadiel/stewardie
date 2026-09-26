---
name: ui-ux-pro-max
description: Pro-level UI/UX design patterns, Flutter component ergonomics, modal/bottom sheet sheet interactions, button states, touch targets, and accessible interaction guidelines.
---

# UI/UX Pro Max Guide for Flutter

You are an expert UI/UX design engineer specializing in high-polish, production-grade Flutter interfaces.

## 1. Ergonomics & Touch Targets
- Minimum interactive touch target: 48x48 logical pixels (`MaterialTapTargetSize.padded`).
- Padding & Gutters: 16-20px horizontal margins on mobile screens.
- Form inputs, buttons, and chips must have distinct visual feedback for default, hover/focus, pressed, disabled, and loading states.
- Never disable a primary button silently without indicating why or providing validation feedback. Prefer keeping buttons enabled and showing actionable field validation on press if requirements are incomplete.

## 2. Modals, Bottom Sheets & Dialogs
- Prefer modal bottom sheets (`showModalBottomSheet`) over centered alert dialogs on mobile for tasks, creation flows, and options.
- Use `isScrollControlled: true` and wrap in `SafeArea` to handle dynamic keyboard height (`viewInsets.bottom`).
- Add a drag handle (`showDragHandle: true`) and clear dismissal affordances (Close icon or Cancel button).
- Keep destructive confirmations explicit with double-confirmation copy ("Delete Space?", "This cannot be undone").

## 3. Visual Hierarchy & Contrast
- Headline: 24-32px bold for screen titles.
- Titles: 18-20px semi-bold for section headers.
- Body: 14-16px regular/medium for readable content.
- Supporting/Caption: 12-13px with adequate contrast ratio (minimum 4.5:1 against surface).
- Avoid low-contrast text on colored pastels. Pastels must carry dark, legible text.

## 4. Integration with Soft Pop Design System
- Honor the approved Soft Pop palette: Canvas (`#FAF9F6`), Surface (`#FFFEFB`), Today/Header (`#F8E7B0`), Primary Electric Blue (`#244BFF`), Ink (`#202633`), Secondary Ink (`#596171`), Character Sky (`#A9CDE8`), Character Butter (`#F5D76E`), Character Rose (`#EAB8C5`).
- Ensure glassmorphism, clay surfaces, and rounded corners (20-28px for cards, 14-16px for buttons, capsule for chips) align with the overarching aesthetic.
