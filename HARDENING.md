# DNDReader hardening patch set

This is a fork of [`hlwhl/webview_cef`](https://github.com/hlwhl/webview_cef), based on upstream
`main` at `bb2dbcc` (2026-09-18, which already contains the unreleased `rootCachePath` option).
It is maintained for [DNDReader](https://github.com/thisisankit27/DNDReader), a PDF reader that shows
web search results in an embedded panel.

> **Licence notice (Apache-2.0 §4(b)).** The files listed below were modified from the upstream
> versions by the DNDReader project. This document is the prominent notice of those changes. The
> upstream `LICENSE` is unchanged and applies to the whole work; upstream has no `NOTICE` file.

## Why

Upstream (including the published 0.6.2) unconditionally launches Chromium with protections that an
application embedding *third-party web pages* should not have turned off, with no opt-out in its API.
The upstream maintainer describes the setting as "a global setting that can ignore all browser
security settings, but be careful to only load pages that you fully trust" (issue #110).

| Upstream behaviour | Where | This fork |
|---|---|---|
| `--disable-web-security` | `common/webview_app.cc` | **removed** |
| `--allow-running-insecure-content` | `common/webview_app.cc` | **removed** |
| `disable-features=SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure` | `common/webview_app.cc` | **removed** (other `disable-features` entries kept) |
| `--no-sandbox` switch **and** `CefSettings.no_sandbox = true` | `common/webview_app.cc`, `common/webview_plugin.cc` | sandbox **on by default on Linux**; opt-out is explicit |
| persistent profile in the platform default directory | (CEF default) | in-memory request context by default |
| `SetEnableGPU()` existed but was never called | `common/webview_app.cc` | reachable via `initialize(enableGpu: true)` |
| main-frame load errors rendered as a raw `data:` page ("Failed to load URL … with error …") | `common/webview_handler.cc` | reported through `WebviewEventsListener.onLoadError`; no page is rendered |

## What changed (modified files)

* `common/webview_app.cc`, `common/webview_app.h` — drop the three insecure defaults; `--no-sandbox` only
  when the embedder opted out (`SetNoSandbox`); other platforms keep upstream's `true`.
* `common/webview_plugin.cc` — parse `sandbox`, `enableGpu`, `cachePath`; **Linux sandbox preflight**
  before `CefInitialize` (fork a throw-away child; `unshare` user/pid/net namespaces, write uid/gid maps,
  `chroot("/proc/self/fdinfo")` — the operations Chromium's namespace sandbox performs). On failure CEF is
  **not** initialised and `init` returns an error `sandbox_unavailable: <reason>`. Sets
  `isCefInitialized` after start.
* `common/webview_handler.cc`, `common/webview_handler.h` — one shared `CefRequestContext` for all
  browsers; empty `cache_path` (in-memory) unless `cachePath` is given; `onLoadError` instead of the raw
  `data:` error page.
* `lib/src/webview_events_listener.dart` — `onLoadError`.
* `lib/src/webview_manager.dart`, `lib/webview_cef.dart` — `initialize({sandbox, cachePath, enableGpu})`;
  `WebviewSandboxException`.
* `lib/src/webview_sandbox.dart` (new) — `WebviewSandboxMode`, `WebviewSandboxException`.
* `test/webview_manager_init_test.dart` — tests for the above.

## API

```dart
await WebviewManager().initialize(
  rootCachePath: '/absolute/path',                 // upstream main
  sandbox: WebviewSandboxMode.required,            // default; .disabled = --no-sandbox (dev only)
  cachePath: null,                                 // null = in-memory; or a dir inside rootCachePath
  enableGpu: false,                                // true = do not pass --disable-gpu[-compositing]
);   // throws WebviewSandboxException if the sandbox cannot start
```

## Platform scope

Developed and tested **on Ubuntu 26.04 only**. On Windows and macOS the sandbox setting is *not*
changed (their sandbox needs a bootstrap/helper layout this plugin does not provide), but the three flag
removals apply to every platform and have **not** been exercised there.

## Making the sandbox start on Ubuntu ≥ 24.04

`kernel.apparmor_restrict_unprivileged_userns=1` denies capabilities to unprivileged user namespaces for
unconfined programs, so the namespace sandbox cannot start unless the *application* has an AppArmor
profile granting `userns` (Ubuntu ships such profiles for Chrome, Chromium, Signal, Slack, VS Code):

```
abi <abi/5.0>,
include <tunables/global>
profile myapp /usr/lib/myapp/myapp flags=(unconfined) {
  userns,
  @{exec_path} mr,
}
```

A SUID `chrome-sandbox` is not required for that path.

## Maintenance

Keep the diff small and deletion-heavy so it rebases cleanly. Rebase on upstream `main` at least
quarterly and on every CEF bump (`CEF_VERSION` in `third/download.cmake` is the single source of truth).
The opt-out for the insecure defaults and the sandbox switch are intended to be offered upstream.
