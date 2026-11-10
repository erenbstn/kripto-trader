import 'dart:convert';

import '../data/http_fetcher.dart';
import '../model/market.dart';

/// Tek bir haber başlığı ve tespit edilen etiketler.
class NewsHeadline {
  const NewsHeadline({
    required this.source,
    required this.title,
    this.summary = '',
    this.dangerTags = const [],
    this.positiveTags = const [],
  });

  final String source;
  final String title;
  final String summary;
  final List<String> dangerTags;
  final List<String> positiveTags;

  Map<String, Object?> toJson() => {
        'source': source,
        'title': title,
        'summary': summary,
        'dangerTags': dangerTags,
        'positiveTags': positiveTags,
      };
}

/// Haber ve duyarlılık değerlendirme sonucu.
class NewsReport {
  const NewsReport({
    required this.instrument,
    required this.veto,
    required this.vetoReason,
    required this.sentimentScore,
    required this.matchedHeadlines,
    this.fearGreedValue,
    this.fearGreedLabel,
  });

  final Instrument instrument;
  final bool veto;
  final String vetoReason;
  final int sentimentScore;
  final List<NewsHeadline> matchedHeadlines;
  final int? fearGreedValue;
  final String? fearGreedLabel;
}

/// Haber/olay vetosu ve duyarlılık analizcisi.
///
/// K7 / R3: Yanlış pozitif üreten genel kelimeler (`link`, `sol`, `gold`, `eth`, `default`)
/// daraltılmıştır. Yalnızca varlık adı veya açık sembol bağlamı eşleşir.
class NewsAnalyzer {
  const NewsAnalyzer({this.http});

  final HttpFetcher? http;

  static const List<(String, String)> cryptoRssFeeds = [
    ('CoinTelegraph', 'https://cointelegraph.com/rss'),
    ('CoinDesk', 'https://www.coindesk.com/arc/outboundfeeds/rss/'),
  ];

  static const String fearGreedUrl = 'https://api.alternative.me/fng/?limit=1';

  /// Daraltılmış kripto varlık eşleşme kalıpları (R3 düzeltmesi).
  /// `link`, `sol`, `gold`, `eth` gibi tek başına genel kelimeler eşleşmez.
  static final Map<String, List<RegExp>> _cryptoPatterns = {
    'ONDO': [
      RegExp(r'\bondo\s+(?:finance|token|coin|dao)\b', caseSensitive: false),
      RegExp(r'(?:\$ondo\b|\bondousdt\b)', caseSensitive: false),
    ],
    'HBAR': [
      RegExp(r'\b(?:hedera|hbar|hbarusdt)\b', caseSensitive: false),
      RegExp(r'\$hbar\b', caseSensitive: false),
    ],
    'BTC': [
      RegExp(r'\b(?:bitcoin|btc|btcusdt)\b', caseSensitive: false),
      RegExp(r'\$btc\b', caseSensitive: false),
    ],
    'SIREN': [
      RegExp(r'\b(?:siren\s+protocol|sirenprotocol|siren\s+token|sirenusdt)\b', caseSensitive: false),
      RegExp(r'\$siren\b', caseSensitive: false),
    ],
    'XAG': [
      RegExp(r'\b(?:xagusdt|xag/usd|silver\s+futures|silver\s+perpetual)\b', caseSensitive: false),
    ],
    'LINK': [
      RegExp(r'\b(?:chainlink|link\s+token|link\s+coin|linkusdt)\b', caseSensitive: false),
      RegExp(r'\$link\b', caseSensitive: false),
    ],
    'SOL': [
      RegExp(r'\b(?:solana|sol\s+token|sol\s+coin|sol\s+network|solusdt)\b', caseSensitive: false),
      RegExp(r'\$sol\b', caseSensitive: false),
    ],
    'PAXG': [
      RegExp(r'\b(?:pax\s+gold|paxos\s+gold|paxg|paxgusdt)\b', caseSensitive: false),
      RegExp(r'\$paxg\b', caseSensitive: false),
    ],
    'XRP': [
      RegExp(r'\b(?:xrp|ripple|xrpusdt)\b', caseSensitive: false),
      RegExp(r'\$xrp\b', caseSensitive: false),
    ],
    'ETH': [
      RegExp(r'\b(?:ethereum|ether\s+token|eth\s+token|eth\s+network|eth\s+etf|ethusdt)\b', caseSensitive: false),
      RegExp(r'\$eth\b', caseSensitive: false),
    ],
  };

