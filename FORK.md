# Fork of react-native-orientation-locker

Published as **`@javascriptcommon/react-native-orientation-locker`** — a fork of
`react-native-orientation-locker@1.7.0`. The **npm name is scoped** but the **pod
name stays `react-native-orientation-locker`** (hardcoded in the `.podspec`), so it
is a drop-in: the iOS Bridging-Header (`<react-native-orientation-locker/Orientation.h>`),
`Orientation.getOrientation()`, and autolinking are unchanged — only the JS
package/import name is scoped.

## Why we forked

Upstream 1.7.0 calls `[self addListener:@"orientationDidChange"]` in `-init` and
`[self removeListeners:1]` in `-dealloc` (`iOS/RCTOrientation/Orientation.m`). Those
`RCTEventEmitter` methods are meant to be driven **only** by the JS bridge; calling
them natively corrupts the JS-managed listener count and, under the New Architecture,
throws on module teardown:

> Attempted to remove more Orientation listeners than added
> (`-[RCTEventEmitter removeListeners:]`, `-[Orientation dealloc]`)

`RCTLogError` → a **redbox in debug** (silent log in release). The fix removes both
calls; the `NSNotificationCenter` observer already drives device-orientation detection
independently of the RCTEventEmitter listener count. See the `PATCH:` comments in
`iOS/RCTOrientation/Orientation.m`.
