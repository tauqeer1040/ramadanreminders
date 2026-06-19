#!/bin/bash
# Build optimized release APK
flutter build apk --release \
  --split-per-abi \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --target-platform android-arm64

echo ""
echo "APK size:"
ls -lh build/app/outputs/flutter-apk/app-*-release.apk 2>/dev/null

echo ""
echo "Total APK sizes (all ABIs if --split-per-abi was used):"
ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null
