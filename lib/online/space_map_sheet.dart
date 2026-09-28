import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../core/stewardie_map.dart';
import '../core/member_avatar.dart';
import 'external_launcher.dart';
import 'live_location_service.dart';
import 'online_backend.dart';

/// A private map view; opening it does not start live sharing.
class SpaceMapSheet extends StatefulWidget {
  const SpaceMapSheet({
    super.key,
    required this.backend,
    required this.spaceId,
  });

  final OnlineBackend backend;
  final String spaceId;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required String spaceId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F6),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SpaceMapSheet(backend: backend, spaceId: spaceId),
    );
  }

  @override
  State<SpaceMapSheet> createState() => _SpaceMapSheetState();
}

class _SpaceMapSheetState extends State<SpaceMapSheet> {
  final MapController _mapController = MapController();
  int _selectedDuration = 15; // 15, 30, 60
  Map<String, dynamic>? _selectedMember;
  StewardieMapStyle _style = StewardieMapStyle.satellite;
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
    final cached = LiveLocationService.instance.currentPosition.value;
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) <
            const Duration(minutes: 10)) {
      final pos = LatLng(cached.latitude, cached.longitude);
      _lastKnownCenter = pos;
      _currentUserLatLng = pos;
      _locationStatus = 'Showing a recent device location while locating…';
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
      if (cached == null || !mounted || _freshResolved ||
          DateTime.now().difference(cached.timestamp) > const Duration(minutes: 10)) return;
      final point = LatLng(cached.latitude, cached.longitude);
      setState(() { _currentUserLatLng = point; _lastKnownCenter = point;
        _locationStatus = 'Showing a recent device location while locating…'; });
      if (_allowAutoCenter && _mapReady) _mapController.move(point, 15);
    } catch (_) { /* A cached fix is optional. */ }
  }

  void _onPositionChanged() {
    final pos = LiveLocationService.instance.currentPosition.value;
    if (pos != null && mounted) {
      _freshResolved = true;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentUserLatLng = latLng;
        _lastKnownCenter = latLng;
      });
      if (_allowAutoCenter && _mapReady) _mapController.move(latLng, 15);
    }
  }

  @override
  void dispose() {
    LiveLocationService.instance.currentPosition.removeListener(
      _onPositionChanged,
    );
    super.dispose();
  }

  Future<void> _initUserLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted)
        setState(
          () => _locationStatus =
              'Location services are off. Enable them to recenter.',
        );
      return;
    }
    final pos = await LiveLocationService.instance.determinePosition();
    if (pos != null && mounted) {
      final userLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _lastKnownCenter = userLatLng;
        _currentUserLatLng = userLatLng;
        _locationStatus = 'Your private device location';
      });
      if (_allowAutoCenter && _mapReady) _mapController.move(userLatLng, 15.0);
    } else if (mounted) {
      final permission = await Geolocator.checkPermission();
      setState(
        () => _locationStatus =
            permission == LocationPermission.denied ||
                permission == LocationPermission.deniedForever
            ? 'Location permission denied. Enable it in device settings.'
            : 'Location timed out or is unavailable. Try Recenter.',
      );
    }
  }

  Future<void> _recenterOnUser() async {
    _allowAutoCenter = true;
    if (_currentUserLatLng != null && _mapReady)
      _mapController.move(_currentUserLatLng!, 15);
    final pos = await LiveLocationService.instance.determinePosition();
    if (pos != null && mounted) {
      final userLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _lastKnownCenter = userLatLng;
        _currentUserLatLng = userLatLng;
      });
      if (_mapReady) _mapController.move(userLatLng, 15.0);
    } else if (mounted) {
      setState(
        () => _locationStatus =
            'Could not update your location. Check permission and services.',
      );
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
      if (me == null || !ids.contains(me))
        throw StateError('You are no longer in this space.');
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
            'Your latest location will be visible in this space to: '
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
        spaceId: widget.spaceId,
        durationMinutes: _selectedDuration,
      );
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
        height: media.size.height * .9 - media.padding.top,
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
                    const Text(
                      'Space map',
                      style: TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202633),
                      ),
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
                const SizedBox(height: 16),
                SegmentedButton<StewardieMapStyle>(
                  segments: const [
                    ButtonSegment(
                      value: StewardieMapStyle.satellite,
                      label: Text('Satellite'),
                      icon: Icon(Icons.satellite_alt_outlined),
                    ),
                    ButtonSegment(
                      value: StewardieMapStyle.streets,
                      label: Text('Streets'),
                      icon: Icon(Icons.map_outlined),
                    ),
                  ],
                  selected: {_style},
                  onSelectionChanged: (value) =>
                      setState(() => _style = value.first),
                ),
                if (mapTilerKey.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Satellite needs a free MapTiler key. Streets remain available.',
                    ),
                  ),
                const SizedBox(height: 12),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: widget.backend.locationSessions(widget.spaceId),
                  builder: (context, snapshot) {
                    final sessions =
                        snapshot.data ?? const <Map<String, dynamic>>[];

                    final myUid = widget.backend.auth.currentUser?.uid;
                    final myUser = widget.backend.auth.currentUser;
                    final myRawName = myUser?.displayName?.isNotEmpty == true
                        ? myUser!.displayName!
                        : (myUser?.email?.split('@').first ?? 'You');

                    // Build markers for all active sessions
                    final markers = <Marker>[];
                    bool userHasSessionMarker = false;

                    for (final s in sessions) {
                      final lat = (s['lat'] as num?)?.toDouble();
                      final lng = (s['lng'] as num?)?.toDouble();
                      if (lat == null || lng == null) continue;

                      final isMe = s['uid'] == myUid;
                      if (isMe) userHasSessionMarker = true;

                      final name = isMe
                          ? 'You'
                          : (s['name'] as String? ?? 'Member');
                      final isSelected = _selectedMember?['uid'] == s['uid'];

                      markers.add(
                        Marker(
                          point: LatLng(lat, lng),
                          width: 56,
                          height: 62,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedMember = s);
                            },
                            child: _buildPin(
                              uid: s['uid'] as String? ?? '',
                              name: isMe ? myRawName : name,
                              label: isMe ? 'You' : name,
                              isSelected: isSelected,
                              isMe: isMe,
                            ),
                          ),
                        ),
                      );
                    }

                    // Only show a personal pin after a real GPS fix. The map's
                    // neutral (0, 0) center is never a reported location.
                    final userPoint = _currentUserLatLng;
                    if (!userHasSessionMarker && userPoint != null) {
                      final isSelected = _selectedMember?['uid'] == myUid;
                      markers.add(
                        Marker(
                          point: userPoint,
                          width: 56,
                          height: 62,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedMember = {
                                  'uid': myUid,
                                  'name': '$myRawName (You)',
                                  'lat': userPoint.latitude,
                                  'lng': userPoint.longitude,
                                };
                              });
                            },
                            child: _buildPin(
                              uid: myUid ?? '',
                              name: myRawName,
                              label: 'You',
                              isSelected: isSelected,
                              isMe: true,
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
                              zoom: _currentUserLatLng == null ? 5 : 15,
                              markers: markers,
                              style: _style,
                              onUserInteraction: () => _allowAutoCenter = false,
                              onReady: () {
                                _mapReady = true;
                                if (_allowAutoCenter &&
                                    _currentUserLatLng != null) {
                                  _mapController.move(_currentUserLatLng!, 15);
                                }
                              },
                            ),
                            // Recenter button
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Material(
                                color: const Color(0xFFFFFEFB),
                                shape: const CircleBorder(),
                                elevation: 3,
                                child: InkWell(
                                  onTap: _recenterOnUser,
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.my_location_rounded,
                                      color: Color(0xFF244BFF),
                                      size: 20,
                                    ),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Column(
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
                        )),
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
                const SizedBox(height: 20),
                ValueListenableBuilder<bool>(
                  valueListenable: locationService.isSharing,
                  builder: (context, sharing, _) {
                    if (sharing) {
                      return ValueListenableBuilder<int>(
                        valueListenable: locationService.remainingMinutes,
                        builder: (context, remaining, _) {
                          return Column(
                            children: [
                              Text(
                                'Sharing your live location (${remaining}m left)',
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
                                child: OutlinedButton(
                                  onPressed: () =>
                                      locationService.stopSharing(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFD32F2F),
                                    side: const BorderSide(
                                      color: Color(0xFFD32F2F),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
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
                                              ? Colors.white
                                              : const Color(0xFF202633),
                                        ),
                                      ),
                                    ),
                                    selected: _selectedDuration == d,
                                    selectedColor: const Color(0xFF244BFF),
                                    backgroundColor: const Color(0xFFFFFEFB),
                                    side: BorderSide(
                                      color: _selectedDuration == d
                                          ? const Color(0xFF244BFF)
                                          : const Color(0xFFE5E2DA),
                                    ),
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
                              backgroundColor: const Color(0xFF244BFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _starting ? 'Starting…' : 'Start sharing',
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
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
            ),
          ),
        ),
      ),
    );
  }

  String _memberLocationStatus(Map<String, dynamic> member) {
    final updated = member['updatedAt'];
    if (updated is! Timestamp) return 'Current device location · not shared';
    final age = DateTime.now().difference(updated.toDate());
    final ageLabel = age.inMinutes < 1 ? 'just now' : '${age.inMinutes}m ago';
    final accuracy = member['accuracy'] is num
        ? ' · ±${(member['accuracy'] as num).round()} m' : '';
    return '${age > const Duration(minutes: 2) ? 'Stale · ' : ''}Updated $ageLabel$accuracy';
  }

  Widget _buildPin({
    required String uid,
    required String name,
    required String label,
    required bool isSelected,
    required bool isMe,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MemberAvatar(uid: uid, name: name, radius: 19, selected: isSelected),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF244BFF) : const Color(0xFF202633),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            label.length > 7 ? '${label.substring(0, 7)}..' : label,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
