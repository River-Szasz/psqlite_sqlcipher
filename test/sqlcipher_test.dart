import 'package:flutter_test/flutter_test.dart';
import 'package:psqlite/psqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../example/lib/model/user.dart';
import '../example/lib/services/user_storage_service.dart';

// Custom storage service that accepts a password for encryption
class EncryptedUserStorageService {
  late PSQLite _database;
  final _tableName = 'users';
  final bool _mockedDatabase;
  final String? _password;

  EncryptedUserStorageService({
    bool mockedDatabase = false,
    String? password,
  }) : _mockedDatabase = mockedDatabase,
      _password = password {
    _initializeDatabase();
  }

  void _initializeDatabase() {
    List<ColumnDb> columns = [
      ColumnDb(
          name: UserColumnName.id.name,
          type: FieldTypeDb.text,
          isPrimaryKey: true),
      ColumnDb(name: UserColumnName.name.name, type: FieldTypeDb.text),
      ColumnDb(name: UserColumnName.lastName.name, type: FieldTypeDb.text),
      ColumnDb(name: UserColumnName.age.name, type: FieldTypeDb.integer)
    ];
    final table = TableDb.create(name: _tableName, columns: columns);
    _database = PSQLite(
      table: table, 
      isMocked: _mockedDatabase,
      password: _password,
    );
  }

  PSQLite getDatabase() => _database;

  Future<void> addUser(User user) async {
    await _database.insertElement(user);
  }

  Future<User?> getUser(String id) async {
    final response = await _database.getElementBy(id);
    if (response != null) {
      return User(
          response[UserColumnName.id.name],
          response[UserColumnName.name.name],
          response[UserColumnName.lastName.name],
          response[UserColumnName.age.name]);
    }
    return null;
  }

  Future<List<User>> getListOfUsers({List<FilterDb> where = const []}) async {
    final maps = await _database.getElements(where: where);
    return List.generate(maps.length, (i) {
      return User(
          maps[i][UserColumnName.id.name],
          maps[i][UserColumnName.name.name],
          maps[i][UserColumnName.lastName.name],
          maps[i][UserColumnName.age.name]);
    });
  }
  
  Future<void> removeAll() async {
    await _database.clearTable();
  }
}

// Helper function to delete test databases files
Future<void> _deleteTestDatabases() async {
  final dbDir = Directory.current;
  final files = dbDir.listSync();
  
  for (var file in files) {
    if (file is File && file.path.endsWith('.db')) {
      await file.delete();
    }
  }
}

void main() {
  // Initialize Flutter binding first
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Setup
  setUpAll(() {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;
  });
  
  setUp(() async {
    // Clean up any test databases before each test
    await _deleteTestDatabases();
  });
  
  tearDownAll(() async {
    // Clean up any test databases after all tests
    await _deleteTestDatabases();
  });

  group('SQLCipher Encryption Tests', () {
    test('Create and access encrypted database with password', () async {
      // Create a storage service with encryption password
      final encryptionPassword = 'test_password_123';
      final storageService = EncryptedUserStorageService(
        password: encryptionPassword, 
        mockedDatabase: false // Use real database, not in-memory
      );
      
      // Test that we can write to and read from the encrypted database
      final testUser = User('1', 'John', 'Doe', 30);
      
      // Add user to database
      await storageService.addUser(testUser);
      
      // Retrieve user from database
      final retrievedUser = await storageService.getUser('1');
      
      // Verify data was correctly stored and retrieved
      expect(retrievedUser, isNotNull);
      expect(retrievedUser, equals(testUser));
      
      // Verify database operations are working by retrieving all users
      final usersList = await storageService.getListOfUsers();
      expect(usersList.length, 1);
      expect(usersList[0], equals(testUser));
    });

    test('Fail to open encrypted database with wrong password', () async {
      // First create database with a password
      final correctPassword = 'correct_password';
      final wrongPassword = 'wrong_password';
      
      // Step 1: Create and populate database with correct password
      {
        final storageService = EncryptedUserStorageService(
          password: correctPassword,
          mockedDatabase: false
        );
        
        // Add test data
        final testUser = User('1', 'Jane', 'Smith', 25);
        await storageService.addUser(testUser);
        
        // Verify data was written
        final users = await storageService.getListOfUsers();
        expect(users.length, 1);
      }
      
      // Step 2: Try to open the database with wrong password
      // This should throw an exception with SQLCipher
      expect(() async {
        final storageService = EncryptedUserStorageService(
          password: wrongPassword,
          mockedDatabase: false
        );
        
        // Attempting to read should fail
        await storageService.getListOfUsers();
      }, throwsException);
    });
  });
}
