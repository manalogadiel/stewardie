import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../core/stewardie_map.dart';
import '../core/location_settings.dart';
import 'member_location_pin.dart';
import 'external_launcher.dart';
import 'live_location_service.dart';
import 'online_backend.dart';

/// A private map view; opening it does not start live sharing.
class SpaceMapSheet extends StatefulWidget {
  const SpaceMapSheet({
    super.key,
    required this.backend,

    /// When null the map opens in private mode: tiles, location, recenter, and
    /// satellite/streets toggle work, but session subscription, other members,
    /// and sharing are all disabled.
    this.spaceId,
    this.onJoinSpace,
  });

  final OnlineBackend backend;
  final String? spaceId;

  /// Called when the user taps the Create/Join prompt in private-map mode.
  final VoidCallback? onJoinSpace;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    String? spaceId,
    VoidCallback? onJoinSpace,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F6),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SpaceMapSheet(
        backend: backend,
        spaceId: spaceId,
        onJoinSpace: onJoinSpace,
      ),
    );
  }

  @override
  State<SpaceMapSheet> createState() => _SpaceMapSheetState();
}

class _SpaceMapSheetState extends State<SpaceMapSheet>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  late final Stream<List<Map<String, dynamic>>> _sessions =
      widget.spaceId == null
      ? const Stream.empty()
      : widget.backend.locationSessions(widget.spaceId!);
  int _selectionRevision = 0;
  int _locationRevision = 0;
  int _selectedDuration = 15; // 15, 30, 60
  Map<String, dynamic>? _selectedMember;
  StewardieMapStyle _style = mapTilerKey.isEmpty
      ? StewardieMapStyle.streets
      : StewardieMapStyle.hybrid;
  LatLng _lastKnownCenter = const LatLng(12, 122);
  LatLng? _currentUserLatLng;
  bool _mapReady = false;
  bool _allowAutoCenter = true;
  bool _freshResolved = false;
  String _locationStatus = 'Finding your location…';
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cached = LiveLocationService.instance.currentPosition.value;
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) <
            const Duration(minutes: 10)) {
      final pos = LatLng(cached.latitude, cached.longitude);
      _lastKnownCenter = pos;
      _currentUserLatLng = pos;
      _locationStatus = 'Your last device location · refreshing…';
    }
    LiveLocationService.instance.currentPosition.addListener(
      _onPositionChanged,
    );
    _showCachedPosition();
    _initUserLocation();
  }

  Future<void> _showCachedPosition() async {
    try {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached == null ||
          !mounted ||
          _freshResolved ||
          DateTime.now().difference(cached.timestamp) >
              const Duration(minutes: 10)) {
        return;
      }
      final point = LatLng(cached.latitude, cached.longitude);
      setState(() {
        _currentUserLatLng = point;
        _lastKnownCenter = point;
        _locationStatus = 'Your last device location · refreshing…';
      });
      LiveLocationService.instance.currentPosition.value = cached;
      if (_allowAutoCenter && _mapReady) {
        _mapController.move(point, 16);
      }
    } catch (_) {
      /* A cached fix is optional. */
    }
  }

  void _onPositionChanged() {
    final pos = LiveLocationService.instance.currentPosition.value;
    if (pos != null && mounted) {
      _freshResolved =
          DateTime.now().difference(pos.timestamp).inSeconds.abs() < 30;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentUserLatLng = latLng;
        _lastKnownCenter = latLng;
        _locationStatus = _freshResolved
            ? 'Your private device location'
            : 'Your last device location · refreshing…';
      });
      if (_allowAutoCenter && _mapReady) {
        _mapController.move(latLng, 16);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _initUserLocation();
  }

  @override
  void dispose() {
    _locationRevision++;
    WidgetsBinding.instance.removeObserver(this);
    LiveLocationService.instance.currentPosition.removeListener(
      _onPositionChanged,
    );
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initUserLocation() async {
    final revision = ++_locationRevision;
    bool current() => mounted && revision == _locationRevision;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!current()) return;
      if (!enabled) {
        setState(
          () => _locationStatus =
              'Location services are off. $locationSettingsHint',
        );
        return;
      }
      final pos = await LiveLocationService.instance.determinePosition();
      if (!current()) return;
      if (pos != null) {
        final point = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _freshResolved = true;
          _lastKnownCenter = point;
          _currentUserLatLng = point;
          _locationStatus = 'Your private device location';
        });
        if (_allowAutoCenter && _mapReady) _mapController.move(point, 16);
      } else {
        final permission = await Geolocator.checkPermission();
        if (!current()) return;
        setState(
          () => _locationStatus = switch (permission) {
            LocationPermission.denied => 'Location permission denied. Tap Enable location to allow access.',
            LocationPermission.deniedForever => 'Location permission is blocked. Enable access in device settings.',
            _ =>
              _currentUserLatLng == null
                  ? 'Location timed out or is unavailable. Try Recenter.'
                  : 'Showing your last device location · refresh timed out. Try Recenter.',
          },
        );
      }
    } catch (_) {
      if (current()) {
        setState(
          () => _locationStatus =
              'Could not check your location. Check device settings and retry.',
        );
      }
    }
  }

  Future<void> _recenterOnUser() async {
    _allowAutoCenter = true;
    if (_currentUserLatLng != null && _mapReady) {
      _mapController.move(_currentUserLatLng!, 16);
    }
    await _initUserLocation();
  }

  Future<void> _recoverLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await openDeviceLocationSettings();
        if (mounted) setState(() => _locationStatus = locationSettingsHint);
        // The foreground observer obtains a new private fix on return.
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.deniedForever) {
        final opened = await Geolocator.openAppSettings();
        if (!mounted) return;
        if (!opened) {
          setState(
            () => _locationStatus = 'Open device Settings and allow Stewardie to use your location.',
          );
          return;
        }
      } else if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      if (mounted) await _initUserLocation();
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationStatus = 'Could not open location settings. Check device settings and retry.',
        );
      }
    }
  }

  bool _requestingLocation = false;
  Future<void> _requestLocation() async {
    final sid = widget.spaceId;
    if (sid == null || _requestingLocation) return;
    setState(() => _requestingLocation = true);
    try {
      final members = await widget.backend.firestore
          .collection('spaces/$sid/members')
          .get();
      if (!mounted) return;
      final others = members.docs
          .where((m) => m.id != widget.backend.auth.currentUser?.uid)
          .toList();
      final target = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Request a location'),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'They decide whether to share. Requests expire after 15 minutes.',
                  ),
                  const SizedBox(height: 12),
                  if (others.isEmpty)
                    const Text('Invite someone to this space first.'),
                  for (final member in others)
                    ListTile(
                      leading: const Icon(Icons.location_on_rounded),
                      title: Text(member.data()['name'] as String? ?? 'Member'),
                      onTap: () => Navigator.pop(dialog, member.id),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (target == null) return;
      await widget.backend.call('requestLocation', {
        'spaceId': sid,
        'targetUid': target,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Location request sent.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _requestingLocation = false);
    }
  }

  Future<void> _startSharing() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final space = await widget.backend.firestore
          .doc('spaces/${widget.spaceId}')
          .get(const GetOptions(source: Source.server));
      final ids = List<String>.from(space.data()?['memberUids'] as List? ?? []);
      final me = widget.backend.auth.currentUser?.uid;
      if (me == null || !ids.contains(me)) {
        throw StateError('You are no longer in this space.');
      }
      final members = await widget.backend.firestore
          .collection('spaces/${widget.spaceId}/members')
          .get(const GetOptions(source: Source.server));
      final names = {
        for (final doc in members.docs)
          doc.id: doc.data()['name'] as String? ?? 'Member',
      };
      final recipientNames = ids
          .where((id) => id != me)
          .map((id) => names[id] ?? 'Member')
          .join(', ');
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('Share for $_selectedDuration minutes?'),
          content: Text(
            '${LiveLocationService.instance.isSharing.value && LiveLocationService.instance.activeSpaceId != widget.spaceId ? 'This will end sharing in ${LiveLocationService.instance.activeSpaceName}. ' : ''}'
            'Your latest location will be visible in ${space.data()?['name'] ?? 'this space'} to: '
            '${recipientNames.isEmpty ? 'no other members yet' : recipientNames}. '
            'You can stop at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Share location'),
            ),
          ],
        ),
      );
      if (approved != true) return;
      await LiveLocationService.instance.startSharing(
        spaceId: widget.spaceId!,
        durationMinutes: _selectedDuration,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError ? error.message : 'Could not start sharing. Check location permission and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final locationService = LiveLocationService.instance;

    return SafeArea(
      top: false,
      child: SizedBox(
        height:
            media.size.height * .9 - media.padding.top - media.padding.bottom,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + media.viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Space map',
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202633),
                        ),
                      ),
                    ),
                    Image.asset(
                      'assets/illustrations/mascot-map-explorer.png',
                      width: 52,
                      height: 60,
                      cacheWidth: 156,
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF596171),
                          ),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _locationStatus,
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 14,
                    color: Color(0xFF596171),
                  ),
                ),
                if (_locationStatus != 'Your private device location')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: _recoverLocation,
                        icon: const Icon(Icons.location_on_outlined),
                        label: const Text('Enable location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF202633),
                          surfaceTintColor: Colors.transparent,
                          shadowColor: const Color(0x26202633),
                          elevation: 2,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _sessions,
                  builder: (context, snapshot) {
                    final sessions = snapshot.hasError
                        ? const <Map<String, dynamic>>[]
                        : snapshot.data ?? const <Map<String, dynamic>>[];

                    final myUid = widget.backend.auth.currentUser?.uid;
                    final myUser = widget.backend.auth.currentUser;
                    final myRawName = myUser?.displayName?.isNotEmpty == true
                        ? myUser!.displayName!
                        : (myUser?.email?.split('@').first ?? 'You');

                    if (_selectedMember != null &&
                        (snapshot.hasData ||
                            snapshot.hasError ||
                            _selectedMember!['uid'] == myUid)) {
                      final selectedUid = _selectedMember!['uid'] as String?;
                      final personal = _currentUserLatLng;
                      final latest = resolveSelectedMemberLocation(
                        selectedUid: selectedUid,
                        currentUid: myUid,
                        sessions: sessions,
                        personalLocation: personal == null
                            ? null
                            : _personalLocation(myUid, myRawName, personal),
                      );
                      if (!mapEquals(_selectedMember, latest)) {
                        final revision = ++_selectionRevision;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted &&
                              revision == _selectionRevision &&
                              _selectedMember?['uid'] == selectedUid) {
                            setState(() => _selectedMember = latest);
                          }
                        });
                      }
                    }

                    final markers = <Marker>[];
                    final allLocations = List<Map<String, dynamic>>.of(
                      sessions,
                    );
                    final userPoint = _currentUserLatLng;
                    if (userPoint != null &&
                        !sessions.any((s) => s['uid'] == myUid)) {
                      allLocations.add(
                        _personalLocation(myUid, myRawName, userPoint),
                      );
                    }
                    for (final group in groupMemberLocations(allLocations)) {
                      final first = group.first;
                      final grouped = group.length > 1;
                      final columns = group.length.clamp(1, 3);
                      final rows = (group.length / 3).ceil();
                      markers.add(
                        Marker(
                          point: LatLng(
                            (first['lat'] as num).toDouble(),
                            (first['lng'] as num).toDouble(),
                          ),
                          // The pointer, rather than the avatar center, marks the fix.
                          alignment: Alignment.topCenter,
                          width: grouped ? columns * 70.0 + 16 : 96,
                          height: grouped
                              ? rows *
                                        (48 +
                                            MediaQuery.textScalerOf(context)
                                                    .scale(11) *
                                                1.2) +
                                    15
                              : MemberLocationPin.sizeFor(context).height,
                          child: grouped
                              ? GroupMemberLocationPin(
                                  members: group,
                                  currentUid: myUid,
                                  selectedUid:
                                      _selectedMember?['uid'] as String?,
                                  onSelected: (s) =>
                                      setState(() => _selectedMember = s),
                                )
                              : GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedMember = first),
                                  child: _buildPin(
                                    uid: first['uid'] as String? ?? '',
                                    name: first['uid'] == myUid
                                        ? myRawName
                                        : first['name'] as String? ?? 'Member',
                                    label: first['uid'] == myUid
                                        ? 'You'
                                        : first['name'] as String? ?? 'Member',
                                    isSelected:
                                        _selectedMember?['uid'] == first['uid'],
                                    isMe: first['uid'] == myUid,
                                  ),
                                ),
                        ),
                      );
                    }

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        height: media.size.height * .52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E5DF),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFE5E2DA),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          children: [
                            StewardieMap(
                              controller: _mapController,
                              center: _lastKnownCenter,
                              zoom: _currentUserLatLng == null ? 5 : 16,
                              markers: markers,
                              style: _style,
                              onStyleChanged: (value) =>
                                  setState(() => _style = value),
                              onUserInteraction: () => _allowAutoCenter = false,
                              onReady: () {
                                _mapReady = true;
                                if (_allowAutoCenter &&
                                    _currentUserLatLng != null) {
                                  _mapController.move(_currentUserLatLng!, 16);
                                }
                              },
                            ),
                            // Recenter button
                            Positioned(
                              bottom: 44,
                              right: 12,
                              child: Material(
                                color: const Color(0xFFFFFEFB),
                                shape: const CircleBorder(),
                                elevation: 3,
                                child: IconButton(
                                  onPressed: _recenterOnUser,
                                  tooltip: 'Recenter on me',
                                  constraints: const BoxConstraints.tightFor(
                                    width: 48,
                                    height: 48,
                                  ),
                                  icon: const Icon(
                                    Icons.my_location_rounded,
                                    color: Color(0xFF244BFF),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_selectedMember != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFEFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E2DA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedMember!['name'] as String? ?? 'Member',
                              style: const TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF202633),
                              ),
                            ),
                            Text(
                              _memberLocationStatus(_selectedMember!),
                              style: const TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 12,
                                color: Color(0xFF596171),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            final lat = (_selectedMember!['lat'] as num?)
                                ?.toDouble();
                            final lng = (_selectedMember!['lng'] as num?)
                                ?.toDouble();
                            ExternalLauncher.openMapDirections(
                              context,
                              query: 'Member location',
                              lat: lat,
                              lng: lng,
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF244BFF),
                          ),
                          child: const Text(
                            'Directions',
                            style: TextStyle(
                              fontFamily: 'NunitoSans',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.spaceId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ElevatedButton.icon(
                      onPressed: _requestingLocation ? null : _requestLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF1C7),
                        foregroundColor: const Color(0xFF202633),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.person_pin_circle_rounded),
                      label: Text(
                        _requestingLocation
                            ? 'Sending request…'
                            : 'Request a location',
                      ),
                    ),
                  ),
                // -- Sharing controls --------------------------------------
                if (widget.spaceId == null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F5F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E2DA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.group_outlined,
                              color: Color(0xFF596171),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Join a space to use location sharing',
                                style: TextStyle(
                                  fontFamily: 'NunitoSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF202633),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'You can view and locate yourself privately without a space.',
                          style: TextStyle(
                            fontFamily: 'NunitoSans',
                            fontSize: 12,
                            color: Color(0xFF596171),
                          ),
                        ),
                        if (widget.onJoinSpace != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onJoinSpace!();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF244BFF),
                              side: const BorderSide(color: Color(0xFF244BFF)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Create or join a space',
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  ValueListenableBuilder<bool>(
                    valueListenable: locationService.isSharing,
                    builder: (context, sharing, _) {
                      if (sharing) {
                        if (locationService.activeSpaceId != widget.spaceId) {
                          return Column(
                            children: [
                              Text(
                                'Sharing in ${locationService.activeSpaceName}, not this space.',
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: _startSharing,
                                    child: const Text(
                                      'Share in this space instead',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        locationService.stopSharing(),
                                    child: const Text('End sharing'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      final id = locationService.activeSpaceId;
                                      if (id == null) return;
                                      final host = Navigator.of(context)
                                          .context;
                                      Navigator.pop(context);
                                      SpaceMapSheet.show(
                                        host,
                                        backend: widget.backend,
                                        spaceId: id,
                                      );
                                    },
                                    child: const Text('View shared space'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                        return ValueListenableBuilder<int>(
                          valueListenable: locationService.remainingMinutes,
                          builder: (context, remaining, _) {
                            return Column(
                              children: [
                                Text(
                                  'Sharing in ${locationService.activeSpaceName} (${remaining}m left)',
                                  style: const TextStyle(
                                    fontFamily: 'NunitoSans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF202633),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        locationService.stopSharing(),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: const Color(0xFFD32F2F),
                                      backgroundColor: const Color(0xFFF9DCE4),
                                      elevation: 2,
                                      shadowColor: const Color(0x337D5260),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                    ),
                                    child: const Text(
                                      'Stop sharing',
                                      style: TextStyle(
                                        fontFamily: 'NunitoSans',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              for (final d in [15, 30, 60])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: ChoiceChip(
                                      showCheckmark: false,
                                      label: Center(
                                        child: Text(
                                          '${d}m',
                                          style: TextStyle(
                                            fontFamily: 'NunitoSans',
                                            fontSize: 13,
                                            fontWeight: _selectedDuration == d
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: _selectedDuration == d
                                                ? const Color(0xFF202633)
                                                : const Color(0xFF202633),
                                          ),
                                        ),
                                      ),
                                      selected: _selectedDuration == d,
                                      selectedColor: const Color(0xFFFBEBC5),
                                      backgroundColor: const Color(0xFFFFFEFB),
                                      side: BorderSide.none,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() => _selectedDuration = d);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: _starting ? null : _startSharing,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFBEBC5),
                                foregroundColor: const Color(0xFF202633),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_starting) ...[
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(
                                    _starting ? 'Starting…' : 'Start sharing',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFFD32F2F)),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _personalLocation(
    String? uid,
    String name,
    LatLng point,
  ) {
    final fix = LiveLocationService.instance.currentPosition.value;
    return {
      'uid': uid,
      'name': '$name (You)',
      'lat': point.latitude,
      'lng': point.longitude,
      'private': true,
      if (fix != null) 'updatedAt': Timestamp.fromDate(fix.timestamp),
      if (fix != null) 'accuracy': fix.accuracy,
    };
  }

  String _memberLocationStatus(Map<String, dynamic> member) {
    final updated = member['updatedAt'];
    if (updated is! Timestamp) return 'Update time unavailable';
    final age = DateTime.now().difference(updated.toDate());
    final ageLabel = age.inMinutes < 1 ? 'just now' : '${age.inMinutes}m ago';
    final accuracy = member['accuracy'] is num
        ? ' · ±${(member['accuracy'] as num).round()} m'
        : '';
    final privacy = member['private'] == true ? 'Private · not shared · ' : '';
    return '$privacy${age > const Duration(minutes: 2) ? 'Stale · ' : ''}Updated $ageLabel$accuracy';
  }

  Widget _buildPin({
    required String uid,
    required String name,
    required String label,
    required bool isSelected,
    required bool isMe,
  }) {
    return MemberLocationPin(
      uid: uid,
      name: name,
      label: label,
      selected: isSelected,
      isMe: isMe,
    );
  }
}
