import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/online/notification_identity.dart';

void main() {
  test('a live request and its worker notice count once', () {
    final live = liveRequestKey('home', 'task-1', 'bob', {
      'status': 'requested',
      'requestedUid': 'bob',
      'version': 3,
    });
    final history = unreadActivityKey('event-1', {
      'spaceId': 'home',
      'kind': 'taskAssigned',
      'taskId': 'task-1',
      'taskVersion': 3,
    });
    expect(live, history);
    expect(
      uniqueNotificationCount(
        [
          {live!},
        ],
        [
          {history!},
        ],
      ),
      1,
    );
    expect(
      uniqueNotificationCount(
        [
          {live},
        ],
        [
          {
            unreadActivityKey('old', {
              'spaceId': 'home',
              'kind': 'taskAssigned',
              'taskId': 'task-1',
            })!,
          },
        ],
      ),
      1,
    );
    expect(
      liveRequestKey('home', 'task-1', 'bob', {
        'status': 'accepted',
        'requestedUid': null,
      }),
      isNull,
    );
  });

  test('ownership offers and cancelled notices have distinct states', () {
    expect(
      unreadActivityKey('offer-1', {
        'spaceId': 'home',
        'kind': 'ownershipOffered',
      }),
      'ownership:home',
    );
    expect(
      unreadActivityKey('cancelled', {
        'spaceId': 'home',
        'kind': 'due',
        'pushState': 'cancelled',
      }),
      isNull,
    );
  });
}
