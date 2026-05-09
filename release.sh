#!/usr/bin/env zsh
# release.sh — Build, verify, package, and publish a WireHack release.
#
# Usage: ./release.sh <version>
#   e.g. ./release.sh 1.0.0
#
# Requires: xcodebuild, hdiutil, gh (GitHub CLI), git, xcodegen

set -euo pipefail

REPO="sevmorris/WireHack"

# ── Args ──────────────────────────────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <version>"
    echo "  e.g. $0 1.0.0"
    exit 1
fi

VERSION="$1"
TAG="v${VERSION}"
SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="$SCRIPT_DIR"
YAML="$PROJECT_DIR/project.yml"
PROJECT="$PROJECT_DIR/WireHack.xcodeproj"
SCHEME="WireHack"
DERIVED_DATA="/tmp/wirehack_build_${VERSION}"
APP_PATH="$DERIVED_DATA/Build/Products/Release/WireHack.app"
STAGING="/tmp/wirehack_dmg_${VERSION}"
DMG="/tmp/WireHack-${TAG}.dmg"
MOUNT="/tmp/wirehack_verify_${VERSION}"

# ── Helpers ───────────────────────────────────────────────────────────────────
step()  { echo "\n▶ $*"; }
ok()    { echo "  ✓ $*"; }
fail()  { echo "\n  ✗ $*" >&2; exit 1; }

cleanup() {
    rm -rf "$STAGING" "$MOUNT" "$DERIVED_DATA"
    rm -f "$DMG"
}

# ── Preflight ─────────────────────────────────────────────────────────────────
step "Preflight checks"
for cmd in xcodebuild hdiutil gh git xcodegen; do
    command -v $cmd &>/dev/null || fail "'$cmd' not found in PATH"
done
ok "Tools present"

cd "$PROJECT_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
    fail "Working tree is dirty — commit or stash changes before releasing"
fi
ok "Working tree clean"

if git tag | grep -q "^${TAG}$"; then
    fail "Tag $TAG already exists — has this version been released?"
fi
ok "Tag $TAG is available"

# ── Version bump ──────────────────────────────────────────────────────────────
step "Bumping version to $VERSION"
CURRENT=$(grep -E "CFBundleShortVersionString:" "$YAML" | head -1 | grep -o '[0-9][0-9.]*')
if [[ "$CURRENT" == "$VERSION" ]]; then
    ok "Already at $VERSION"
else
    sed -i '' "s/CFBundleShortVersionString: \"${CURRENT}\"/CFBundleShortVersionString: \"${VERSION}\"/g" "$YAML"
    # Build number: zero-padded MMMmmpp so it stays monotonic across digit
    # boundaries (e.g. 1.5.10 → 10510 < 1.6.0 → 10600).
    IFS=. read -r MAJ MIN PATCH <<< "$VERSION"
    BUNDLE_VERSION=$(printf "%d%02d%02d" "${MAJ:-0}" "${MIN:-0}" "${PATCH:-0}")
    sed -i '' "s/CFBundleVersion: \"[0-9]*\"/CFBundleVersion: \"${BUNDLE_VERSION}\"/g" "$YAML"

    xcodegen generate
    ok "Bumped $CURRENT → $VERSION (build $BUNDLE_VERSION) and regenerated project"
fi

# Always update README's download link, even if version was pre-bumped.
sed -i '' "s|WireHack-v[0-9][0-9.]*\.dmg|WireHack-${TAG}.dmg|g" README.md

if [[ -n "$(git status --porcelain)" ]]; then
    git add "$YAML" "$PROJECT/project.pbxproj" "WireHack/Info.plist" README.md
    git commit -m "Bump version to $VERSION"
    ok "Committed version bump"
else
    ok "All files already up to date"
fi

# ── Build ─────────────────────────────────────────────────────────────────────
step "Building (clean, Release)"
rm -rf "$DERIVED_DATA"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet
ok "Build complete"

# ── Sign ──────────────────────────────────────────────────────────────────────
step "Codesigning app bundle"
IDENTITY="Developer ID Application: Seven Morris (T9RLNAXPWU)"
ENTITLEMENTS="$PROJECT_DIR/WireHack/WireHack.entitlements"

# Sign the app bundle with Hardened Runtime
codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP_PATH"
ok "Codesigning complete"

# ── Verify app version ────────────────────────────────────────────────────────
step "Verifying built app version"
BUILT_VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString)
[[ "$BUILT_VERSION" == "$VERSION" ]] || \
    fail "App version mismatch: expected $VERSION, got $BUILT_VERSION"
ok "App reports $BUILT_VERSION"

# ── Stage DMG contents ────────────────────────────────────────────────────────
step "Staging DMG contents"
rm -rf "$STAGING"
mkdir "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
ok "App, Applications alias"

# ── Create DMG ────────────────────────────────────────────────────────────────
step "Creating DMG"
rm -f "$DMG"
hdiutil create \
    -volname "WireHack $TAG" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -o "$DMG" \
    -quiet
ok "Created $(du -sh $DMG | cut -f1) DMG"

# ── Notarize ──────────────────────────────────────────────────────────────────
step "Notarizing DMG"
xcrun notarytool submit "$DMG" --wait --keychain-profile "WoWoNotary"
xcrun stapler staple "$DMG"
ok "Notarization complete"

# ── Verify DMG ────────────────────────────────────────────────────────────────
step "Verifying DMG contents"
rm -rf "$MOUNT"
mkdir "$MOUNT"
hdiutil attach "$DMG" -mountpoint "$MOUNT" -quiet -nobrowse
DMG_VERSION=$(defaults read "$MOUNT/WireHack.app/Contents/Info.plist" CFBundleShortVersionString)
hdiutil detach "$MOUNT" -quiet
[[ "$DMG_VERSION" == "$VERSION" ]] || \
    fail "DMG version mismatch: expected $VERSION, got $DMG_VERSION"
ok "DMG contains $DMG_VERSION"

# ── Tag and push ──────────────────────────────────────────────────────────────
step "Tagging and pushing"
git tag "$TAG"
# Resolve the tracked remote/branch so this works from any branch (e.g. a
# worktree branch whose name differs from its upstream).
UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}')
REMOTE="${UPSTREAM%%/*}"
BRANCH="${UPSTREAM#*/}"
git push "$REMOTE" "HEAD:$BRANCH"
git push "$REMOTE" "$TAG"
ok "Pushed $TAG to $REMOTE/$BRANCH"

# ── GitHub release ────────────────────────────────────────────────────────────
step "Creating GitHub release"
PREV_TAG=$(git tag --sort=-creatordate | grep -v "^${TAG}$" | head -1)
if [[ -n "$PREV_TAG" ]]; then
    CHANGES=$(git log "${PREV_TAG}..HEAD" --pretty=format:"- %s" | grep -v "^- Bump version" || true)
else
    CHANGES=$(git log --pretty=format:"- %s" | grep -v "^- Bump version" || true)
fi
RELEASE_NOTES="### Changes
${CHANGES}"

gh release create "$TAG" "$DMG" \
    --repo "$REPO" \
    --title "WireHack $TAG" \
    --notes "$RELEASE_NOTES"
ok "Release published"

# ── Clean up temp files ───────────────────────────────────────────────────────
step "Cleaning up"
rm -rf "$STAGING" "$MOUNT" "$DERIVED_DATA"
# Keep DMG in project root for easy access if needed, or just delete it
# rm -f "$DMG"
ok "Temp files removed"

RELEASE_URL="https://github.com/${REPO}/releases/tag/${TAG}"
echo "\n✓ WireHack $TAG released successfully."
echo "  $RELEASE_URL"
