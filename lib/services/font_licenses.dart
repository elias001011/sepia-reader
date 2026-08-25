import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _fontLicenses = {
  'Inter': 'assets/fonts/licenses/Inter-OFL.txt',
  'Merriweather': 'assets/fonts/licenses/Merriweather-OFL.txt',
  'Lora': 'assets/fonts/licenses/Lora-OFL.txt',
  'Roboto Mono': 'assets/fonts/licenses/RobotoMono-OFL.txt',
};

void registerBundledFontLicenses() {
  for (final entry in _fontLicenses.entries) {
    LicenseRegistry.addLicense(() async* {
      final license = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], license);
    });
  }
}
