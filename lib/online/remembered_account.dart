import 'package:sembast/sembast.dart';

/// Only a display identity is remembered. Authentication credentials stay with
/// Firebase and the platform password manager, never in this local record.
class RememberedAccount {
  const RememberedAccount(this.email, this.name);
  final String email, name;
  static final _record = stringMapStoreFactory
      .store('account-preferences')
      .record('remembered');
  static Future<RememberedAccount?> load(Database? database) async {
    if (database == null) return null;
    final value = await _record.get(database);
    if (value == null) return null;
    return RememberedAccount(
      value['email'] as String,
      value['name'] as String? ?? '',
    );
  }

  Future<void> save(Database? database) async {
    if (database != null)
      await _record.put(database, {'email': email, 'name': name});
  }

  static Future<void> forget(Database? database) async {
    if (database != null) await _record.delete(database);
  }
}
