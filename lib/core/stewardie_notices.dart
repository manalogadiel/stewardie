import 'package:flutter/material.dart';

import 'theme.dart';

/// Product notices describe the current pilot; no network or account is needed.
Future<void> showStewardieNotice(BuildContext context, {bool privacy = true}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: SoftPop.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: .85,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  privacy ? 'Privacy Notice' : 'Community Guidelines',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: (privacy ? _privacy : _guidelines)
                        .map(
                          (section) => Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  section.$1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: SoftPop.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  section.$2,
                                  style: const TextStyle(
                                    color: SoftPop.secondary,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

const _privacy = <(String, String)>[
  (
    'Your account',
    'Stewardie uses your email, account ID, display name and optional profile photo to identify you and connect your spaces. Email and password sign-in is handled by Firebase Authentication.',
  ),
  (
    'What your space can see',
    'Tasks, calendar entries, mood check-ins, photos and attached photo locations are shared with people who have access to that space. Only add content you are comfortable sharing with them.',
  ),
  (
    'Camera and location',
    'Camera and location permissions are optional. Opening a map can obtain your position privately; live sharing starts only when you choose to share. It stops when you end it or its timer expires. A location attached to a photo stays with that photo until the photo is removed.',
  ),
  (
    'Notifications and subscriptions',
    'Device push tokens and reminder preferences are used to deliver updates. You can change notification settings in the app or device Settings. RevenueCat handles subscription information and purchase verification for your account.',
  ),
  (
    'Services used by Stewardie',
    'Firebase stores account and shared-space records and delivers push notifications. Supabase stores shared photos and supports cloud processing. MapTiler receives map tile and place lookup requests when you use maps. These services process the information needed to provide those features.',
  ),
  (
    'Your choices and retained content',
    'You can edit your profile, remove photos when permitted, leave spaces, stop location sharing or request account deletion in account settings. Account deletion may require cloud processing or review; it is not an instant erase of every shared record or provider backup. Basic history limits hide older completed tasks rather than deleting them.',
  ),
  (
    'Notice updated October 1, 2026',
    'This notice describes the current Stewardie pilot. Review it again when the app or its connected services change.',
  ),
];

const _guidelines = <(String, String)>[
  (
    'Be kind',
    'Use Stewardie respectfully. Do not harass, threaten or target other members.',
  ),
  (
    'Share with permission',
    'Only upload photos and information you have permission to share. Respect other people’s privacy and location choices.',
  ),
  (
    'Keep access safe',
    'Share invite codes only with people you want in your space. Do not misuse someone else’s account or try to bypass space permissions.',
  ),
  (
    'Raise concerns',
    'Use the available report or block controls for harmful content or unwanted contact. Space owners can manage membership.',
  ),
];