  /// Kripto ve BIST için kritik tehlike kalıpları (`default` tek başına çıkarıldı, R3).
  static final List<(String, RegExp)> _dangerPatterns = [
    (
      'hack_exploit',
      RegExp(
        r'\bhack(?:ed|s|ing)?\b|\bexploit(?:ed|s)?\b|\bdrained\b|\bstolen\b|\bbridge\s+attack\b',
        caseSensitive: false,
      ),
    ),
    (
      'delist_halt',
      RegExp(
        r'\bdelist(?:ed|ing|s)?\b|\btrading\s+halt(?:ed)?\b|\bsuspend(?:ed|s)?\s+withdrawals\b|'
        r'işlem\s+sırası\s+kapat|kottan\s+çıkar',
        caseSensitive: false,
      ),
    ),
    (
      'insolvency',
      RegExp(
        r'\bbankrupt(?:cy)?\b|\binsolven(?:t|cy)\b|\b(?:debt|loan|bond)\s+default(?:ed)?\b|'
        r'\biflas\b|\bkonkordato\b|\bfaaliyet\s+durdur',
        caseSensitive: false,
      ),
    ),
    (
      'regulatory_ban',
      RegExp(
        r'\bsec\s+charges\b|\bdoj\s+indictment\b|\bfraud\s+charges\b|\bspk\s+işlem\s+yasağı\b',
        caseSensitive: false,
      ),
    ),
  ];

  static final List<(String, RegExp)> _positivePatterns = [
    (
      'etf_institutional',
      RegExp(
        r'\betf\s+(?:inflow|approval|approved|filing)\b|\binstitutional\s+adoption\b|\btemettü\s+dağıtım\b',
        caseSensitive: false,
      ),
    ),
    (
      'partnership_upgrade',
      RegExp(
        r'\bpartnership\b|\bmainnet\s+launch\b|\bnetwork\s+upgrade\b|\byeni\s+iş\s+ilişkisi\b|\bihale\s+kazan',
        caseSensitive: false,
      ),
    ),
  ];

  /// Bir metnin verilen varlıkla ilgili olup olmadığını daraltılmış kurallarla denetler.
  static bool matchesInstrument(Instrument instrument, String text) {
    if (instrument.market == Market.crypto) {
      final base = instrument.short.toUpperCase();
      final regs = _cryptoPatterns[base] ??
          [RegExp('\\b${RegExp.escape(base.toLowerCase())}\\b', caseSensitive: false)];
      return regs.any((r) => r.hasMatch(text));
    }
    // BIST: tam sembol kodu (örn. THYAO, ASELS) veya şirket adı
    final symRx = RegExp('\\b${RegExp.escape(instrument.symbol)}\\b', caseSensitive: false);
    if (symRx.hasMatch(text)) return true;
    if (instrument.name.trim().length >= 4) {
      final nameRx = RegExp('\\b${RegExp.escape(instrument.name.trim())}\\b', caseSensitive: false);
      if (nameRx.hasMatch(text)) return true;
    }
    return false;
  }

