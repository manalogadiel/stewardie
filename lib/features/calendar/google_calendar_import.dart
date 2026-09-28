import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../online/online_backend.dart';
import '../timeline/domain/models.dart';

const _scopes = [
  'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
  'https://www.googleapis.com/auth/calendar.events.readonly',
];

class GoogleCalendarEvent {
  const GoogleCalendarEvent({
    required this.calendarId,
    required this.eventId,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.updated,
  });
  final String calendarId, eventId, title, updated;
  final DateTime start, end;
  final bool allDay;

  static GoogleCalendarEvent? decode(
    String calendarId,
    Map<String, dynamic> data,
  ) {
    if (data['status'] == 'cancelled') return null;
    final start = data['start'] as Map?;
    final end = data['end'] as Map?;
    final allDay = start?['date'] != null;
    final begins = DateTime.tryParse(
      start?[allDay ? 'date' : 'dateTime'] as String? ?? '',
    );
    final ends = DateTime.tryParse(
      end?[allDay ? 'date' : 'dateTime'] as String? ?? '',
    );
    final id = data['id'] as String?;
    if (id == null || begins == null || ends == null || !ends.isAfter(begins)) {
      return null;
    }
    return GoogleCalendarEvent(
      calendarId: calendarId,
      eventId: id,
      title: (data['summary'] as String?)?.trim().isNotEmpty == true
          ? (data['summary'] as String).trim()
          : 'Untitled Google event',
      start: allDay ? begins : begins.toUtc(),
      end: allDay ? ends : ends.toUtc(),
      allDay: allDay,
      updated: data['updated'] as String? ?? '',
    );
  }

  String get planId {
    // Two independent 32-bit hashes keep Firestore IDs short and stable.
    final key = '$calendarId/$eventId';
    var a = 0x811c9dc5, b = 0x9e3779b9;
    for (final byte in utf8.encode(key)) {
      a = ((a ^ byte) * 0x01000193) & 0xffffffff;
      b = ((b + byte) * 0x85ebca6b) & 0xffffffff;
    }
    return 'gcal_${a.toRadixString(16).padLeft(8, '0')}${b.toRadixString(16).padLeft(8, '0')}';
  }
}

/// Google tokens stay on device. Only member-selected event copies reach Firestore.
class GoogleCalendarImport {
  GoogleCalendarImport._();
  static final instance = GoogleCalendarImport._();
  final _signIn = GoogleSignIn.instance;
  Future<void>? _initialization;
  GoogleSignInAccount? _account;
  DateTime? lastRefreshed;

  Future<void> _init() => _initialization ??= _signIn.initialize(
    clientId: const String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID').isEmpty
        ? null
        : const String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID'),
    serverClientId:
        const String.fromEnvironment('GOOGLE_OAUTH_SERVER_CLIENT_ID').isEmpty
        ? null
        : const String.fromEnvironment('GOOGLE_OAUTH_SERVER_CLIENT_ID'),
  );

  Future<bool> restore() async {
    await _init();
    try {
      _account ??= await _signIn.attemptLightweightAuthentication();
      return _account != null &&
          await _account!.authorizationClient.authorizationForScopes(_scopes) !=
              null;
    } catch (_) {
      return false;
    }
  }

