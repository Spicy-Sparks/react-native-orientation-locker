# react-native-orientation-locker — Lyra in-repo fork

Standalone fork of `react-native-orientation-locker@1.7.0`, published as
**`@javascriptcommon/react-native-orientation-locker`**. Lyra consumes it via the
npm version in `universal/package.json` (`"@javascriptcommon/react-native-orientation-locker": "^1.7.0"`).
The **npm name is scoped** but the **pod name stays `react-native-orientation-locker`**
(hardcoded in the `.podspec`), so it is a drop-in: the native
integration is untouched — `universal/ios/Lyra/Lyra-Bridging-Header.h`
(`#import <react-native-orientation-locker/Orientation.h>`), `AppDelegate.swift`
(`Orientation.getOrientation()`), autolinking, and the `index.ts`
`Orientation.lockToPortrait()` all keep working unchanged.

## Why we forked

Upstream 1.7.0 calls `[self addListener:@"orientationDidChange"]` in `-init` and
`[self removeListeners:1]` in `-dealloc` (`iOS/RCTOrientation/Orientation.m`).
Those `RCTEventEmitter` methods are meant to be driven **only** by the JS bridge;
calling them natively corrupts the JS-managed listener count and, under the New
Architecture, throws on module teardown:

> Attempted to remove more Orientation listeners than added
> (`-[RCTEventEmitter removeListeners:]`, `-[Orientation dealloc]`)

`RCTLogError` → a **redbox in debug** (silent log in release, so no production
crash, but it broke the dev loop). The fix removes both calls; the
`NSNotificationCenter` observer already drives device-orientation detection
independently of the RCTEventEmitter listener count. See the `PATCH (Lyra)`
comments in `iOS/RCTOrientation/Orientation.m`.

This replaces the earlier `universal/patches/react-native-orientation-locker+1.7.0.patch`
(patch-package) with an owned in-repo fork.

## Publishing to npm (when ready)

To publish under our own scope (like `@javascriptcommon/react-native-track-player`):

1. Set this `package.json` `"name": "@javascriptcommon/react-native-orientation-locker"`
   and add `"publishConfig": { "access": "public" }` + `repository`. **Keep the podspec
   `s.name = react-native-orientation-locker`** so the iOS Bridging-Header
   (`<react-native-orientation-locker/Orientation.h>`), `AppDelegate.swift`, and
   autolinking stay unchanged — only the JS package/import name is scoped.
2. `npm publish` from this directory (needs npm access to the `@javascriptcommon` scope).
3. In `universal/package.json` switch the dep to the published version, and update the JS
   import in `universal/index.ts` to `require('@javascriptcommon/react-native-orientation-locker')`.
   Then `yarn install` + `cd ios && pod install`.

Until then it is consumed **in-repo** via `link:` — no publish needed, and the fix is live.

