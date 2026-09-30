# Task and place field spacing — October 1, 2026

Fixed the two overlaps shown in the owner's screenshots:

- Task creation now leaves 24 logical pixels before the recipient field. Validation messages wrap up to three lines instead of truncating beside the character counter or crowding the next floating label.
- The place picker now leaves 24 logical pixels between Selected place and Location note, keeping the floating label clear of the preceding outline.

Fresh verification: four widget tests in `test/form_spacing_test.dart` passed at a 360-pixel width with normal and doubled text. Checks measure separation between task validation and the next label, and between the location fields. No framework layout exceptions were observed. Widget tests simulate failed map tile requests; these checks do not verify the live map provider. `git diff --check` passed.

This is a focused repair of the reported forms, not a claim that every application screen has been checked for overlap.
