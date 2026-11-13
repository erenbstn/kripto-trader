/// HTTP katmanı hatası. `status` ağ hatasında null olur.
class HttpFetchException implements Exception {
  HttpFetchException(this.message, {this.status});
  final String message;
  final int? status;

  bool get isRateLimited => status == 429;
  bool get isNotFound => status == 400 || status == 404;

  @override
  String toString() => 'HttpFetchException(${status ?? 'ağ'}): $message';
}

/// Sağlayıcının anlamlı veri döndürememesi (boş yanıt, biçim değişikliği, desteklenmeyen istek).
class ProviderException implements Exception {
  ProviderException(this.providerId, this.message, {this.rateLimited = false});
  final String providerId;
  final String message;
  final bool rateLimited;

  @override
  String toString() => '$providerId: $message';
}

/// Hiçbir sağlayıcıdan ve önbellekten veri alınamadı.
class MarketDataException implements Exception {
  MarketDataException(this.instrumentId, this.reasons);
  final String instrumentId;

  /// sağlayıcı kimliği -> neden.
  final Map<String, String> reasons;

  @override
  String toString() => 'Veri alınamadı ($instrumentId): '
      '${reasons.entries.map((e) => '${e.key}: ${e.value}').join(' | ')}';
}
