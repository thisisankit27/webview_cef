import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_cef/webview_cef.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('webview_cef');
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Records the arguments the manager sends with 'init'.
  Future<dynamic> initArguments({
    String? userAgent,
    String? rootCachePath,
    WebviewSandboxMode? sandbox,
    String? cachePath,
    bool? enableGpu,
  }) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return null;
    });
    await WebviewManager().initialize(
      userAgent: userAgent,
      rootCachePath: rootCachePath,
      sandbox: sandbox ?? WebviewSandboxMode.required,
      cachePath: cachePath,
      enableGpu: enableGpu ?? false,
    );
    return calls.firstWhere((MethodCall call) => call.method == 'init').arguments;
  }

  test('init is sent without arguments when nothing is configured', () async {
    expect(await initArguments(), isNull);
  });

  test('init carries the user agent', () async {
    expect(await initArguments(userAgent: 'agent/1.0'),
        <String, String>{'userAgent': 'agent/1.0'});
  });

  test('init carries the root cache path', () async {
    expect(await initArguments(rootCachePath: '/tmp/webview_cef'),
        <String, String>{'rootCachePath': '/tmp/webview_cef'});
  });

  test('init carries both settings', () async {
    expect(
      await initArguments(userAgent: 'agent/1.0', rootCachePath: '/tmp/webview_cef'),
      <String, String>{'userAgent': 'agent/1.0', 'rootCachePath': '/tmp/webview_cef'},
    );
  });

  test('empty settings are left out', () async {
    expect(await initArguments(userAgent: '', rootCachePath: ''), isNull);
  });

  group('DNDReader hardening', () {
    test('the sandbox is required by default: nothing about it is sent', () async {
      // Absence of a `sandbox` key means "required" natively.
      expect(await initArguments(), isNull);
      expect(await initArguments(userAgent: 'a/1'), isNot(contains('sandbox')));
    });

    test('opting out of the sandbox is explicit', () async {
      expect(
        await initArguments(sandbox: WebviewSandboxMode.disabled),
        <String, String>{'sandbox': 'disabled'},
      );
    });

    test('a persistent request-context path and GPU are forwarded', () async {
      expect(
        await initArguments(cachePath: '/tmp/ctx', enableGpu: true),
        <String, String>{'cachePath': '/tmp/ctx', 'enableGpu': 'true'},
      );
    });

    test('a native sandbox failure surfaces as WebviewSandboxException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        throw PlatformException(
          code: 'error',
          message: 'error',
          details: 'sandbox_unavailable: user namespaces are restricted',
        );
      });
      await expectLater(
        WebviewManager().initialize(),
        throwsA(
          isA<WebviewSandboxException>().having(
            (e) => e.reason,
            'reason',
            'user namespaces are restricted',
          ),
        ),
      );
    });

    test('other platform errors are not mislabelled as sandbox failures', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        throw PlatformException(code: 'error', message: 'error', details: 'boom');
      });
      await expectLater(WebviewManager().initialize(), throwsA(isA<PlatformException>()));
    });
  });
}
