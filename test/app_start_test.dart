import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raad_mobile/app/protected_store.dart';
import 'package:raad_mobile/auth/session_store.dart';
import 'package:raad_mobile/main.dart' as app;
import 'package:raad_mobile/main_fake.dart' as preview;

import 'support/harness.dart';

void main() {
  testWidgets('a build without C4 values shows why and starts nothing', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    expect(byKey('config.error'), findsOneWidget);
    expect(
      find.textContaining('Missing value for "configVersion"'),
      findsOneWidget,
    );
    expect(byKey('signIn.submit'), findsNothing);
  });

  testWidgets('the offline preview opens on sign-in with a LOCAL chip', (
    tester,
  ) async {
    preview.main();
    await tester.pumpAndSettle();

    expect(byKey('signIn.submit'), findsOneWidget);
    expect(find.text('LOCAL'), findsOneWidget);
  });

  test('secure storage keeps both tokens and clears them together', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureSessionStore();

    expect(await store.read(), isNull);
    await store.save(
      const StoredSession(accessToken: 'a1', refreshToken: 'r1'),
    );
    final saved = await store.read();
    expect(saved?.accessToken, 'a1');
    expect(saved?.refreshToken, 'r1');

    await store.clear();
    expect(await store.read(), isNull);
  });

  test('a half-written session counts as no session', () async {
    FlutterSecureStorage.setMockInitialValues({
      'raad.session.accessToken': 'a1',
    });
    expect(await SecureSessionStore().read(), isNull);
  });

  test('private records live in the secure store and can be removed', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureProtectedStore();
    expect(await store.read('raad.pending.dev.sub'), isNull);
    await store.write('raad.pending.dev.sub', '{"v":1}');
    expect(await store.read('raad.pending.dev.sub'), '{"v":1}');
    await store.delete('raad.pending.dev.sub');
    expect(await store.read('raad.pending.dev.sub'), isNull);
  });
}
