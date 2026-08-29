import 'package:flutter/material.dart';

import 'app.dart';
import 'services/font_licenses.dart';
import 'state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();
  // Build a real Flutter frame immediately. SepiaBootstrap shows a branded
  // loading surface while local persistence opens, instead of leaving Android
  // on the opaque native launch window (which looked like a black-screen
  // crash). Network sync starts only after the library itself is visible.
  runApp(SepiaBootstrap(controller: AppController()));
}
