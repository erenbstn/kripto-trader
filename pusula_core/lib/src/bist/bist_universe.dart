import '../model/candle.dart';
import '../model/market.dart';

/// BIST evreni: aday listesi + likidite süzgeci.
///
/// Aday listesi BIST 100 ağırlıklı, elle derlenmiş bir listedir ve endeks dönemlerinde
/// güncellenmelidir ([candidatesAsOf]). Listedeki bir sembol veri kaynağında bulunamazsa
/// (kod değişikliği, kottan çıkma) süzgeç onu "veri yok" gerekçesiyle eler; sistem çalışmaya devam eder.
class BistUniverse {
  const BistUniverse._();

  static const String candidatesAsOf = '2026-11';

  /// Piyasa rejimi için referans endeks.
  static const Instrument benchmark = Instrument.bist('XU100', name: 'BIST 100');

  /// Borsa İstanbul (BIST) hisse kataloğu: sembol → şirket adı.
  static const Map<String, String> stockNames = {
    'ADEL': 'Adel Kalemcilik',
    'ADGYO': 'Adra GYO',
    'AEFES': 'Anadolu Efes',
    'AFYON': 'Afyon Çimento',
    'AGESA': 'AgeSA Hayat Emeklilik',
    'AGHOL': 'AG Anadolu Grubu Holding',
    'AGROT': 'Agrotech Teknoloji',
    'AHGAZ': 'Ahlatcı Doğalgaz',
    'AKBNK': 'Akbank',
    'AKCNS': 'Akçansa Çimento',
    'AKFGY': 'Akfen GYO',
    'AKFYE': 'Akfen Yenilenebilir Enerji',
    'AKGRT': 'Aksigorta',
    'AKMGY': 'Akmerkez GYO',
    'AKSA': 'Aksa Akrilik',
    'AKSEN': 'Aksa Enerji',
    'AKSGY': 'Akiş GYO',
    'ALARK': 'Alarko Holding',
    'ALBRK': 'Albaraka Türk',
    'ALCAR': 'Alarko Carrier',
    'ALCTL': 'Alcatel-Lucent Teletaş',
    'ALFAS': 'Alfa Solar Enerji',
    'ALGYO': 'Alarko GYO',
    'ALKIM': 'Alkim Kimya',
    'ALTNY': 'Altınay Savunma',
    'ANHYT': 'Anadolu Hayat Emeklilik',
    'ANSGR': 'Anadolu Sigorta',
    'ARASE': 'Doğu Aras Enerji',
    'ARCLK': 'Arçelik',
    'ARDYZ': 'ARD Bilişim',
    'ARENA': 'Arena Bilgisayar',
    'ARSAN': 'Arsan Tekstil',
    'ASELS': 'Aselsan',
    'ASGYO': 'ASCE GYO',
    'ASTOR': 'Astor Enerji',
    'ASUZU': 'Anadolu Isuzu',
    'ATAKP': 'Atakey Patates',
    'ATATP': 'ATP Yazılım',
    'AVPGY': 'Avrupakent GYO',
    'AYDEM': 'Aydem Enerji',
    'AYEN': 'Ayen Enerji',
    'AYGAZ': 'Aygaz',
    'AZTEK': 'Aztek Teknoloji',
    'BAGFS': 'Bagfaş',
    'BAKAB': 'Bak Ambalaj',
    'BANVT': 'Banvit',
    'BARMA': 'Barem Ambalaj',
    'BASGZ': 'Başkent Doğalgaz',
    'BEGYO': 'Batı Ege GYO',
    'BERA': 'Bera Holding',
    'BIENY': 'Bien Yapı',
    'BIGCH': 'Big Chefs',
    'BIMAS': 'BİM Birleşik Mağazalar',
    'BIOEN': 'Biotrend Enerji',
    'BIZIM': 'Bizim Toptan',
    'BJKAS': 'Beşiktaş Futbol',
    'BLCYT': 'Bilici Yatırım',
    'BMSCH': 'BMS Çelik Hasır',
    'BNTAS': 'Bantaş Ambalaj',
    'BOBET': 'Boğaziçi Beton',
    'BORLS': 'Borlease Otomotiv',
    'BORSK': 'Bor Şeker',
    'BOSSA': 'Bossa',
    'BRISA': 'Brisa',
    'BRKSN': 'Berkosan',
    'BRKVY': 'Birikim Varlık',
    'BRSAN': 'Borusan Mannesmann',
    'BRYAT': 'Borusan Yatırım',
    'BTCIM': 'Batıçim',
    'BUCIM': 'Bursa Çimento',
    'BURCE': 'Burçelik',
    'BYDNR': 'Baydöner',
    'CANTE': 'Çan2 Termik',
    'CATES': 'Çates Elektrik',
    'CCOLA': 'Coca-Cola İçecek',
    'CEOEM': 'CEO Event Medya',
    'CIMSA': 'Çimsa Çimento',
    'CLEBI': 'Çelebi Hava Servisi',
    'CMBTN': 'Çimbeton',
    'CONSE': 'Consus Enerji',
    'CRFSA': 'CarrefourSA',
    'CUSAN': 'Çuhadaroğlu Metal',
    'CVKMD': 'CVK Maden',
    'CWENE': 'CW Enerji',
    'DAPGM': 'DAP Gayrimenkul',
    'DARDL': 'Dardanel',
    'DEVA': 'Deva Holding',
    'DGNMO': 'Doğanlar Mobilya',
    'DOAS': 'Doğuş Otomotiv',
    'DOFER': 'Dofer Yapı',
    'DOHOL': 'Doğan Holding',
    'DOKTA': 'Döktaş Dökümcülük',
    'DYOBY': 'DYO Boya',
    'EBEBK': 'ebebek Mağazacılık',
    'ECILC': 'Eczacıbaşı İlaç',
    'ECZYT': 'Eczacıbaşı Yatırım',
    'EDATA': 'E-Data Teknoloji',
    'EFORC': 'Efor Çay',
    'EGEEN': 'Ege Endüstri',
    'EGEPO': 'Nasmed Egepol',
    'EGGUB': 'Ege Gübre',
    'EGPRO': 'Ege Profil',
    'EGSER': 'Ege Seramik',
    'EKGYO': 'Emlak Konut GYO',
    'EKOS': 'EKOS Teknoloji',
    'ELITE': 'Elite Naturel',
    'EMKEL': 'Emek Elektrik',
    'ENERY': 'Enerya Enerji',
    'ENJSA': 'Enerjisa Enerji',
    'ENKAI': 'Enka İnşaat',
    'ENSRI': 'Ensari Deri',
    'ERBOS': 'Erbosan',
    'ERCB': 'Erciyas Çelik Boru',
    'EREGL': 'Ereğli Demir Çelik',
    'ESCAR': 'Escar Filo',
    'ESCOM': 'Escort Teknoloji',
    'ESEN': 'Esenboğa Elektrik',
    'EUPWR': 'Europower Enerji',
    'EUREN': 'Europen Endüstri',
    'EYGYO': 'EYG Gayrimenkul',
    'FENER': 'Fenerbahçe Futbol',
    'FLAP': 'Flap Kongre',
    'FMIZP': 'Federal-Mogul İzmit',
    'FONET': 'Fonet Bilgi Teknolojileri',
    'FORMT': 'Formet Metal',
    'FORTE': 'Forte Bilgi İletişim',
    'FRIGO': 'Frigo-Pak Gıda',
    'FROTO': 'Ford Otosan',
    'FZLGY': 'Fuzul GYO',
    'GARAN': 'Garanti BBVA',
    'GENIL': 'Gen İlaç',
    'GENTS': 'Gentaş',
    'GEREL': 'Gersan Elektrik',
    'GESAN': 'Girişim Elektrik',
    'GIPTA': 'Gıpta Ofis',
    'GLCVY': 'Gelecek Varlık',
    'GLYHO': 'Global Yatırım Holding',
    'GMTAS': 'Gimat Mağazacılık',
    'GOKNR': 'Göknur Gıda',
    'GOLTS': 'Göltaş Çimento',
    'GOODY': 'Goodyear',
    'GOZDE': 'Gözde Girişim',
    'GRSEL': 'Gür-Sel Turizm',
    'GRTHO': 'GrainTurk Holding',
    'GSDHO': 'GSD Holding',
    'GSRAY': 'Galatasaray Sportif',
    'GUBRF': 'Gübre Fabrikaları',
    'GWIND': 'Galata Wind Enerji',
    'GZNMI': 'Gezinomi',
    'HALKB': 'Halkbank',
    'HATSN': 'Hat-San Gemi',
    'HEDEF': 'Hedef Holding',
    'HEKTS': 'Hektaş',
    'HLGYO': 'Halk GYO',
    'HTTBT': 'Hitit Bilgisayar',
    'HUNER': 'Hun Yenilenebilir Enerji',
    'HURGZ': 'Hürriyet Gazetecilik',
    'ICBCT': 'ICBC Turkey Bank',
    'IEYHO': 'Işıklar Enerji',
    'IHAAS': 'İhlas Haber Ajansı',
    'IHLAS': 'İhlas Holding',
    'IMASM': 'İmaş Makina',
    'INDES': 'İndeks Bilgisayar',
    'INFO': 'İnfo Yatırım',
    'INGRM': 'Ingram Micro Bilişim',
    'INTEM': 'İntema',
    'INVEO': 'Inveo Yatırım',
    'INVES': 'Investco Holding',
    'IPEKE': 'İpek Doğal Enerji',
    'ISBIR': 'İşbir Holding',
    'ISCTR': 'İş Bankası (C)',
    'ISDMR': 'İskenderun Demir Çelik',
    'ISFIN': 'İş Finansal Kiralama',
    'ISGSY': 'İş Girişim',
    'ISGYO': 'İş GYO',
    'ISKPL': 'Işık Plastik',
    'ISMEN': 'İş Yatırım Menkul',
    'ISSEN': 'İşbir Sentetik',
    'IZENR': 'İzdemir Enerji',
    'IZFAS': 'İzmir Fırça',
    'IZMDC': 'İzmir Demir Çelik',
    'JANTS': 'Jantsa Jant',
    'KAPLM': 'Kaplamin',
    'KARSN': 'Karsan Otomotiv',
    'KARTN': 'Kartonsan',
    'KATMR': 'Katmerciler',
    'KAYSE': 'Kayseri Şeker',
    'KBORU': 'Kuzey Boru',
    'KCAER': 'Kocaer Çelik',
    'KCHOL': 'Koç Holding',
    'KERVT': 'Kerevitaş',
    'KFEIN': 'Kafein Yazılım',
    'KGYO': 'Koray GYO',
    'KIMMR': 'Ersan Alışveriş',
    'KLGYO': 'Kiler GYO',
    'KLKIM': 'Kalekim',
    'KLMSN': 'Klimasan',
    'KLNMA': 'Türkiye Kalkınma Bankası',
    'KLRHO': 'Kiler Holding',
    'KLSER': 'Kaleseramik',
    'KLSYN': 'Koleksiyon Mobilya',
    'KMPUR': 'Kimteks Poliüretan',
    'KNFRT': 'Konfrut Gıda',
    'KONKA': 'Konya Kağıt',
    'KONTR': 'Kontrolmatik',
    'KONYA': 'Konya Çimento',
    'KOPOL': 'Koza Polyester',
    'KORDS': 'Kordsa',
    'KOZAA': 'Koza Anadolu Metal',
    'KOZAL': 'Koza Altın',
    'KRDMA': 'Kardemir (A)',
    'KRDMB': 'Kardemir (B)',
    'KRDMD': 'Kardemir (D)',
    'KRGYO': 'Körfez GYO',
    'KRONT': 'Kron Teknoloji',
    'KRPLS': 'Koroplast',
    'KRSTL': 'Kristal Kola',
    'KRTEK': 'Karsu Tekstil',
    'KRVGD': 'Kervan Gıda',
    'KTLEV': 'Katılımevim',
    'KUTPO': 'Kütahya Porselen',
    'KUVVA': 'Kuvva Gıda',
    'KUYAS': 'Kuyaş Yatırım',
    'KZBGY': 'Kızılbük GYO',
    'KZGYO': 'Kuzugrup GYO',
    'LIDER': 'LDR Turizm',
    'LILAK': 'Lila Kağıt',
    'LINK': 'Link Bilgisayar',
    'LKMNH': 'Lokman Hekim',
    'LMKDC': 'Limak Doğu Anadolu Çimento',
    'LOGO': 'Logo Yazılım',
    'LRSHO': 'Loras Holding',
    'LUKSK': 'Lüks Kadife',
    'MAALT': 'Marmaris Altınyunus',
    'MACKO': 'Mackolik',
    'MAGEN': 'Margün Enerji',
    'MAKIM': 'Makim Makine',
    'MAKTK': 'Makina Takım',
    'MANAS': 'Manas Enerji',
    'MARBL': 'Tureks Turunç Madencilik',
    'MARTI': 'Martı Otel',
    'MAVI': 'Mavi Giyim',
    'MEDTR': 'Meditera Tıbbi Malzeme',
    'MEGAP': 'Mega Polietilen',
    'MEGMT': 'Mega Metal',
    'MEKAG': 'Meka Beton',
    'MERCN': 'Mercan Kimya',
    'MERIT': 'Merit Turizm',
    'METUR': 'Metemtur',
    'MGROS': 'Migros Ticaret',
    'MHRGY': 'MHR GYO',
    'MIATK': 'MIA Teknoloji',
    'MNDRS': 'Menderes Tekstil',
    'MNDTR': 'Mondi Turkey',
    'MOBTL': 'Mobiltel İletişim',
    'MOGAN': 'Mogan Enerji',
    'MPARK': 'MLP Sağlık (Medical Park)',
    'MRGYO': 'Martı GYO',
    'MRSHL': 'Marshall Boya',
    'MSGYO': 'Mistral GYO',
    'MTRKS': 'Matriks Bilgi Dağıtım',
    'MTRYO': 'Metro Yatırım Ort.',
    'NATEN': 'Naturel Enerji',
    'NETAS': 'Netaş Telekom',
    'NIBAS': 'Niğbaş',
    'NTGAZ': 'Naturelgaz',
    'NTHOL': 'Net Holding',
    'NUGYO': 'Nurol GYO',
    'NUHCM': 'Nuh Çimento',
    'OBAMS': 'Oba Makarnacılık',
    'OBASE': 'Obase Bilgisayar',
    'ODAS': 'Odaş Elektrik',
    'OFSYM': 'Ofis Yem',
    'ONCSM': 'Oncosem Onkoloji',
    'ORGE': 'Orge Enerji',
    'OSMEN': 'Osmanlı Yatırım',
    'OTKAR': 'Otokar',
    'OYAKC': 'Oyak Çimento',
    'OYLUM': 'Oylum Sınai',
    'OYYAT': 'Oyak Yatırım',
    'OZGYO': 'Özderici GYO',
    'OZKGY': 'Özak GYO',
    'OZRDN': 'Özerden Ambalaj',
    'OZSUB': 'Özsu Balık',
    'PAGYO': 'Panora GYO',
    'PAMEL': 'Pamel Yenilenebilir',
    'PAPIL': 'Papilon Savunma',
    'PARSN': 'Parsan',
    'PASEU': 'Pasifik Eurasia',
    'PATEK': 'Pasifik Teknoloji',
    'PCILT': 'PC İletişim',
    'PEHOL': 'Pera Yatırım Holding',
    'PEKGY': 'Peker GYO',
    'PENGD': 'Penguen Gıda',
    'PENTA': 'Penta Teknoloji',
    'PETKM': 'Petkim',
    'PETUN': 'Pınar Et ve Un',
    'PGSUS': 'Pegasus',
    'PINSU': 'Pınar Su',
    'PKART': 'Plastikkart',
    'PKENT': 'Petrokent Turizm',
    'PLTUR': 'Platform Turizm',
    'PNLSN': 'Panelsan Çatı',
    'PNSUT': 'Pınar Süt',
    'POLHO': 'Polisan Holding',
    'POLTK': 'Politeknik Metal',
    'PRDGS': 'Pardus Girişim',
    'PRKAB': 'Türk Prysmian Kablo',
    'PRKME': 'Park Elektrik',
    'PRZMA': 'Prizma Pres',
    'PSDTC': 'Pergamon Status',
    'PSGYO': 'Pasifik GYO',
    'QUAGR': 'QUA Granite',
    'RALYH': 'Ral Yatırım Holding',
    'RAYSG': 'Ray Sigorta',
    'REEDR': 'Reeder Teknoloji',
    'RGYAS': 'Rönesans GYO',
    'RNPOL': 'Rainbow Polikarbonat',
    'RODRG': 'Rodrigo Tekstil',
    'RTALB': 'RTA Laboratuvarları',
    'RUBNS': 'Rubenis Tekstil',
    'RYGYO': 'Reysaş GYO',
    'RYSAS': 'Reysaş Lojistik',
    'SAFKR': 'Safkar',
    'SAHOL': 'Sabancı Holding',
    'SAMAT': 'Saray Matbaacılık',
    'SANEL': 'San-El Mühendislik',
    'SANFM': 'Sanifoam Endüstri',
    'SANKO': 'Sanko Pazarlama',
    'SARKY': 'Sarkuysan',
    'SASA': 'SASA Polyester',
    'SAYAS': 'Say Yenilenebilir',
    'SDTTR': 'SDT Uzay ve Savunma',
    'SEGYO': 'Şeker GYO',
    'SEKFK': 'Şeker Finansal',
    'SELEC': 'Selçuk Ecza Deposu',
    'SELGD': 'Selçuk Gıda',
    'SELVA': 'Selva Gıda',
    'SEYKM': 'Seyitler Kimya',
    'SILVR': 'Silverline',
    'SISE': 'Şişecam',
    'SKBNK': 'Şekerbank',
    'SKTAS': 'Söktaş',
    'SKYLP': 'Skyalp Finansal',
    'SMART': 'Smartiks Yazılım',
    'SMRTG': 'Smart Güneş Enerjisi',
    'SNGYO': 'Sinpaş GYO',
    'SNKRN': 'Senkron Güvenlik',
    'SNPAM': 'Sönmez Pamuklu',
    'SOKE': 'Söke Değirmencilik',
    'SOKM': 'Şok Marketler',
    'SONME': 'Sönmez Filament',
    'SRVGY': 'Servet GYO',
    'SUMAS': 'Sumaş Suni Tahta',
    'SUNTK': 'Sun Tekstil',
    'SURGY': 'Sur Tatil Evleri GYO',
    'SUWEN': 'Suwen Tekstil',
    'TABGD': 'TAB Gıda',
    'TARKM': 'Tarkim Bitki Koruma',
    'TATEN': 'Tatlıpınar Enerji',
    'TATGD': 'Tat Gıda',
    'TAVHL': 'TAV Havalimanları',
    'TBORG': 'Türk Tuborg',
    'TCELL': 'Turkcell',
    'TDGYO': 'Trend GYO',
    'TEKTU': 'Tek-Art Turizm',
    'TERA': 'Tera Yatırım',
    'TETMT': 'Tetamat Gıda',
    'TEZOL': 'Europap Tezol',
    'TGSAS': 'TGS Dış Ticaret',
    'THYAO': 'Türk Hava Yolları',
    'TKFEN': 'Tekfen Holding',
    'TKNSA': 'Teknosa',
    'TLMAN': 'Trabzon Liman',
    'TMPOL': 'Temapol Polimer',
    'TMSN': 'Tümosan',
    'TNZTP': 'Tapdi Oksijen',
    'TOASO': 'Tofaş Oto Fabrika',
    'TRCAS': 'Turcas Petrol',
    'TRGYO': 'Torunlar GYO',
    'TRILC': 'Türk İlaç ve Serum',
    'TSGYO': 'TSKB GYO',
    'TSKB': 'TSKB',
    'TSPOR': 'Trabzonspor Sportif',
    'TTKOM': 'Türk Telekom',
    'TTRAK': 'Türk Traktör',
    'TUCLK': 'Tuğçelik',
    'TUKAS': 'Tukaş',
    'TUPRS': 'Tüpraş',
    'TUREX': 'Tureks Turizm',
    'TURSG': 'Türkiye Sigorta',
    'ULAS': 'Ulaşlar Turizm',
    'ULKER': 'Ülker Bisküvi',
    'ULUFA': 'Ulusal Faktoring',
    'ULUSE': 'Ulusoy Elektrik',
    'ULUUN': 'Ulusoy Un',
    'UNLU': 'Ünlü Yatırım',
    'USAK': 'Uşak Seramik',
    'VAKBN': 'VakıfBank',
    'VAKFN': 'Vakıf Finansal',
    'VAKKO': 'Vakko Tekstil',
    'VANGD': 'Vanet Gıda',
    'VBTYZ': 'VBT Yazılım',
    'VERTU': 'Verusaturk Girişim',
    'VERUS': 'Verusa Holding',
    'VESBE': 'Vestel Beyaz Eşya',
    'VESTL': 'Vestel Elektronik',
    'VKGYO': 'Vakıf GYO',
    'VRGYO': 'Vera Konsept GYO',
    'YAPRK': 'Yaprak Süt',
    'YATAS': 'Yataş',
    'YAYLA': 'Yayla Enerji',
    'YBTAS': 'Yibitaş',
    'YEOTK': 'YEO Teknoloji',
    'YESIL': 'Yeşil Yatırım',
    'YGGYO': 'Yeni Gimat GYO',
    'YGYO': 'Yeşil GYO',
    'YKBNK': 'Yapı Kredi Bankası',
    'YKSLN': 'Yükselen Çelik',
    'YUNSA': 'Yünsa',
    'YYAPI': 'Yeşil Yapı',
    'YYLGD': 'Yayla Agro Gıda',
    'ZOREN': 'Zorlu Enerji',
    'ZRGYO': 'Ziraat GYO',
  };

