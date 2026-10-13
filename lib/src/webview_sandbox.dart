/// DNDReader hardening (see HARDENING.md).
///
/// Whether the embedded Chromium runs inside its sandbox.
enum WebviewSandboxMode {
  /// The sandbox must start. If it cannot, [WebviewManager.initialize] throws a
  /// [WebviewSandboxException] **before** CEF is initialised. This is the default.
  required,

  /// Run without the sandbox (`--no-sandbox`). Every renderer, including those
  /// loading third-party pages, then runs with the user's full privileges.
  /// Intended for development on machines where the sandbox cannot be set up;
  /// release builds of an application should never select it.
  disabled,
}

/// Thrown by [WebviewManager.initialize] when [WebviewSandboxMode.required] was
/// requested and the sandbox cannot start on this system.
///
/// Nothing was initialised and no browser process exists when this is thrown.
class WebviewSandboxException implements Exception {
  const WebviewSandboxException(this.reason);

  /// A short, user-presentable explanation.
  final String reason;

  @override
  String toString() => 'WebviewSandboxException: $reason';
}
