#!/usr/bin/env bash
set -euo pipefail

# Keep the web archive fully static: fonts and Flutter's rendering runtime are
# shipped inside build/web instead of being fetched from public CDNs.
(cd web/fonts/fallback && sha256sum --check SHA256SUMS.txt)

flutter build web --release --wasm --no-web-resources-cdn

# Flutter's loader references a development source map that is not shipped in
# release archives. Removing only that hint keeps browser consoles free of a
# harmless 404 without changing application code.
sed -i '/sourceMappingURL=flutter\.js\.map/d' \
  build/web/flutter.js \
  build/web/flutter_bootstrap.js

# Guard against accidentally reverting the same-origin font configuration or
# dropping the vendored fallback subsets from a future release archive.
grep -Fq 'fontFallbackBaseUrl: "fonts/fallback/"' \
  build/web/flutter_bootstrap.js
(cd build/web/fonts/fallback && sha256sum --check SHA256SUMS.txt)
