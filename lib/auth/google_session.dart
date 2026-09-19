import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GoogleSession extends ChangeNotifier {
  static const serverClientId =
      '863353284554-ph5l416ufjj2s7g0l3om594ldq2qmnvq.apps.googleusercontent.com';
  static const apiBase = String.fromEnvironment('SEEP_API_URL',
      defaultValue: 'https://whats-for-dinner-k4u8.onrender.com');
  static Future<void>? _sdkReady;
  static const _profileKey = 'seep.google.profile.v1';
  final SharedPreferences preferences;
  final http.Client _client = http.Client();
  Map<String, dynamic>? user;
  bool busy = false;
  bool verified = false;
  String? errorKey;
  String? _token;
  DateTime? _expires;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _refresh;

  GoogleSession(this.preferences);
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  String? get email => user?['email'] as String?;
  String? get subject => user?['googleSubject'] as String?;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (!supported) return;
    final generation = _generation;
    try {
      final saved = preferences.getString(_profileKey);
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        if (data['email'] is String && data['googleSubject'] is String) {
          user = data;
        }
      }
      _changed();
      await _ensureSdk();
      await _restore(generation);
    } catch (_) {
      if (_disposed || generation != _generation) return;
      // Cached profile allows offline play/queuing, never authenticates uploads.
      verified = false;
      _changed();
    }
  }

  Future<void> _ensureSdk() => _sdkReady ??=
      GoogleSignIn.instance.initialize(serverClientId: serverClientId);

  Future<void> _restore(int generation) async {
    if (_disposed || generation != _generation) return;
    final account =
        await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (account != null) await _verify(account, generation);
  }

  Future<void> signIn() async {
    if (!supported || busy) return;
    busy = true;
    errorKey = null;
    _changed();
    final generation = ++_generation;
    try {
      await _ensureSdk();
      final account = await GoogleSignIn.instance.authenticate();
      await _verify(account, generation);
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        errorKey = 'login_failed';
      }
    } catch (_) {
      errorKey = 'login_verify_failed';
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> _verify(GoogleSignInAccount account, int generation) async {
    if (_disposed || generation != _generation) return;
    if (Uri.parse(apiBase).scheme != 'https') {
      throw StateError('Google verification requires HTTPS');
    }
    final token = account.authentication.idToken;
    if (token == null) throw StateError('Missing Google ID token');
    final response = await _client
        .post(Uri.parse('$apiBase/api/seep/auth/google'), headers: {
      'Authorization': 'Bearer $token'
    }).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw StateError('Sign-in verification failed');
    }
    final profile = (jsonDecode(response.body) as Map)['user'];
    if (profile is! Map ||
        profile['id'] is! String ||
        profile['email'] is! String ||
        profile['googleSubject'] != account.id) {
      throw StateError('Invalid profile');
    }
    // Token payload is used only to schedule refresh. Backend verification above
    // is the trust boundary; a locally decoded token is never trusted as login.
    final payload = jsonDecode(utf8.decode(
        base64Url.decode(base64Url.normalize(token.split('.')[1])))) as Map;
    if (_disposed || generation != _generation) return;
    user = Map<String, dynamic>.from(profile);
    _token = token;
    _expires =
        DateTime.fromMillisecondsSinceEpoch((payload['exp'] as int) * 1000);
    verified = true;
    await preferences.setString(_profileKey, jsonEncode(user));
    _changed();
  }

  Future<Map<String, String>?> headersFor(Map<String, dynamic> report) async {
    if (_disposed || busy || subject == null) return null;
    final generation = _generation;
    final owner = report['user'] as Map?;
    if (owner?['googleSubject'] != subject || owner?['email'] != email) {
      return null;
    }
    if (_token == null ||
        _expires == null ||
        _expires!.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      try {
        await _ensureSdk();
        await (_refresh ??=
            _restore(generation).whenComplete(() => _refresh = null));
      } catch (_) {
        if (_disposed || generation != _generation) return null;
        verified = false;
        errorKey = 'login_again';
        _changed();
        return null;
      }
    }
    if (_disposed ||
        generation != _generation ||
        owner?['googleSubject'] != subject ||
        owner?['email'] != email ||
        _token == null ||
        _expires == null ||
        _expires!.isBefore(DateTime.now())) {
      if (!_disposed && subject != null) {
        verified = false;
        errorKey = 'login_again';
        _changed();
      }
      return null;
    }
    return {'Authorization': 'Bearer $_token'};
  }

  Future<void> signOut() async {
    ++_generation;
    user = null;
    _token = null;
    _expires = null;
    verified = false;
    errorKey = null;
    _changed();
    await preferences.remove(_profileKey);
    try {
      await _ensureSdk();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  void sessionRejected() {
    _token = null;
    _expires = null;
    verified = false;
    errorKey = 'login_again';
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _client.close();
    super.dispose();
  }
}