  static final List<String> candidateSymbols = List<String>.unmodifiable(stockNames.keys);

  static String normalizeSymbol(String symbol) {
    var clean = symbol.trim().toUpperCase();
    if (clean.endsWith('.IS') && clean.length > 3) {
      clean = clean.substring(0, clean.length - 3);
    }
    return clean;
  }

  static String? nameOf(String symbol) => stockNames[normalizeSymbol(symbol)];

  static Instrument instrumentFor(String symbol) {
    final clean = normalizeSymbol(symbol);
    return Instrument.bist(clean, name: stockNames[clean] ?? clean);
  }

  static List<Instrument> get candidates => [
        for (final e in stockNames.entries) Instrument.bist(e.key, name: e.value),
      ];
}

class UniverseRejection {
  const UniverseRejection(this.symbol, this.reason);
  final String symbol;
  final String reason;
}

class UniverseSelection {
  const UniverseSelection({required this.selected, required this.rejected, required this.turnover});
  final List<Instrument> selected;
  final List<UniverseRejection> rejected;

  /// Seçilenlerin 20 günlük ortalama işlem hacmi (TL).
  final Map<String, double> turnover;
}

/// Likidite süzgeci. Gecikmeli veriyle makul giriş yalnızca derin tahtalarda mümkün olduğu için
/// en yüksek işlem hacimli hisseler tutulur.
class BistUniverseFilter {
  const BistUniverseFilter({
    this.topN = 40,
    this.minAvgTurnoverTry = 300e6,
    this.minBars = 60,
    this.lookback = 20,
    this.maxLimitDays = 5,
    this.limitMovePct = 9.5,
    this.maxStaleDays = 6,
  });

