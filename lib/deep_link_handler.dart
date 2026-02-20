import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'api.dart';

class DeepLinkHandler {
  DeepLinkHandler._();
  static final DeepLinkHandler instance = DeepLinkHandler._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Future<void> start({
    required void Function() onAuthed,
    required void Function(String err) onError,
  }) async {
    // Handle cold start link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        await _handle(initialLink, onAuthed, onError);
      }
    } catch (e) {
      onError('$e');
    }

    // Handle links while app is running
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri, onAuthed, onError),
      onError: (e) => onError('$e'),
    );
  }

  Future<void> _handle(
    Uri uri,
    void Function() onAuthed,
    void Function(String err) onError,
  ) async {
    debugPrint('Deep link received: $uri');

    // Expect: coachstack://auth?token=ml_...
    if (uri.scheme != 'coachstack' || uri.host != 'auth') {
      debugPrint('Deep link ignored (scheme/host mismatch)');
      return;
    }

    final token = uri.queryParameters['token'];
    if (token == null || !token.startsWith('ml_')) {
      debugPrint('Deep link ignored (missing/invalid token)');
      return;
    }

    debugPrint('Verifying magic token: ${token.substring(0, 6)}...');

    try {
      await Api.instance.verifyMagicToken(token);
      debugPrint('Magic token verified ✅');
      onAuthed();
    } catch (e) {
      debugPrint('Magic token verify failed ❌: $e');
      onError('$e');
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}