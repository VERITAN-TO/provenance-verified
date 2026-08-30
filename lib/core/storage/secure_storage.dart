import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PvSecureStorage {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const _recentSearchesKey = 'pv_recent_searches';
  static const _receiptPrefix = 'pv_receipt_';

  Future<List<String>> getRecentSearches() async {
    final raw = await _storage.read(key: _recentSearchesKey);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').where((s) => s.isNotEmpty).toList();
  }

  Future<void> addRecentSearch(String publicId) async {
    final searches = await getRecentSearches();
    searches.remove(publicId);
    searches.insert(0, publicId);
    final trimmed = searches.take(10).toList();
    await _storage.write(key: _recentSearchesKey, value: trimmed.join(','));
  }

  Future<void> saveReceiptJson(String receiptId, String json) async {
    await _storage.write(key: '$_receiptPrefix$receiptId', value: json);
  }

  Future<String?> readReceiptJson(String receiptId) async {
    return _storage.read(key: '$_receiptPrefix$receiptId');
  }

  Future<void> deleteReceipt(String receiptId) async {
    await _storage.delete(key: '$_receiptPrefix$receiptId');
  }

  Future<List<String>> listReceiptIds() async {
    final all = await _storage.readAll();
    return all.keys
        .where((k) => k.startsWith(_receiptPrefix))
        .map((k) => k.replaceFirst(_receiptPrefix, ''))
        .toList();
  }
}
