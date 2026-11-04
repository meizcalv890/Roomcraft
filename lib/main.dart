import 'package:flutter/material.dart';

import 'app.dart';
import 'core/storage/roomcraft_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RoomcraftStorage.initialize();

  runApp(const RoomcraftApp());
}
