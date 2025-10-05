#!/usr/bin/env bash
set -euo pipefail
echo '[1/3] dart format .'
dart format .
echo '[2/3] dart analyze'
dart analyze
echo '[3/3] flutter test'
flutter test
echo 'OK ✅'
