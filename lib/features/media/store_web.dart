import 'package:sembast_web/sembast_web.dart';

Future<Database> openLocalDatabase() =>
    databaseFactoryWeb.openDatabase('stewardie-v1');
