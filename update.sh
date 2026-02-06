#!/usr/bin/env bash

# Get current version from versions.json
CURRENT_VERSION=$(grep 'version = ' package.nix | sed 's/.*version = "\([^"]*\)".*/\1/')
echo "Current version: $CURRENT_VERSION"

# Get both latest stable and prerelease versions
LATEST_STABLE=$(npm view @github/copilot dist-tags.latest)
LATEST_PRERELEASE=$(npm view @github/copilot dist-tags.prerelease)
echo "Latest stable: $LATEST_STABLE"
echo "Latest prerelease: $LATEST_PRERELEASE"

# Compare versions using semver logic - pick whichever is newer
# npx semver will output the higher version when given two versions
LATEST_VERSION=$(npx semver "$LATEST_STABLE" "$LATEST_PRERELEASE" | tail -1)
echo "Selected version: $LATEST_VERSION"

# Check if update is needed
if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
  tmpFile=$(mktemp)
  jq ".version=\"${LATEST_VERSION}\"" versions.json > $tmpFile 
  cp $tmpFile versions.json
  NEW_URL="https://registry.npmjs.org/@github/copilot/-/copilot-${LATEST_VERSION}.tgz"
  NEW_SHA256=$(nix-prefetch-url --type sha256 "$NEW_URL")
  NEW_SHA256_NIX=$(nix hash to-sri --type sha256 "$NEW_SHA256")
  echo $NEW_SHA256
  echo $NEW_SHA256_NIX
  jq ".sha256=\"${NEW_SHA256_NIX}\"" versions.json > $tmpFile 
  cp $tmpFile versions.json
  npm init -y > /dev/null 2>&1 || true
  npm install --package-lock-only  @github/copilot@$LATEST_VERSION

  BUILD_OUTPUT=$(nix build --no-link --accept-flake-config .#packages.x86_64-linux.default 2>&1 || true)
  NEW_NPM_HASH=$(echo "$BUILD_OUTPUT" | grep "got:" | sed 's/.*got: *\([^ ]*\).*/\1/' | tail -1)
  jq ".npmDepsHash=\"${NEW_NPM_HASH}\"" versions.json > $tmpFile
  cp $tmpFile versions.json
  rm package.json
else
  echo "No update needed"
fi
