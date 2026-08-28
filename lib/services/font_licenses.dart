import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The reading faces bundled with the app, mapped to the OFL text that has to
/// travel with them. Shown under the app's own "open-source licenses" screen.
const _fontLicenses = {
  'Inter': 'assets/fonts/licenses/Inter-OFL.txt',
  'Merriweather': 'assets/fonts/licenses/Merriweather-OFL.txt',
  'Merriweather Sans': 'assets/fonts/licenses/MerriweatherSans-OFL.txt',
  'Lora': 'assets/fonts/licenses/Lora-OFL.txt',
  'Bitter': 'assets/fonts/licenses/Bitter-OFL.txt',
  'Literata': 'assets/fonts/licenses/Literata-OFL.txt',
  'Source Serif 4': 'assets/fonts/licenses/SourceSerif4-OFL.txt',
  'EB Garamond': 'assets/fonts/licenses/EBGaramond-OFL.txt',
  'Atkinson Hyperlegible': 'assets/fonts/licenses/AtkinsonHyperlegible-OFL.txt',
  'Roboto Mono': 'assets/fonts/licenses/RobotoMono-OFL.txt',
  'JetBrains Mono': 'assets/fonts/licenses/JetBrainsMono-OFL.txt',
};

void registerBundledFontLicenses() {
  for (final entry in _fontLicenses.entries) {
    LicenseRegistry.addLicense(() async* {
      try {
        final license = await rootBundle.loadString(entry.value);
        yield LicenseEntryWithLineBreaks([entry.key], license);
      } catch (error) {
        debugPrint('sepia: missing font license ${entry.value}: $error');
      }
    });
  }
}
