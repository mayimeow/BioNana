import 'package:flutter/foundation.dart'; 
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocalDbService {
  // Singleton instance
  static final LocalDbService instance = LocalDbService._init();
  static Database? _database;

  LocalDbService._init(); 

  final String _tableName = "completed_batches";

  Future<Database> get database async {
    if (_database != null) return _database!;
    // (FIX) Changed name to v3 to force a fresh start with the new column
    _database = await _initDB('bionana_local_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        firestoreId TEXT PRIMARY KEY, 
        sapVolume REAL,
        waterVolume REAL,
        molassesVolume REAL,
        totalVolume REAL,
        startTime TEXT,
        completedAt TEXT,
        status TEXT,
        cancelReason TEXT
      )
    ''');
    // (FIX) ^ firestoreId is now the PRIMARY KEY. Duplicates are impossible.
  }

  Future<void> saveBatchToLocal(
      Map<String, dynamic> batchData, String firestoreId) async {
    final db = await database;
    try {
      // --- Handle Timestamps ---
      String startTimeStr;
      if (batchData['startTime'] is Timestamp) {
        startTimeStr = (batchData['startTime'] as Timestamp).toDate().toIso8601String();
      } else if (batchData['startTime'] is String) {
        startTimeStr = batchData['startTime'];
      } else {
        startTimeStr = DateTime.now().toIso8601String();
      }

      String completedAtStr;
      if (batchData['completedAt'] is Timestamp) {
        completedAtStr = (batchData['completedAt'] as Timestamp).toDate().toIso8601String();
      } else if (batchData['completedAt'] is String) {
        completedAtStr = batchData['completedAt'];
      } else {
        completedAtStr = DateTime.now().toIso8601String();
      }

      // --- (FIX) UPSERT LOGIC: Check before saving ---
      final existing = await db.query(
        _tableName,
        where: 'firestoreId = ?',
        whereArgs: [firestoreId],
      );

      final dataToSave = {
        'firestoreId': firestoreId,
        'sapVolume': (batchData['sapVolume'] ?? 0).toDouble(),
        'waterVolume': (batchData['waterVolume'] ?? 0).toDouble(),
        'molassesVolume': (batchData['molassesVolume'] ?? 0).toDouble(),
        'totalVolume': (batchData['totalVolume'] ?? 0).toDouble(),
        'startTime': startTimeStr,
        'completedAt': completedAtStr,
        'status': batchData['status'] ?? 'Unknown',
        'cancelReason': batchData['cancelReason'] ?? '', // --- SAVING NEW REASON HERE ---
      };

      if (existing.isNotEmpty) {
        // Update existing row
        await db.update(
          _tableName,
          dataToSave,
          where: 'firestoreId = ?',
          whereArgs: [firestoreId],
        );
      } else {
        // Insert new row
        await db.insert(_tableName, dataToSave);
      }
      debugPrint("Local DB: Batch Saved/Updated ($firestoreId)");

    } catch (e) {
      debugPrint("Error saving to local DB: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getLocalBatches() async {
    final db = await database;
    return await db.query(
      _tableName,
      orderBy: 'completedAt DESC',
    );
  }

  Future<void> deleteBatch(String firestoreId) async {
    final db = await database;
    try {
      await db.delete(
        _tableName,
        where: 'firestoreId = ?',
        whereArgs: [firestoreId],
      );
      debugPrint("Local DB: Deleted batch $firestoreId");
    } catch (e) {
      debugPrint("Local DB Error deleting: $e");
    }
  }

  // --- SYNC FEATURE ---
  // Kept so MainPage listener can call it
  Future<void> syncFromFirestore() async {
    // Note: We don't need 'final db = await database;' here since saveBatchToLocal handles it.
    try {
      final snapshot = await FirebaseFirestore.instance.collection('batches').get();
      debugPrint("Found ${snapshot.docs.length} batches in Cloud. Syncing...");

      for (var doc in snapshot.docs) {
        await saveBatchToLocal(doc.data(), doc.id);
      }
      debugPrint("Sync Complete!");
    } catch (e) {
      debugPrint("Error syncing from cloud: $e");
    }
  }
}