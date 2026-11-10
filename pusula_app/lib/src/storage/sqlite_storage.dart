import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pusula_core/pusula_core.dart';
import 'package:sqflite/sqflite.dart';

import 'app_settings.dart';

/// Uygulamanın tüm kalıcı depolarını bir arada tutan sarmalayıcı.
class StorageBundle {
  const StorageBundle({
    required this.candleCache,
    required this.journalStore,
    required this.reportStore,
    required this.settingsStore,
    required this.isPersistentSqlite,
  });

  final CandleCache candleCache;
  final SignalJournalStore journalStore;
  final WeeklyReportStore reportStore;
  final SettingsStore settingsStore;
  final bool isPersistentSqlite;

  factory StorageBundle.inMemory() => StorageBundle(
        candleCache: MemoryCandleCache(),
        journalStore: MemorySignalJournalStore(),
        reportStore: MemoryWeeklyReportStore(),
        settingsStore: MemorySettingsStore(),
        isPersistentSqlite: false,
      );

  /// Android cihazda SQLite veritabanını açar; Web önizlemesinde veya masaüstü testte
  /// güvenli biçimde bellek içi depolara düşer.
  static Future<StorageBundle> open() async {
    if (kIsWeb) {
      return StorageBundle.inMemory();
    }
    try {
      final dbDir = await getDatabasesPath();
      final dbPath = p.join(dbDir, 'pusula_local.db');
      final db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE candle_cache (
              cache_key TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE signal_journal (
              id TEXT PRIMARY KEY,
              market TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              is_active INTEGER NOT NULL,
              is_weekly INTEGER NOT NULL,
              payload TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE weekly_reports (
              id TEXT PRIMARY KEY,
              generated_at INTEGER NOT NULL,
              payload TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE app_settings (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              payload TEXT NOT NULL
            )
          ''');
        },
      );
      return StorageBundle(
        candleCache: SqliteCandleCache(db),
        journalStore: SqliteSignalJournalStore(db),
        reportStore: SqliteWeeklyReportStore(db),
        settingsStore: SqliteSettingsStore(db),
        isPersistentSqlite: true,
      );
    } catch (_) {
      return StorageBundle.inMemory();
    }
  }

  /// Tüm kullanıcı verilerini (ayarlar, sinyal günlüğü, haftalık raporlar) JSON metni olarak dışa aktarır (K6).
  Future<String> exportToJson() async {
    final settings = await settingsStore.load();
    final signals = await journalStore.allSignals();
    final reports = await reportStore.allReports();
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': settings.toJson(),
      'signals': [for (final s in signals) s.toJson()],
      'reports': [for (final r in reports) r.toJson()],
    });
  }

  /// Dışa aktarılmış JSON yedeğini içe aktarır.
  Future<void> importFromJson(String jsonText) async {
    final doc = jsonDecode(jsonText);
    if (doc is! Map) throw const FormatException('Geçersiz yedek dosyası');
    if (doc['settings'] is Map) {
      await settingsStore.save(AppSettings.fromJson((doc['settings'] as Map).cast<String, Object?>()));
    }
    if (doc['signals'] is List) {
      for (final row in doc['signals'] as List) {
        if (row is Map) {
          await journalStore.save(SignalRecord.fromJson(row.cast<String, Object?>()));
        }
      }
    }
    if (doc['reports'] is List) {
      for (final row in doc['reports'] as List) {
        if (row is Map) {
          await reportStore.save(WeeklyReport.fromJson(row.cast<String, Object?>()));
        }
      }
    }
  }
}

/// SQLite tabanlı mum önbelleği (`CandleCache`).
class SqliteCandleCache implements CandleCache {
  SqliteCandleCache(this._db);
  final Database _db;

  @override
  Future<CandleSeries?> read(String key) async {
    final rows = await _db.query(
      'candle_cache',
      columns: ['payload'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['payload'] as String?;
    if (raw == null) return null;
    return CandleSeries.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  }

  @override
  Future<void> write(String key, CandleSeries series) async {
    await _db.insert(
      'candle_cache',
      {
        'cache_key': key,
        'payload': jsonEncode(series.toJson()),
        'updated_at': series.fetchedAt.toUtc().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clear() async {
    await _db.delete('candle_cache');
  }
}

/// SQLite tabanlı sinyal günlüğü (`SignalJournalStore`).
class SqliteSignalJournalStore implements SignalJournalStore {
  SqliteSignalJournalStore(this._db);
  final Database _db;

  @override
  Future<void> save(SignalRecord record) async {
    await _db.insert(
      'signal_journal',
      {
        'id': record.id,
        'market': record.instrument.market.name,
        'created_at': record.createdAt.toUtc().millisecondsSinceEpoch,
        'is_active': record.isActive ? 1 : 0,
        'is_weekly': record.isWeeklyProposal ? 1 : 0,
        'payload': jsonEncode(record.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<SignalRecord?> byId(String id) async {
    final rows = await _db.query(
      'signal_journal',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SignalRecord.fromJson((jsonDecode(rows.first['payload'] as String) as Map).cast<String, Object?>());
  }

  @override
  Future<List<SignalRecord>> activeSignals({Market? market}) async {
    final where = market == null ? 'is_active = 1' : 'is_active = 1 AND market = ?';
    final args = market == null ? null : [market.name];
    final rows = await _db.query(
      'signal_journal',
      columns: ['payload'],
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return [
      for (final r in rows)
        SignalRecord.fromJson((jsonDecode(r['payload'] as String) as Map).cast<String, Object?>()),
    ];
  }

  @override
  Future<List<SignalRecord>> allSignals({
    Market? market,
    DateTime? since,
    DateTime? until,
    bool? weeklyProposalsOnly,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (market != null) {
      clauses.add('market = ?');
      args.add(market.name);
    }
    if (since != null) {
      clauses.add('created_at >= ?');
      args.add(since.toUtc().millisecondsSinceEpoch);
    }
    if (until != null) {
      clauses.add('created_at <= ?');
      args.add(until.toUtc().millisecondsSinceEpoch);
    }
    if (weeklyProposalsOnly != null) {
      clauses.add('is_weekly = ?');
      args.add(weeklyProposalsOnly ? 1 : 0);
    }
    final rows = await _db.query(
      'signal_journal',
      columns: ['payload'],
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return [
      for (final r in rows)
        SignalRecord.fromJson((jsonDecode(r['payload'] as String) as Map).cast<String, Object?>()),
    ];
  }

  @override
  Future<void> clear() async {
    await _db.delete('signal_journal');
  }
}

/// SQLite tabanlı haftalık rapor arşivi (`WeeklyReportStore`).
class SqliteWeeklyReportStore implements WeeklyReportStore {
  SqliteWeeklyReportStore(this._db);
  final Database _db;

  @override
  Future<void> save(WeeklyReport report) async {
    await _db.insert(
      'weekly_reports',
      {
        'id': report.id,
        'generated_at': report.generatedAt.toUtc().millisecondsSinceEpoch,
        'payload': jsonEncode(report.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<WeeklyReport?> latest() async {
    final rows = await _db.query(
      'weekly_reports',
      columns: ['payload'],
      orderBy: 'generated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WeeklyReport.fromJson((jsonDecode(rows.first['payload'] as String) as Map).cast<String, Object?>());
  }

  @override
  Future<List<WeeklyReport>> allReports() async {
    final rows = await _db.query(
      'weekly_reports',
      columns: ['payload'],
      orderBy: 'generated_at DESC',
    );
    return [
      for (final r in rows)
        WeeklyReport.fromJson((jsonDecode(r['payload'] as String) as Map).cast<String, Object?>()),
    ];
  }

  @override
  Future<void> clear() async {
    await _db.delete('weekly_reports');
  }
}

/// SQLite tabanlı ayarlar deposu (`SettingsStore`).
class SqliteSettingsStore implements SettingsStore {
  SqliteSettingsStore(this._db);
  final Database _db;

  @override
  Future<AppSettings> load() async {
    final rows = await _db.query('app_settings', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return const AppSettings();
    final raw = rows.first['payload'] as String?;
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _db.insert(
      'app_settings',
      {
        'id': 1,
        'payload': jsonEncode(settings.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

