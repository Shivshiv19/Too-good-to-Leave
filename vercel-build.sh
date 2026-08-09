#!/usr/bin/env bash
# Vercel's build image has no Flutter SDK, so each build clones one fresh —
# pinned to the exact version this project has been built and tested
# against everywhere else (local dev, GitHub Actions) so behaviour never
# drifts between the two deploy targets.
set -euo pipefail

git clone https://github.com/flutter/flutter.git --branch 3.44.8 --depth 1 flutter-sdk
export PATH="$PATH:$(pwd)/flutter-sdk/bin"

flutter pub get

# *.g.dart / *.freezed.dart (riverpod_generator, freezed, json_serializable,
# drift, go_router_builder) are gitignored by design — regenerate them
# every build, the same fix that resolved this exact failure mode on the
# GitHub Pages deploy.
dart run build_runner build --delete-conflicting-outputs

# MAPTILER_API_KEY comes from a Vercel project environment variable
# (Settings > Environment Variables), never committed — see
# lib/bootstrap.dart's own startup guard for why this can't be empty.
cat > dart_defines.json <<EOF
{ "MAPTILER_API_KEY": "${MAPTILER_API_KEY:-}" }
EOF

flutter build web --release --no-wasm-dry-run \
  --dart-define-from-file=dart_defines.json
