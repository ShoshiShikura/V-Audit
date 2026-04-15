// ignore_for_file: unnecessary_this

import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart' as legacy_sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:tm_audit/models/team.dart';
import '../models/document.dart';
import '../models/user.dart';
import '../models/worker.dart';
import '../services/encryption_service.dart';
import '../services/data_encryption_service.dart';
import '../services/session_manager.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    return _database ??= await _initDatabase();
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final legacyPath = join(dbPath, 'vmm.db'); // legacy unencrypted db
    final encryptedPath = join(dbPath, 'vaudit.db'); // new SQLCipher db

    // If a plaintext SQLite file accidentally exists at the encrypted path,
    // SQLCipher will fail to open it. Detect and recover by treating it as legacy.
    if (await File(encryptedPath).exists()) {
      final isPlain = await _isPlainSQLiteFile(encryptedPath);
      if (isPlain) {
        final recoveredLegacy = join(dbPath,
            'vmm_recovered_${DateTime.now().millisecondsSinceEpoch}.db');
        await File(encryptedPath).rename(recoveredLegacy);
        await _migrateLegacyToEncrypted(
          legacyPath: recoveredLegacy,
          encryptedPath: encryptedPath,
        );
      }
    }

    // One-time migration: if encrypted DB doesn't exist but legacy does, migrate.
    final encryptedExists = await File(encryptedPath).exists();
    final legacyExists = await File(legacyPath).exists();
    if (!encryptedExists && legacyExists) {
      await _migrateLegacyToEncrypted(
        legacyPath: legacyPath,
        encryptedPath: encryptedPath,
      );
    }

    final password = await EncryptionService.getDerivedKey();
    try {
      return await openDatabase(
        encryptedPath,
        password: password,
        version: 10,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      // Recovery strategy:
      // - If legacy exists, try migrating (again) then re-open.
      // - Otherwise, backup the encrypted file (likely key mismatch/corruption),
      //   recreate a fresh encrypted DB so the app can run.
      final legacyStillExists = await File(legacyPath).exists();
      if (legacyStillExists) {
        await _migrateLegacyToEncrypted(
          legacyPath: legacyPath,
          encryptedPath: encryptedPath,
        );
        return await openDatabase(
          encryptedPath,
          password: password,
          version: 10,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
      }

      if (await File(encryptedPath).exists()) {
        final backup =
            '$encryptedPath.corrupt_${DateTime.now().millisecondsSinceEpoch}.bak';
        try {
          await File(encryptedPath).copy(backup);
        } catch (_) {
          // ignore backup failure
        }
        try {
          await legacy_sqflite.deleteDatabase(encryptedPath);
        } catch (_) {
          // ignore
        }
      }

      // Fresh encrypted DB (data may be lost if key mismatch was the cause).
      return await openDatabase(
        encryptedPath,
        password: password,
        version: 10,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
  }

  Future<bool> _isPlainSQLiteFile(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return false;
      final raf = await f.open(mode: FileMode.read);
      try {
        final bytes = await raf.read(16);
        final header = utf8.decode(bytes, allowMalformed: true);
        return header.startsWith('SQLite format 3');
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _migrateLegacyToEncrypted({
    required String legacyPath,
    required String encryptedPath,
  }) async {
    // Open legacy (plain) DB with sqflite.
    final legacyDb = await legacy_sqflite.openDatabase(legacyPath);

    try {
      // Create encrypted DB and schema, then copy table contents.
      final password = await EncryptionService.getDerivedKey();
      final encryptedDb = await openDatabase(
        encryptedPath,
        password: password,
        version: 10,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      try {
        await encryptedDb.transaction((txn) async {
          // Tables in this app's schema that must be migrated.
          const tables = <String>[
            'documents',
            'users',
            'companies',
            'teams',
            'profiling_team',
            'summary_team',
            'finding_summary',
            'company_name',
            'team_images',
            'workers',
          ];

          for (final table in tables) {
            final rows = await legacyDb.query(table);
            for (final row in rows) {
              await txn.insert(
                table,
                Map<String, Object?>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        });
      } finally {
        await encryptedDb.close();
      }

      // Keep a backup of the legacy DB for safety.
      final backupPath = '$legacyPath.bak';
      if (!await File(backupPath).exists()) {
        await File(legacyPath).copy(backupPath);
      }

      // Delete legacy DB so the app uses encrypted DB going forward.
      await legacy_sqflite.deleteDatabase(legacyPath);
    } finally {
      await legacyDb.close();
    }
  }

  /// Returns SQLCipher version string if encrypted DB is working.
  Future<String?> getCipherVersion() async {
    final db = await database;
    try {
      final rows = await db.rawQuery('PRAGMA cipher_version;');
      if (rows.isEmpty) return null;
      final first =
          rows.first.values.isNotEmpty ? rows.first.values.first : null;
      return first?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE documents (
      id TEXT PRIMARY KEY,
      title TEXT,
      description TEXT,
      type TEXT,
      createdDate TEXT,
      lastModified TEXT,
      fileName TEXT,
      isDraft INTEGER,
      ownerId TEXT,
      location TEXT,
      auditor TEXT
    )
  ''');

    await db.execute('''
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      password TEXT,
      role TEXT,
      fullName TEXT,
      activated INTEGER DEFAULT 0
    )
  ''');

    // Add companies table
    await db.execute('''
    CREATE TABLE companies (
      id TEXT PRIMARY KEY,
      name TEXT UNIQUE
    )
  ''');

    // Add teams table
    await db.execute('''
    CREATE TABLE teams (
      id TEXT PRIMARY KEY,
      documentId TEXT,
      type TEXT,
      label TEXT,
      number INTEGER
    )
  ''');

    await db.execute('''
      CREATE TABLE profiling_team (
        id TEXT PRIMARY KEY,
        documentId TEXT,
        teamId TEXT,
        personIndex INTEGER,
        name TEXT,
        ic TEXT,
        attendance TEXT,
        ntsmpDate TEXT,
        aespDate TEXT,
        agtesDate TEXT,
        poleProficiency TEXT,
        ca2aDate TEXT,
        ca2cDate TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE summary_team (
        teamId TEXT PRIMARY KEY,
        typeOfTeam TEXT,
        ppe TEXT,
        competency TEXT,
        typeOfTeamRed INTEGER DEFAULT 0,
        ppeRed INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE finding_summary (
        documentId TEXT PRIMARY KEY,
        remark TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE company_name (
        teamId TEXT PRIMARY KEY,
        attachmentPath TEXT DEFAULT NULL,
        capturedAt TEXT DEFAULT NULL,
        latitude REAL DEFAULT NULL,
        longitude REAL DEFAULT NULL,
        altitude REAL DEFAULT NULL,
        remark TEXT DEFAULT '',
        members TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS team_images (
        teamId TEXT PRIMARY KEY,
        imagePath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workers (
        userId TEXT PRIMARY KEY,
        name TEXT,
        ic TEXT,
        companies TEXT,
        status TEXT
      )
    ''');

    // Insert default administrator
    String hashedPassword = sha256.convert(utf8.encode('admin123')).toString();
    await db.insert('users', {
      'id': 'superadmin',
      'password': hashedPassword,
      'role': SessionManager.roleAdministrator,
      'fullName': 'Administrator',
      'activated': 1,
    });

    // Insert default companies
    final defaultCompanies = [
      'BEGAS ENERGY SDN BHD',
      'EMAX SYNERGY SDN BHD',
      'EP SINAR SDN BHD',
      'EXACT ENGINEERING SDN BHD',
      'FEMAC ENGINEERING SDN BHD',
      'KAMAWANG ENTERPRISE SDN BHD',
      'KK UNIK SDN BHD',
      'KOMISO SDN BHD',
      'KONSORTIUM MYRCOM SDN BHD',
      'LLP ELECTRICAL ENGINEERING SDN BHD',
      'MAJU R&A SDN BHD',
      'MEGA SEVEN NETWORK SDN BHD',
      'NINAZ ENTERPRISE SDN BHD',
      'NINAZ TELCO SDN BHD',
      'OCK SETIA ENGINEERING SDN BHD',
      'PEMBANGUNAN ECO-BUMI SDN BHD',
      'RASMART SDN BHD',
      'RITES SDN BHD',
      'SERI PANCAR SDN BHD',
      'SETIA JAYA ENERGY SDN BHD',
      'TAISAH TEGUH ENGINEERING SDN BHD',
      'TETAP PADU HOLDINGS SDN BHD',
      'TETAP YAKIN SDN BHD',
      'WUHAN FIBERHOME SDN BHD',
      'YAZA COMMUNICATION SDN BHD',
    ];

    for (final company in defaultCompanies) {
      await db.insert('companies', {
        'id': 'company_${company.hashCode}',
        'name': company,
      });
    }

    // Insert preset workers for NINAZ TELCO SDN BHD
    final presetWorkers = [
      {'name': 'MOHD NOORESHAM BIN AMBO', 'ic': '970318-12-6111'},
      {'name': 'ABU BAKAR BIN ARAS', 'ic': 'C1588036'},
      {'name': 'ASMAWI BIN MUHTAR', 'ic': '840814-12-5665'},
      {'name': 'MUHAMMAD AMRY BIN SUKURI', 'ic': '000319-12-0347'},
      {'name': 'SAMSUL BIN MOHAMMAD', 'ic': '860317-12-5937'},
      {'name': 'MUHAMMAD ALI IMRAN BIN SUGALA', 'ic': '020709-12-0527'},
      {'name': 'AL-FAIZAL BIN HARRIS', 'ic': 'P3629653B'},
      {'name': 'MAZLAN BIN MUSAFIR', 'ic': '010315-12-0461'},
      {'name': 'WARIS BIN JAMALUDDIN', 'ic': '850626-12-5501'},
      {'name': 'ABRAHAM BIN ARKIEL', 'ic': '960930-12-6311'},
      {'name': 'MUHAMMAD NABIL BIN ABDULLAH', 'ic': '020623-14-1175'},
      {'name': 'MOHAMMAD SHAHRIZAD HASSAN', 'ic': '050929-12-0921'},
      {'name': 'MOHD SHAREYZMAN BIN ABDUL MALIK', 'ic': '010726-12-0263'},
      {'name': 'DONNY SIWOH', 'ic': '970309-12-6021'},
      {'name': 'MUHD HISHAM', 'ic': 'C8342150'},
      {'name': 'CARPIO JECKEE DEMAYO', 'ic': 'EB483684'},
      {'name': 'MUHD SYAHNURRIZAL BIN MAIDIN', 'ic': '001020-12-0427'},
      {'name': 'SYAMIR BIN ABD MAJID', 'ic': 'C7623522'},
      {'name': 'MUHAMMAD IKHRAM BIN ROSLIE', 'ic': '051219-12-2067'},
      {'name': 'MOHAMAD SHAHRIZAL BIN HASSAN', 'ic': '010710-12-0787'},
      {'name': 'FRANCIS RENOON', 'ic': '880811-49-5245'},
      {'name': 'ASMID BIN MAJID', 'ic': 'IP-12041-6037'},
    ];

    for (int i = 0; i < presetWorkers.length; i++) {
      final worker = presetWorkers[i];
      await db.insert('workers', {
        'userId':
            'XL${(i + 1).toString().padLeft(3, '0')}', // XL001, XL002, etc.
        'name': worker['name'],
        'ic': worker['ic'],
        'companies': 'NINAZ TELCO SDN BHD',
        'status': 'active',
      });
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE documents ADD COLUMN location TEXT;");
      await db.execute("ALTER TABLE documents ADD COLUMN auditor TEXT;");
    }
    if (oldVersion < 3) {
      // Add fullName column and migrate existing data
      await db.execute("ALTER TABLE users ADD COLUMN fullName TEXT;");

      // Update existing superadmin user
      await db.update(
        'users',
        {'fullName': 'Superadmin'},
        where: 'id = ?',
        whereArgs: ['superadmin'],
      );

      // Remove email column if it exists (for future compatibility)
      try {
        await db.execute("ALTER TABLE users DROP COLUMN email;");
      } catch (e) {
        // Column might not exist, ignore error
      }
    }
    if (oldVersion < 4) {
      // Add companies table if it doesn't exist
      await db.execute('''
      CREATE TABLE IF NOT EXISTS companies (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE
      )
    ''');

      // Insert default companies if table is empty
      final companiesCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM companies'),
      );

      if (companiesCount == 0) {
        final defaultCompanies = [
          'BEGAS ENERGY SDN BHD',
          'EMAX SYNERGY SDN BHD',
          'EP SINAR SDN BHD',
          'EXACT ENGINEERING SDN BHD',
          'FEMAC ENGINEERING SDN BHD',
          'KAMAWANG ENTERPRISE SDN BHD',
          'KK UNIK SDN BHD',
          'KOMISO SDN BHD',
          'KONSORTIUM MYRCOM SDN BHD',
          'LLP ELECTRICAL ENGINEERING SDN BHD',
          'MAJU R&A SDN BHD',
          'MEGA SEVEN NETWORK SDN BHD',
          'NINAZ ENTERPRISE SDN BHD',
          'NINAZ TELCO SDN BHD',
          'OCK SETIA ENGINEERING SDN BHD',
          'PEMBANGUNAN ECO-BUMI SDN BHD',
          'RASMART SDN BHD',
          'RITES SDN BHD',
          'SERI PANCAR SDN BHD',
          'SETIA JAYA ENERGY SDN BHD',
          'TAISAH TEGUH ENGINEERING SDN BHD',
          'TETAP PADU HOLDINGS SDN BHD',
          'TETAP YAKIN SDN BHD',
          'WUHAN FIBERHOME SDN BHD',
          'YAZA COMMUNICATION SDN BHD',
        ];

        for (final company in defaultCompanies) {
          await db.insert('companies', {
            'id': 'company_${company.hashCode}',
            'name': company,
          });
        }
      }
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS workers (
          userId TEXT PRIMARY KEY,
          name TEXT,
          ic TEXT,
          companies TEXT,
          status TEXT
        )
      ''');
    }
    if (oldVersion < 6) {
      // Insert preset workers for NINAZ TELCO SDN BHD
      final presetWorkers = [
        {'name': 'MOHD NOORESHAM BIN AMBO', 'ic': '970318-12-6111'},
        {'name': 'ABU BAKAR BIN ARAS', 'ic': 'C1588036'},
        {'name': 'ASMAWI BIN MUHTAR', 'ic': '840814-12-5665'},
        {'name': 'MUHAMMAD AMRY BIN SUKURI', 'ic': '000319-12-0347'},
        {'name': 'SAMSUL BIN MOHAMMAD', 'ic': '860317-12-5937'},
        {'name': 'MUHAMMAD ALI IMRAN BIN SUGALA', 'ic': '020709-12-0527'},
        {'name': 'AL-FAIZAL BIN HARRIS', 'ic': 'P3629653B'},
        {'name': 'MAZLAN BIN MUSAFIR', 'ic': '010315-12-0461'},
        {'name': 'WARIS BIN JAMALUDDIN', 'ic': '850626-12-5501'},
        {'name': 'ABRAHAM BIN ARKIEL', 'ic': '960930-12-6311'},
        {'name': 'MUHAMMAD NABIL BIN ABDULLAH', 'ic': '020623-14-1175'},
        {'name': 'MOHAMMAD SHAHRIZAD HASSAN', 'ic': '050929-12-0921'},
        {'name': 'MOHD SHAREYZMAN BIN ABDUL MALIK', 'ic': '010726-12-0263'},
        {'name': 'DONNY SIWOH', 'ic': '970309-12-6021'},
        {'name': 'MUHD HISHAM', 'ic': 'C8342150'},
        {'name': 'CARPIO JECKEE DEMAYO', 'ic': 'EB483684'},
        {'name': 'MUHD SYAHNURRIZAL BIN MAIDIN', 'ic': '001020-12-0427'},
        {'name': 'SYAMIR BIN ABD MAJID', 'ic': 'C7623522'},
        {'name': 'MUHAMMAD IKHRAM BIN ROSLIE', 'ic': '051219-12-2067'},
        {'name': 'MOHAMAD SHAHRIZAL BIN HASSAN', 'ic': '010710-12-0787'},
        {'name': 'FRANCIS RENOON', 'ic': '880811-49-5245'},
        {'name': 'ASMID BIN MAJID', 'ic': 'IP-12041-6037'},
      ];

      for (int i = 0; i < presetWorkers.length; i++) {
        final worker = presetWorkers[i];
        await db.insert('workers', {
          'userId':
              'XL${(i + 1).toString().padLeft(3, '0')}', // XL001, XL002, etc.
          'name': worker['name'],
          'ic': worker['ic'],
          'companies': 'NINAZ TELCO SDN BHD',
          'status': 'active',
        });
      }
    }

    if (oldVersion < 7) {
      // Add capture metadata fields for company_name attachments
      try {
        await db
            .execute("ALTER TABLE company_name ADD COLUMN capturedAt TEXT;");
      } catch (e) {
        // Column might already exist, ignore error
      }
      try {
        await db.execute("ALTER TABLE company_name ADD COLUMN latitude REAL;");
      } catch (e) {
        // Column might already exist, ignore error
      }
      try {
        await db.execute("ALTER TABLE company_name ADD COLUMN longitude REAL;");
      } catch (e) {
        // Column might already exist, ignore error
      }
      try {
        await db.execute("ALTER TABLE company_name ADD COLUMN altitude REAL;");
      } catch (e) {
        // Column might already exist, ignore error
      }
    }

    if (oldVersion < 9) {
      // Mark whether a user has been verified online at least once.
      try {
        await db.execute(
          "ALTER TABLE users ADD COLUMN activated INTEGER DEFAULT 0;",
        );
      } catch (e) {
        // Column might already exist, ignore error
      }
    }

    if (oldVersion < 10) {
      // Normalize legacy role vocabulary.
      await db.rawUpdate(
        "UPDATE users SET role = ? WHERE lower(role) IN ('superadmin','admin')",
        [SessionManager.roleAdministrator],
      );
      await db.rawUpdate(
        "UPDATE users SET role = ? WHERE lower(role) = 'user'",
        [SessionManager.roleAuditor],
      );
    }

    // Add summary_team columns safely (check if they exist first)
    try {
      await db.execute(
          "ALTER TABLE summary_team ADD COLUMN typeOfTeamRed INTEGER DEFAULT 0;");
    } catch (e) {
      // Column might already exist, ignore error
    }

    try {
      await db.execute(
          "ALTER TABLE summary_team ADD COLUMN ppeRed INTEGER DEFAULT 0;");
    } catch (e) {
      // Column might already exist, ignore error
    }
  }

  Future<User?> getUser(String id) async {
    final db = await database;
    final result = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      // Decrypt sensitive user data
      final decryptedData =
          await DataEncryptionService.decryptSensitiveFields(result.first);

      return User(
        id: decryptedData['id'] as String,
        password: decryptedData['password'] as String,
        role: SessionManager.normalizeRole(decryptedData['role'] as String?),
        fullName: decryptedData['fullName'] as String? ?? '',
        activated: (decryptedData['activated'] ?? 0) == 1,
      );
    }
    return null;
  }

  // NOTE: Password hashes are no longer encrypted as of [fix date].
  // Existing users must reset their password or be re-added for login to work.
  Future<void> addUser(User user) async {
    final db = await database;
    final userMap = user.toMap();
    userMap['role'] = SessionManager.normalizeRole(userMap['role']?.toString());

    // Encrypt sensitive user data
    final encryptedUserMap =
        await DataEncryptionService.encryptSensitiveFields(userMap);

    await db.insert('users', encryptedUserMap);
  }

  /// Upsert a user after successful online verification so they can log in offline.
  Future<void> upsertActivatedUser({
    required String id,
    required String hashedPassword,
    required String role,
    required String fullName,
  }) async {
    final db = await database;
    final userMap = {
      'id': id,
      'password': hashedPassword,
      'role': SessionManager.normalizeRole(role),
      'fullName': fullName,
      'activated': 1,
    };

    final encryptedUserMap =
        await DataEncryptionService.encryptSensitiveFields(userMap);

    await db.insert(
      'users',
      encryptedUserMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateUserRole(String id, String role) async {
    final db = await database;
    await db.update(
      'users',
      {'role': SessionManager.normalizeRole(role)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // NOTE: Password hashes are no longer encrypted as of [fix date].
  // Existing users must reset their password or be re-added for login to work.
  Future<void> updatePassword(String id, String hashedPassword) async {
    final db = await database;
    await db.update(
      'users',
      {'password': hashedPassword},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteUser(String id) async {
    final db = await database;
    await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<User>> getUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');

    final decryptedUsers = <User>[];
    for (final map in maps) {
      // Decrypt sensitive user data
      final decryptedData =
          await DataEncryptionService.decryptSensitiveFields(map);
      decryptedData['role'] =
          SessionManager.normalizeRole(decryptedData['role']?.toString());
      decryptedUsers.add(User.fromMap(decryptedData));
    }

    return decryptedUsers;
  }

  /// Migration: Fix all users by decrypting any encrypted fields and updating to plain text.
  Future<void> fixAllUsersDecryption() async {
    final db = await database;
    final users = await db.query('users');
    for (final user in users) {
      // Decrypt all possibly encrypted fields
      final decrypted =
          await DataEncryptionService.decryptSensitiveFields(user);
      // Only update if any field changed (i.e., was encrypted)
      bool needsUpdate = false;
      final updated = Map<String, dynamic>.from(user);
      for (final key in ['id', 'role', 'fullName']) {
        if (user[key] != decrypted[key]) {
          updated[key] = decrypted[key];
          needsUpdate = true;
        }
      }
      if (needsUpdate) {
        await db
            .update('users', updated, where: 'id = ?', whereArgs: [user['id']]);
      }
    }
  }

  // Add these methods to your DatabaseHelper class

  Future<int> insertDocument(Document document) async {
    final db = await this.database;
    return await db.insert('documents', document.toMap());
  }

  Future<List<Document>> getDocuments() async {
    final db = await this.database;
    final List<Map<String, dynamic>> maps = await db.query('documents');
    return List.generate(maps.length, (i) {
      return Document.fromMap(maps[i]);
    });
  }

  Future<int> updateDocument(Document document) async {
    final db = await this.database;
    return await db.update(
      'documents',
      document.toMap(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  Future<int> deleteDocument(String id) async {
    final db = await database;
    return await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Team>> getTeamsByDocumentId(String documentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'teams',
      where: 'documentId = ?',
      whereArgs: [documentId],
      orderBy: 'number ASC',
    );
    if (maps.isEmpty) return [];
    return List.generate(maps.length, (i) => Team.fromMap(maps[i]));
  }

  Future<int> insertTeam(Team newTeam) async {
    final db = await database;
    return await db.insert('teams', newTeam.toMap());
  }

  Future<int> deleteTeam(String id) async {
    final db = await database;
    return await db.delete(
      'teams',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Document>> getDocumentsByUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: 'ownerId = ?',
      whereArgs: [userId],
    );
    if (maps.isEmpty) return [];
    return List.generate(maps.length, (i) => Document.fromMap(maps[i]));
  }

  Future<Map<String, dynamic>?> getProfilingPerson(
      String teamId, int personIndex) async {
    final db = await database;
    final result = await db.query(
      'profiling_team',
      where: 'teamId = ? AND personIndex = ?',
      whereArgs: [teamId, personIndex],
      limit: 1,
    );
    if (result.isNotEmpty) {
      // Decrypt sensitive data before returning
      final decryptedData =
          await DataEncryptionService.decryptSensitiveFields(result.first);
      return decryptedData;
    }
    return null;
  }

  Future<void> saveProfilingPerson({
    required String documentId,
    required String teamId,
    required int personIndex,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    // Make id unique by including documentId
    final id = '${documentId}_${teamId}_$personIndex';

    // Encrypt sensitive data before storing
    final encryptedData =
        await DataEncryptionService.encryptSensitiveFields(data);

    final row = {
      'id': id,
      'documentId': documentId,
      'teamId': teamId,
      'personIndex': personIndex,
      'name': encryptedData['name'],
      'ic': encryptedData['ic'],
      'attendance': data['attendance'], // Not sensitive
      'ntsmpDate': data['ntsmpDate']?.toString(), // Not sensitive
      'aespDate': data['aespDate']?.toString(), // Not sensitive
      'agtesDate': data['agtesDate']?.toString(), // Not sensitive
      'poleProficiency': data['poleProficiency'], // Not sensitive
      'ca2aDate': data['ca2aDate']?.toString(), // Not sensitive
      'ca2cDate': data['ca2cDate']?.toString(), // Not sensitive
    };
    await db.insert(
      'profiling_team',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Company management methods
  Future<List<String>> getCompanies() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'companies',
      columns: ['name'],
      orderBy: 'name ASC',
    );
    return maps.map((map) => map['name'] as String).toList();
  }

  Future<void> addCompany(String companyName) async {
    final db = await database;
    await db.insert('companies', {
      'id': 'company_${companyName.hashCode}',
      'name': companyName,
    });
  }

  Future<void> deleteCompany(String companyName) async {
    final db = await database;
    await db.delete(
      'companies',
      where: 'name = ?',
      whereArgs: [companyName],
    );
  }

  // Worker CRUD
  Future<void> insertWorker(Worker worker) async {
    final db = await database;
    await db.insert('workers', worker.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Worker>> getWorkers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('workers');
    return List.generate(maps.length, (i) => Worker.fromMap(maps[i]));
  }

  Future<void> deleteWorker(String userId) async {
    final db = await database;
    await db.delete('workers', where: 'userId = ?', whereArgs: [userId]);
  }

  Future<void> updateWorker(Worker worker) async {
    final db = await database;
    await db.update('workers', worker.toMap(),
        where: 'userId = ?', whereArgs: [worker.userId]);
  }

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // ── View Reports queries ──────────────────────────────────────────────

  /// Returns ALL documents regardless of ownerId (for admin reports).
  Future<List<Document>> getAllDocuments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      orderBy: 'lastModified DESC',
    );
    return List.generate(maps.length, (i) => Document.fromMap(maps[i]));
  }

  /// Returns document count grouped by type, e.g. {'CM': 5, 'PM': 3, 'ND': 2}.
  Future<Map<String, int>> getDocumentCountByType() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT type, COUNT(*) as cnt FROM documents GROUP BY type',
    );
    final counts = <String, int>{};
    for (final row in result) {
      final type = (row['type'] ?? '').toString();
      final cnt = row['cnt'] is int ? row['cnt'] as int : 0;
      if (type.isNotEmpty) counts[type] = cnt;
    }
    return counts;
  }

  /// Returns distinct auditor names from all documents.
  Future<List<String>> getUniqueAuditors() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT auditor FROM documents WHERE auditor IS NOT NULL AND auditor != "" ORDER BY auditor ASC',
    );
    return result.map((r) => r['auditor'] as String).toList();
  }

  /// Returns distinct company names from all documents.
  Future<List<String>> getUniqueCompaniesFromDocuments() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT description FROM documents WHERE description IS NOT NULL AND description != "" ORDER BY description ASC',
    );
    return result.map((r) => r['description'] as String).toList();
  }

  /// Returns team count for a specific document.
  Future<int> getTeamCountForDocument(String documentId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM teams WHERE documentId = ?',
      [documentId],
    );
    if (result.isNotEmpty) {
      return result.first['cnt'] as int? ?? 0;
    }
    return 0;
  }
}

Future<void> deleteDatabaseFile() async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'vaudit.db');
  await deleteDatabase(path);
}