  /// Verilen başlık listesini değerlendirir (ağsız, birim test dostu).
  NewsReport evaluateHeadlines(
    Instrument instrument,
    List<({String source, String title, String summary})> rawItems, {
    int? fearGreedValue,
    String? fearGreedLabel,
  }) {
    final matched = <NewsHeadline>[];
    final dangerHits = <NewsHeadline>[];
    final positiveHits = <NewsHeadline>[];

    for (final it in rawItems) {
      final fullText = '${it.title} ${it.summary}';
      if (!matchesInstrument(instrument, fullText)) continue;

      final dTags = <String>[
        for (final (label, rx) in _dangerPatterns)
          if (rx.hasMatch(fullText)) label,
      ];
      final pTags = <String>[
        for (final (label, rx) in _positivePatterns)
          if (rx.hasMatch(fullText)) label,
      ];

      final h = NewsHeadline(
        source: it.source,
        title: it.title,
        summary: it.summary,
        dangerTags: dTags,
        positiveTags: pTags,
      );
      matched.add(h);
      if (dTags.isNotEmpty) dangerHits.add(h);
      if (pTags.isNotEmpty) positiveHits.add(h);
    }

    final veto = dangerHits.isNotEmpty;
    var vetoReason = '';
    if (veto) {
      final first = dangerHits.first;
      vetoReason = 'Kritik riskli haber (${first.dangerTags.join(', ')}): ${first.title}';
    }

    var sentiment = 0;
    if (positiveHits.isNotEmpty) {
      sentiment += (positiveHits.length * 15).clamp(0, 30);
    }
    if (dangerHits.isNotEmpty) {
      sentiment -= 100;
    }

    return NewsReport(
      instrument: instrument,
      veto: veto,
      vetoReason: vetoReason,
      sentimentScore: sentiment,
      matchedHeadlines: matched.take(5).toList(),
      fearGreedValue: fearGreedValue,
      fearGreedLabel: fearGreedLabel,
    );
  }

  /// `HttpFetcher` üzerinden RSS ve Korku/Açgözlülük verisini çekip değerlendirir.
  /// Ağ hatasında işlemi bloke etmez, temiz/nötr rapor döndürür.
  Future<NewsReport> fetchAndEvaluate(Instrument instrument) async {
    final fetcher = http;
    if (fetcher == null) {
      return evaluateHeadlines(instrument, const []);
    }

    final items = <({String source, String title, String summary})>[];
    int? fngVal;
    String? fngCls;

    if (instrument.market == Market.crypto) {
      for (final (srcName, url) in cryptoRssFeeds) {
        try {
          final xml = await fetcher.getText(Uri.parse(url), timeout: const Duration(seconds: 8));
          items.addAll(parseSimpleRss(srcName, xml));
        } catch (_) {
          // RSS kaynağı erişilemezse diğerine geç
        }
      }
      try {
        final fngRaw = await fetcher.getText(Uri.parse(fearGreedUrl), timeout: const Duration(seconds: 6));
        final doc = jsonDecode(fngRaw);
        if (doc is Map && doc['data'] is List && (doc['data'] as List).isNotEmpty) {
          final d0 = (doc['data'] as List).first as Map;
          fngVal = int.tryParse('${d0['value']}');
          fngCls = d0['value_classification'] as String?;
        }
      } catch (_) {}
    }

    return evaluateHeadlines(
      instrument,
      items,
      fearGreedValue: fngVal,
      fearGreedLabel: fngCls,
    );
  }

  /// Harici XML paketine ihtiyaç duymadan RSS `<item>` başlık ve özetlerini ayıklar.
  static List<({String source, String title, String summary})> parseSimpleRss(String source, String xml) {
    final out = <({String source, String title, String summary})>[];
    final itemRx = RegExp(r'<item\b[^>]*>([\s\S]*?)</item>', caseSensitive: false);
    final titleRx = RegExp(r'<title[^>]*>(?:<!\[CDATA\[([\s\S]*?)\]\]>|([\s\S]*?))</title>', caseSensitive: false);
    final descRx =
        RegExp(r'<description[^>]*>(?:<!\[CDATA\[([\s\S]*?)\]\]>|([\s\S]*?))</description>', caseSensitive: false);

    for (final m in itemRx.allMatches(xml).take(25)) {
      final block = m.group(1) ?? '';
      final tm = titleRx.firstMatch(block);
      if (tm == null) continue;
      final title = (tm.group(1) ?? tm.group(2) ?? '').trim();
      if (title.isEmpty) continue;
      final dm = descRx.firstMatch(block);
      final desc = (dm?.group(1) ?? dm?.group(2) ?? '').trim();
      out.add((
        source: source,
        title: title,
        summary: desc.length > 240 ? desc.substring(0, 240) : desc,
      ));
    }
    return out;
  }
}
