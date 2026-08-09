#!/usr/bin/env bash
# See ../vercel-build.sh for why this clones Flutter fresh every build.
# No build_runner step here — the shop app has zero generated code (no
# freezed/riverpod_generator/json_serializable dependencies), unlike the
# customer app.
set -euo pipefail

git clone https://github.com/flutter/flutter.git --branch 3.44.8 --depth 1 flutter-sdk
export PATH="$PATH:$(pwd)/flutter-sdk/bin"

flutter pub get
flutter build web --release --no-wasm-dry-run
