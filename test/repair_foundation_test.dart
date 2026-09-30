import 'package:image/image.dart' as img;
import 'package:stewardie/features/media/media_library.dart';
import 'package:stewardie/online/member_location_pin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as native;
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/core/month_year_picker.dart';
import 'package:stewardie/features/onboarding/onboarding_store.dart';
import 'package:stewardie/features/onboarding/permission_adapter.dart';

void main() {
  test('expired member selection cannot fall back to the viewer location', () {
    final ownFix = {'uid': 'me', 'lat': 14.0, 'lng': 121.0};
    expect(
      resolveSelectedMemberLocation(
        selectedUid: 'other',
        currentUid: 'me',
        sessions: [],
        personalLocation: ownFix,
      ),
      isNull,
    );
    expect(
      resolveSelectedMemberLocation(
        selectedUid: 'me',
        currentUid: 'me',
        sessions: [],
        personalLocation: ownFix,
      ),
      ownFix,
    );
    final latest = {'uid': 'other', 'lat': 15.0, 'lng': 122.0};
    expect(
      resolveSelectedMemberLocation(
        selectedUid: 'other',
        currentUid: 'me',
        sessions: [latest],
        personalLocation: ownFix,
      ),
      latest,
    );
  });
  test('selected framing becomes saved pixels and cannot crop twice', () {
    final image = img.Image(width: 400, height: 300);
    final framing = FramingRect.fromAspectRatio(
      targetRatio: 9 / 16,
      imageWidth: 400,
      imageHeight: 300,
      ratioName: '9:16',
    );
    final preview = processPhoto({
      'bytes': img.encodePng(image),
      'source': 'camera',
      'framing': framing.toMap(),
    });
    expect(preview.width, 400);
    expect(preview.framing.isFull, isFalse);
    final saved = processPhoto({
      'bytes': preview.bytes,
      'source': 'camera',
      'framing': preview.framing.toMap(),
      'bakeFraming': true,
    });
    expect(saved.width, 169);
    expect(saved.height, 300);
    expect(saved.framing.isFull, isTrue);
    final thumbnail = img.decodeImage(saved.thumbnail)!;
    expect(thumbnail.width / thumbnail.height, closeTo(9 / 16, .01));
    final repeated = processPhoto({
      'bytes': saved.bytes,
      'source': 'camera',
      'framing': saved.framing.toMap(),
      'bakeFraming': true,
    });
    expect(repeated.width, saved.width);
    expect(repeated.height, saved.height);
  });
  test('native permission status does not manufacture a grant', () {
    expect(
      PermissionAdapter.mapStatus(native.PermissionStatus.denied),
      PermissionStatusState.denied,
    );
    expect(
      PermissionAdapter.mapStatus(native.PermissionStatus.granted),
      PermissionStatusState.granted,
    );
    expect(
      PermissionAdapter.mapStatus(native.PermissionStatus.permanentlyDenied),
      PermissionStatusState.permanentlyDenied,
    );
  });
  test(
    'legacy drafts resume the same feature/payoff after inserting profile',
    () async {
      final db = await databaseFactoryMemory.openDatabase('draft-migration');
      addTearDown(db.close);
      final record = stringMapStoreFactory
          .store('onboarding_v1')
          .record('draft_u');
      for (final entry in {
        5: OnboardingStep.features,
        6: OnboardingStep.allSet,
      }.entries) {
        await record.put(db, {
          'schemaVersion': 1,
          'stepIndex': entry.key,
          'avatarBase64': 'saved-photo',
        });
        final draft = await OnboardingStore(db).loadDraft('u');
        expect(draft!['stepIndex'], entry.value.index);
        expect(draft['avatarBase64'], 'saved-photo');
      }
    },
  );
  test('calendar keeps valid days across leap years and clamps its range', () {
    expect(calendarDayInMonth(DateTime(2024, 2), 31), DateTime(2024, 2, 29));
    expect(calendarDayInMonth(DateTime(2025, 2), 31), DateTime(2025, 2, 28));
    expect(clampCalendarMonth(DateTime(1000)).year, DateTime.now().year - 100);
    expect(clampCalendarMonth(DateTime(9999)).year, DateTime.now().year + 20);
  });
}
