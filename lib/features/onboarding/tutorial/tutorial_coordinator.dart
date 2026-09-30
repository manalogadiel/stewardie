import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import 'tutorial_invitation.dart';
import 'tutorial_overlay.dart';
import 'tutorial_state.dart';

/// Coordinates the guided tour lifecycle, invitation prompt, persistence, and overlay.
///
/// Rules:
/// - Offer only once after first successful onboarding setup for the Firebase UID.
/// - Persist state before or during display so a remount cannot duplicate it.
/// - In-memory debouncing prevents duplicate prompts within the running session.
/// - Returning users, opening Space, or tab revisits must never auto-prompt.
/// - Manual replay from Space settings works without resetting first-use completion.
class TutorialCoordinator {
  TutorialCoordinator(this.database) : _store = TutorialStore(database);

  final Database? database;
  final TutorialStore _store;

  /// In-memory tracker for UIDs that have been prompted during this app session.
  static final Set<String> _promptedUids = <String>{};
  static final Set<String> _continuingUids = <String>{};
  static final Map<String, Future<void> Function(TutorialStatus?)>
  _activeTours = {};

  /// Account departure closes its overlay without recording a false completion.
  static Future<void> cancelForAccount(String uid) async {
    await _activeTours[uid]?.call(null);
  }

  /// In-memory tracker for UIDs that just finished fresh onboarding and are
  /// eligible for the one-time first-use tour offer.
  static final Set<String> _eligibleFirstUseUids = <String>{};

  /// Marks a newly verified user as eligible for the first-use tour prompt upon entering the app.
  static void markEligibleForFirstUsePrompt(String uid) {
    if (uid.isNotEmpty) {
      _eligibleFirstUseUids.add(uid);
    }
  }

  /// Checks if a UID is marked eligible for first-use prompt.
  static bool isEligibleForFirstUsePrompt(String uid) =>
      _eligibleFirstUseUids.contains(uid);

  /// Clears in-memory session eligibility (e.g. for testing or logout).
  static void resetSessionState() {
    for (final close in _activeTours.values.toList()) {
      unawaited(close(null));
    }
    _promptedUids.clear();
    _continuingUids.clear();
    _eligibleFirstUseUids.clear();
  }

  /// Checks if the tour should be offered, and if so, shows the compact invitation.
  /// Gated strictly by:
  /// 1. UID must have just finished first-time onboarding (_eligibleFirstUseUids)
  /// 2. UID must not have been prompted in this session (_promptedUids)
  /// 3. Persistent store must be available and status == notStarted
  Future<void> checkAndPromptTour(
    BuildContext context, {
    required String uid,
    ValueChanged<int>? onTabRequested,
    bool hasSpaces = true,
  }) async {
    if (uid.isEmpty) return;
    if (database == null) {
      return; // Avoid repeating if local storage is unavailable
    }

    // Must be newly finished onboarding in this session
    if (!_eligibleFirstUseUids.contains(uid)) return;

    // Must not have already been prompted in this session
    if (_promptedUids.contains(uid)) return;

    final status = await _store.getStatus(uid);
    if (status != TutorialStatus.notStarted) {
      _eligibleFirstUseUids.remove(uid);
      return;
    }

    // Persist and debounce before/during display so remounts cannot duplicate
    _promptedUids.add(uid);
    _eligibleFirstUseUids.remove(uid);
    await _store.setStatus(uid, TutorialStatus.inProgress);

    if (!context.mounted) return;

    final accepted = await TutorialInvitationSheet.show(context);
    if (!context.mounted) return;

    if (accepted == true) {
      await startTour(
        context,
        uid: uid,
        initialStop: 0,
        onTabRequested: onTabRequested,
        hasSpaces: hasSpaces,
      );
    } else {
      await _store.setStatus(uid, TutorialStatus.skipped);
    }
  }

  /// Launches the interactive guided tour overlay.
  Future<void> startTour(
    BuildContext context, {
    required String uid,
    int initialStop = 0,
    ValueChanged<int>? onTabRequested,
    bool isReplay = false,
    bool hasSpaces = true,
  }) async {
    if (uid.isNotEmpty && _activeTours.containsKey(uid)) return;
    final overlay = Overlay.of(context);
    final closed = Completer<void>();
    late OverlayEntry entry;
    bool closing = false;

    Future<void> close(TutorialStatus? status) async {
      if (closing) return;
      closing = true;
      _activeTours.remove(uid);
      if (entry.mounted) {
        entry.remove();
      }
      entry.dispose();
      try {
        if (uid.isNotEmpty && !isReplay && status != null) {
          await _store.setStatus(uid, status);
        }
      } finally {
        if (!closed.isCompleted) closed.complete();
      }
    }

    entry = OverlayEntry(
      builder: (ctx) => TutorialOverlay(
        initialStopIndex: initialStop,
        stops: hasSpaces ? TutorialStops.all : [TutorialStops.all.first],
        finishLabel: hasSpaces ? 'Got it' : 'Create or join',
        onTabRequested: onTabRequested,
        onFinished: () => close(
          hasSpaces ? TutorialStatus.completed : TutorialStatus.awaitingSpace,
        ),
        onSkipped: () => close(TutorialStatus.skipped),
      ),
    );

    overlay.insert(entry);
    if (uid.isNotEmpty) _activeTours[uid] = close;
    await closed.future;
  }

  /// Replays the tour from settings / help menu without modifying account or first-use state.
  Future<void> replayTour(
    BuildContext context, {
    required String uid,
    ValueChanged<int>? onTabRequested,
    bool hasSpaces = true,
  }) async {
    await startTour(
      context,
      uid: uid,
      initialStop: 0,
      onTabRequested: onTabRequested,
      isReplay: true,
      hasSpaces: hasSpaces,
    );
  }

  /// Explicit continuation after the first membership, never an automatic tour.
  Future<void> continueTour(
    BuildContext context, {
    required String uid,
    ValueChanged<int>? onTabRequested,
  }) async {
    if (!_continuingUids.add(uid)) return;
    try {
      if (await _store.getStatus(uid) != TutorialStatus.awaitingSpace ||
          !context.mounted)
        return;
      await _store.setStatus(uid, TutorialStatus.inProgress);
      if (!context.mounted) return;
      await startTour(
        context,
        uid: uid,
        initialStop: 1,
        onTabRequested: onTabRequested,
      );
    } finally {
      _continuingUids.remove(uid);
    }
  }

  /// Clears local tutorial state for the given user (e.g. on account deletion).
  Future<void> clear(String uid) async {
    _promptedUids.remove(uid);
    _eligibleFirstUseUids.remove(uid);
    await _store.clear(uid);
  }
}