  final int topN;
  final double minAvgTurnoverTry;
  final int minBars;
  final int lookback;

  /// Son [lookback] günde bu sayıdan fazla tavan/taban günü olan hisse elenir.
  final int maxLimitDays;
  final double limitMovePct;

  /// Son mum bu kadar takvim gününden eskiyse veri bayat sayılır.
  final int maxStaleDays;

  UniverseSelection select(Map<String, List<Candle>> dailyBySymbol, {required DateTime now}) {
    final rejected = <UniverseRejection>[];
    final turnover = <String, double>{};
    for (final sym in dailyBySymbol.keys) {
      final bars = dailyBySymbol[sym]!;
      if (bars.isEmpty) {
        rejected.add(UniverseRejection(sym, 'veri yok'));
        continue;
      }
      if (bars.length < minBars) {
        rejected.add(UniverseRejection(sym, 'yetersiz geçmiş (${bars.length} < $minBars gün)'));
        continue;
      }
      final ageDays = now.toUtc().difference(bars.last.openTime).inDays;
      if (ageDays > maxStaleDays) {
        rejected.add(UniverseRejection(sym, 'veri bayat ($ageDays gün)'));
        continue;
      }
      final recent = bars.sublist(bars.length - lookback);
      final avg = recent.fold<double>(0, (s, b) => s + b.quoteVolume) / recent.length;
      var limitDays = 0;
      for (var i = bars.length - lookback; i < bars.length; i++) {
        final prev = bars[i - 1].close;
        if (prev > 0 && ((bars[i].close / prev - 1).abs() * 100) >= limitMovePct) limitDays++;
      }
      if (limitDays > maxLimitDays) {
        rejected.add(UniverseRejection(sym, 'son $lookback günde $limitDays tavan/taban günü'));
        continue;
      }
      if (avg < minAvgTurnoverTry) {
        rejected.add(UniverseRejection(sym, 'düşük likidite (${(avg / 1e6).toStringAsFixed(0)} mn TL/gün)'));
        continue;
      }
      turnover[sym] = avg;
    }
    final ranked = turnover.keys.toList()..sort((a, b) => turnover[b]!.compareTo(turnover[a]!));
    for (final sym in ranked.skip(topN)) {
      rejected.add(UniverseRejection(sym, 'ilk $topN dışında'));
    }
    final keep = ranked.take(topN).toList();
    return UniverseSelection(
      selected: [for (final s in keep) Instrument.bist(s)],
      rejected: rejected,
      turnover: {for (final s in keep) s: turnover[s]!},
    );
  }
}
