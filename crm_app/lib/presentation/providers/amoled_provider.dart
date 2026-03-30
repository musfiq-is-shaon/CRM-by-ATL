import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// OLED pitch-black scaffold when combined with dark mode.
class AmoledNotifier extends StateNotifier<bool> {
  AmoledNotifier()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        ),
        super(false);

  final FlutterSecureStorage _storage;
  static const String _key = 'amoled_black';
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    final v = await _storage.read(key: _key);
    state = v == 'true';
    _ready = true;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    await _storage.write(key: _key, value: value.toString());
  }
}

final amoledDarkProvider =
    StateNotifierProvider<AmoledNotifier, bool>((ref) {
  return AmoledNotifier();
});
