import '../model/market.dart';

/// Sabit kripto evreni. Kullanıcı kararıyla kilitlidir; bu liste dışında varlık taranmaz.
class CryptoUniverse {
  const CryptoUniverse._();

  static const List<Instrument> instruments = [
    Instrument.crypto('ONDOUSDT', name: 'Ondo'),
    Instrument.crypto('HBARUSDT', name: 'Hedera'),
    Instrument.crypto('BTCUSDT', name: 'Bitcoin'),
    Instrument.crypto('SIRENUSDT', name: 'Siren'),
    Instrument.crypto('XAGUSDT', name: 'Gümüş'),
    Instrument.crypto('LINKUSDT', name: 'Chainlink'),
    Instrument.crypto('SOLUSDT', name: 'Solana'),
    Instrument.crypto('PAXGUSDT', name: 'PAX Gold (altın)'),
    Instrument.crypto('XRPUSDT', name: 'XRP'),
    Instrument.crypto('ETHUSDT', name: 'Ethereum'),
  ];

  /// Piyasa rejimi için referans varlık.
  static const Instrument benchmark = Instrument.crypto('BTCUSDT', name: 'Bitcoin');

  /// Emtia vekili olan, kripto piyasasıyla düşük bağıntılı varlıklar.
  static const Set<String> commodityProxies = {'XAGUSDT', 'PAXGUSDT'};

  static bool contains(String symbol) => instruments.any((i) => i.symbol == symbol);
}
