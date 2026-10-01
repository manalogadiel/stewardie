# Location session access fix

Implemented and `space-actions` deployed October 1, 2026.

The production map no longer requests each member's private session document. Those requests were predictably denied for missing, expired, or nonrecipient sessions. The existing Firebase-authenticated gateway now queries unexpired sessions, checks current membership before and after the query, and returns only current senders' sessions whose original recipient snapshot includes the viewer. Firestore's private-session rules remain unchanged. Server reads still consume Firestore quota.

Polling runs only while subscribed, cancels its timer when the map closes, drops responses that finish after cancellation, and ends on authentication/access rejection. The Android application opts in to the back-invocation callback to address the platform warning.

Verification: three server privacy tests and two polling cancellation tests passed. Focused Flutter analysis reported no issues. The gateway deployment succeeded. Physical-device map sharing and back gestures still need verification. The native manifest change requires a full restart with `flutter run`, not hot reload.

## October 1 live access investigation

The connected Samsung device reproduced a Moments HTTP 503. After deploying accurate Firestore error handling, the same request reported `RESOURCE_EXHAUSTED` (Firestore quota reached). Supabase photo downloads still require Firestore membership verification, so quota exhaustion prevents live photo access. Do not bypass membership checks or treat a generic HTTP 403 as proof of membership removal.

Both gateways now distinguish quota failures from ordinary access/service errors. Stop commits distinguish a transient write conflict from quota/server failures. The client bounds space-action requests to 30 seconds and prevents concurrent stop-retry loops; GPS collection stops before waiting for the server acknowledgment. Debug diagnostics include the action/status/error, never credentials or photo URLs. Focused analysis passed, and nine location/cache and shared-media tests passed. `media` and `space-actions` were deployed. A debug build was installed on the connected phone and confirmed the live quota response; final client retry changes require another `flutter run`.

Successful live sharing cessation and photo loading remain blocked until Firestore accepts requests again. No billing change, authorization bypass, or data deletion was performed. These fixes cannot restore an exhausted cloud quota.
