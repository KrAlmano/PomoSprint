import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pomodoro_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        avatar_id TEXT NOT NULL DEFAULT 'tomato_basic',
        total_minutes INTEGER DEFAULT 0,
        points INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');
  }

  // Register user
  Future<UserModel?> registerUser({
    required String name,
    required String email,
    required String password,
    required String avatarId,
  }) async {
    final db = await instance.database;
    try {
      final id = await db.insert('users', {
        'name': name,
        'email': email.trim().toLowerCase(),
        'password': password,
        'avatar_id': avatarId,
        'total_minutes': 0,
        'points': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      return UserModel(
        id: id,
        name: name,
        email: email.trim().toLowerCase(),
        password: password,
        avatarId: avatarId,
        totalMinutes: 0,
        points: 0,
      );
    } catch (e) {
      // Email duplicate or error
      return null;
    }
  }

  // Login user
  Future<UserModel?> loginUser(String emailOrName, String password) async {
    final db = await instance.database;
    final term = emailOrName.trim().toLowerCase();

    final result = await db.query(
      'users',
      where: '(LOWER(email) = ? OR LOWER(name) = ?) AND password = ?',
      whereArgs: [term, term, password],
    );

    if (result.isNotEmpty) {
      return UserModel.fromMap(result.first);
    }
    return null;
  }

  // Update Avatar
  Future<void> updateUserAvatar(int userId, String avatarId) async {
    final db = await instance.database;
    await db.update(
      'users',
      {'avatar_id': avatarId},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // Update Study Minutes & Points
  Future<void> addStudyMinutes(int userId, int minutes) async {
    final db = await instance.database;
    final userMap = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (userMap.isNotEmpty) {
      final user = UserModel.fromMap(userMap.first);
      final newMinutes = user.totalMinutes + minutes;
      final newPoints = user.points + (minutes * 10);
      await db.update(
        'users',
        {'total_minutes': newMinutes, 'points': newPoints},
        where: 'id = ?',
        whereArgs: [userId],
      );
    }
  }
}
