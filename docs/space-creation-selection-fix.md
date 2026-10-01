# Space creation and automatic selection

Implemented October 1, 2026.

- Keep the signed-in app and its dialogs mounted while an additional space's member stream loads. Previously that refresh replaced the provider scope with a loading screen, interrupting create/join UI and resetting selection.
- Do not overwrite a newly requested space with the previous space while membership streams catch up. The controller retains the confirmed selection and handles fallback after an established membership is removed.
- Call the join selection callback once, and guard against a disposed home screen.

Verification: the shell regression test passes with an existing space, delayed new membership, and eventual selection of the new space. Three focused Firestore emulator tests pass, including first-space creation and creation preserving an existing Plus account. Focused Flutter analysis reports no issues. No production data, rules, or cloud services changed.

Physical-device creation/join remains to be checked. Restart the app, create a space below the account quota, and join another authorized space; the selector should change to the resulting space. An approval request does not grant membership until approved and redeemed. Basic's three-space limit remains enforced. If a device still rejects creation, record the exact error to distinguish a live authorization/network failure from the repaired lifecycle bugs.

## Follow-up: Create only reloads

Removed the unnecessary Firebase user reload from Create. The session now reuses its account-scoped onboarding completion future across user/token updates instead of replacing the signed-in app with a loading screen on each update. The completion check resets on sign-out, another UID, or onboarding completion.

The creation dialog now waits for the backend acknowledgement, disables repeated submission while saving, and returns the confirmed space ID. Failures remain in the dialog with the draft intact and a retryable error, rather than closing silently. Two focused widget tests pass for acknowledgement and failed-save retry; physical-device verification is still required.
