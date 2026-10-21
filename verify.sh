#!/usr/bin/env bash
# Compiles and runs the pipeline against fixtures/corpus-a.jsonl.
# Needs a JDK 17 or newer (17 and 21 both work) and nothing else - no network, no database, no Gradle.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> compiling"
rm -rf build/selfcheck && mkdir -p build/selfcheck
javac --release 17 -d build/selfcheck $(find src/main/java -name '*.java')

echo
echo "==> running"
java -cp build/selfcheck in.simplifymoney.ledgersync.SelfCheck "$@"