  Future<void> connect() async {
    await _init();
    if (_account == null) {
      if (!_signIn.supportsAuthenticate()) {
        throw StateError(
          'Google Calendar connection is available on Android and iOS.',
        );
      }
      _account = await _signIn.authenticate();
    }
    await _account!.authorizationClient.authorizeScopes(_scopes);
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final account = _account;
    if (account == null) throw StateError('Connect Google Calendar first.');
    final headers = await account.authorizationClient.authorizationHeaders(
      _scopes,
    );
    if (headers == null) {
      throw StateError('Reconnect Google Calendar to refresh.');
    }
    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('Google Calendar access expired. Reconnect to refresh.');
    }
    if (response.statusCode == 404) {
      throw StateError('Google event was removed.');
    }
    if (response.statusCode != 200) {
      throw StateError('Could not load Google Calendar. Try again.');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<GoogleCalendarEvent>> preview() async {
    final calendars = await _get(
      Uri.parse(
        'https://www.googleapis.com/calendar/v3/users/me/calendarList?maxResults=100',
      ),
    );
    final start = DateTime.now().toUtc().subtract(const Duration(days: 7));
    final end = start.add(const Duration(days: 70));
    final events = <GoogleCalendarEvent>[];
    for (final raw in (calendars['items'] as List? ?? const [])) {
      final calendar = Map<String, dynamic>.from(raw as Map);
      final id = calendar['id'] as String?;
      if (id == null) continue;
      final uri =
          Uri.parse(
            'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(id)}/events',
          ).replace(
            queryParameters: {
              'timeMin': start.toIso8601String(),
              'timeMax': end.toIso8601String(),
              'singleEvents': 'true',
              'showDeleted': 'false',
              'maxResults': '250',
            },
          );
      try {
        final page = await _get(uri);
        for (final item in (page['items'] as List? ?? const [])) {
          final event = GoogleCalendarEvent.decode(
            id,
            Map<String, dynamic>.from(item as Map),
          );
          if (event != null) events.add(event);
        }
      } catch (_) {
        // An inaccessible calendar does not hide the other calendars.
      }
    }
    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  Future<void> share(
    OnlineBackend backend,
    String spaceId,
    GoogleCalendarEvent event,
  ) async {
    int millis(DateTime date) =>
        (event.allDay
                ? DateTime.utc(date.year, date.month, date.day)
                : date.toUtc())
            .millisecondsSinceEpoch;
    await backend.call('savePlan', {
      'spaceId': spaceId,
      'planId': event.planId,
      'title': event.title.length > 100
          ? event.title.substring(0, 100)
          : event.title,
      'note': 'Imported from Google Calendar',
      'allDay': event.allDay,
      'startMillis': millis(event.start),
      'endMillis': millis(event.end),
      'participants': <String>[],
      'source': 'google',
      'sourceCalendarId': event.calendarId,
      'sourceEventId': event.eventId,
      'sourceUpdatedAt': event.updated,
    });
  }

  Future<void> refreshSpace(OnlineBackend backend, String spaceId) async {
    if (!await restore()) return;
    final plans = await backend.firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('plans')
        .get();
    final mine = plans.docs.where(
      (doc) =>
          doc.data()['ownerUid'] == backend.auth.currentUser?.uid &&
          doc.data()['source'] == 'google',
    );
    for (final doc in mine) {
      final data = doc.data();
      final calendarId = data['sourceCalendarId'] as String?;
      final eventId = data['sourceEventId'] as String?;
      if (calendarId == null || eventId == null) continue;
      try {
        final event = GoogleCalendarEvent.decode(
          calendarId,
          await _get(
            Uri.parse(
              'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events/${Uri.encodeComponent(eventId)}',
            ),
          ),
        );
        if (event == null) {
          await backend.call('removePlan', {
            'spaceId': spaceId,
            'planId': doc.id,
          });
        } else if (event.updated != data['sourceUpdatedAt']) {
          await share(backend, spaceId, event);
        }
      } on StateError catch (error) {
        if (error.message == 'Google event was removed.') {
          await backend.call('removePlan', {
            'spaceId': spaceId,
            'planId': doc.id,
          });
        } else {
          rethrow;
        }
      }
    }
    lastRefreshed = DateTime.now();
  }

  Future<void> disconnect(
    OnlineBackend backend,
    Iterable<String> spaces,
  ) async {
    for (final space in spaces) {
      final plans = await backend.firestore
          .collection('spaces')
          .doc(space)
          .collection('plans')
          .get();
      for (final doc in plans.docs.where(
        (d) =>
            d.data()['ownerUid'] == backend.auth.currentUser?.uid &&
            d.data()['source'] == 'google',
      )) {
        await backend.call('removePlan', {'spaceId': space, 'planId': doc.id});
      }
    }
    await _signIn.disconnect();
    _account = null;
    lastRefreshed = null;
  }
}

Future<void> showGoogleCalendarImport(
  BuildContext context,
  OnlineBackend backend,
  Space space,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => _GoogleImportSheet(backend: backend, space: space),
);

class _GoogleImportSheet extends StatefulWidget {
  const _GoogleImportSheet({required this.backend, required this.space});
  final OnlineBackend backend;
  final Space space;
  @override
  State<_GoogleImportSheet> createState() => _GoogleImportSheetState();
}

class _GoogleImportSheetState extends State<_GoogleImportSheet> {
  List<GoogleCalendarEvent> events = [];
  final selected = <String>{};
  bool busy = false;
  bool connected = false;
  String? error;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      connected = await GoogleCalendarImport.instance.restore();
      if (!connected) return;
      events = await GoogleCalendarImport.instance.preview();
    } catch (e) {
      error = e is StateError ? e.message : 'Could not load calendars.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .8,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose Google events',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Only selected events will be copied into ${widget.space.name}.',
          ),
          const SizedBox(height: 12),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await GoogleCalendarImport.instance.connect();
                      if (mounted) await load();
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => error = 'Could not connect Google Calendar. Check the OAuth app setup.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            icon: const Icon(Icons.link_rounded),
            label: const Text('Connect Google Calendar'),
          ),
          if (connected)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final remove = await showDialog<bool>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          title: const Text('Disconnect Google Calendar?'),
                          content: const Text(
                            'Remove all Google events you shared to Stewardie spaces?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dialog, true),
                              child: const Text('Disconnect and remove'),
                            ),
                          ],
                        ),
                      );
                      if (remove != true || !mounted) return;
                      setState(() => busy = true);
                      try {
                        final uid = widget.backend.auth.currentUser!.uid;
                        final account = await widget.backend.firestore
                            .doc('accounts/$uid')
                            .get();
                        final spaces = List<String>.from(
                          account.data()?['spaceIds'] as List? ?? [],
                        );
                        await GoogleCalendarImport.instance.disconnect(
                          widget.backend,
                          spaces,
                        );
                        if (mounted) {
                          setState(() {
                            connected = false;
                            events = [];
                            selected.clear();
                          });
                        }
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => error = 'Could not disconnect. Try again.',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: const Text('Disconnect Google Calendar'),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return CheckboxListTile(
                  value: selected.contains(event.planId),
                  title: Text(event.title),
                  subtitle: Text(
                    event.allDay
                        ? event.start.toIso8601String().substring(0, 10)
                        : event.start.toLocal().toString(),
                  ),
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            selected.add(event.planId);
                          } else {
                            selected.remove(event.planId);
                          }
                        }),
                );
              },
            ),
          ),
          FilledButton(
            onPressed: busy || selected.isEmpty
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      for (final event in events.where(
                        (e) => selected.contains(e.planId),
                      )) {
                        await GoogleCalendarImport.instance.share(
                          widget.backend,
                          widget.space.id,
                          event,
                        );
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(
                          () => error = e is StateError
                              ? e.message
                              : 'Could not share selected events.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text('Share ${selected.length} selected'),
          ),
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}
