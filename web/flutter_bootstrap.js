{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Keep CanvasKit/Skwasm font fallback on the same origin. The matching
    // Noto emoji and symbol subsets live under web/fonts/fallback.
    fontFallbackBaseUrl: "fonts/fallback/",
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
