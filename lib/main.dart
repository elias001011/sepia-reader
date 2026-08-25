import 'package:flutter/material.dart';

import 'app.dart';
import 'services/font_licenses.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();
  final controller = AppController();
  await controller.initialize();
  runApp(SepiaApp(controller: controller));
}
