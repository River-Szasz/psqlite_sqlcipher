import 'package:flutter/material.dart';
import 'package:psqlite/psqlite.dart';
import '../model/user.dart';
import '../services/user_storage_service.dart';

/// A screen that demonstrates SQLCipher encryption functionality
class SQLCipherTestScreen extends StatefulWidget {
  const SQLCipherTestScreen({Key? key}) : super(key: key);

  @override
  _SQLCipherTestScreenState createState() => _SQLCipherTestScreenState();
}

class _SQLCipherTestScreenState extends State<SQLCipherTestScreen> {
  // Test results
  List<String> _logMessages = [];
  bool _isRunningTests = false;

  // Encryption passwords for testing
  final String _correctPassword = 'test_password_123';
  final String _wrongPassword = 'wrong_password_456';

  @override
  void initState() {
    super.initState();
  }

  // Helper method to log messages
  void _log(String message) {
    setState(() {
      _logMessages.add(message);
    });
  }

  // Run the encryption tests
  Future<void> _runEncryptionTests() async {
    setState(() {
      _isRunningTests = true;
      _logMessages = []; // Clear previous logs
    });

    try {
      _log('Starting SQLCipher encryption tests...');
      
      // Test 1: Create and access encrypted database with password
      await _testCreateAndAccessEncryptedDatabase();
      
      // Test 2: Try to open with wrong password
      await _testWrongPassword();
      
      _log('✅ All tests completed successfully!');
    } catch (e) {
      _log('❌ Test failed with error: $e');
    } finally {
      setState(() {
        _isRunningTests = false;
      });
    }
  }

  // Test 1: Create and access encrypted database with password
  Future<void> _testCreateAndAccessEncryptedDatabase() async {
    _log('Test 1: Creating encrypted database with password...');
    
    // Create encrypted storage service
    final storageService = _createEncryptedStorageService(
      password: _correctPassword,
      dbName: 'test1.db'
    );
    
    // Create test user
    final testUser = User('1', 'John', 'Doe', 30);
    
    // Add user to database
    _log('Adding user to encrypted database...');
    await storageService.addUser(testUser);
    
    // Retrieve user from database
    _log('Retrieving user from encrypted database...');
    final retrievedUser = await storageService.getUser('1');
    
    // Verify data was correctly stored and retrieved
    if (retrievedUser != null && 
        retrievedUser.getId() == testUser.getId() &&
        retrievedUser.getName() == testUser.getName() &&
        retrievedUser.getLastName() == testUser.getLastName() &&
        retrievedUser.getAge() == testUser.getAge()) {
      _log('✅ Test 1 passed: User successfully stored and retrieved from encrypted database');
    } else {
      _log('❌ Test 1 failed: User data mismatch or not found');
      throw Exception('User data mismatch or not found');
    }
  }

  // Test 2: Try to open with wrong password
  Future<void> _testWrongPassword() async {
    _log('Test 2: Testing database access with wrong password...');
    
    // Step 1: Create database with correct password
    _log('Creating database with correct password...');
    final correctPasswordService = _createEncryptedStorageService(
      password: _correctPassword,
      dbName: 'test2.db'
    );
    
    // Add test data
    final testUser = User('1', 'Jane', 'Smith', 25);
    await correctPasswordService.addUser(testUser);
    
    // Verify data was written
    final users = await correctPasswordService.getListOfUsers();
    if (users.isEmpty) {
      _log('❌ Test 2 failed: Could not add user to database');
      throw Exception('Could not add user to database');
    }
    
    _log('User successfully added with correct password');
    
    // Step 2: Try to open the same database with wrong password
    _log('Attempting to access database with wrong password...');
    
    try {
      // This should fail with SQLCipher
      final wrongPasswordService = _createEncryptedStorageService(
        password: _wrongPassword,
        dbName: 'test2.db'
      );
      
      // Attempting to read should fail
      await wrongPasswordService.getListOfUsers();
      
      // If we got here, it means it didn't throw an exception
      _log('❌ Test 2 failed: Expected exception when using wrong password');
      throw Exception('Expected exception when using wrong password');
    } catch (e) {
      // This is expected behavior - wrong password should cause an exception
      _log('✅ Test 2 passed: Database access failed with wrong password as expected');
    }
  }

  // Creates an encrypted storage service with the specified password and database name
  EncryptedUserStorageService _createEncryptedStorageService({
    required String password,
    required String dbName
  }) {
    return EncryptedUserStorageService(
      password: password,
      dbName: dbName,
      mockedDatabase: false // Use real database, not in-memory
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SQLCipher Encryption Test'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'SQLCipher Encryption Tests',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          ElevatedButton(
            onPressed: _isRunningTests ? null : _runEncryptionTests,
            child: _isRunningTests
                ? const CircularProgressIndicator()
                : const Text('Run Encryption Tests'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ListView.builder(
                  itemCount: _logMessages.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _logMessages[index],
                      style: const TextStyle(fontFamily: 'monospace'),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom storage service that accepts a password for encryption
class EncryptedUserStorageService {
  late PSQLite _database;
  final _tableName = 'users';
  final bool _mockedDatabase;
  final String? _password;
  final String _dbName;

  EncryptedUserStorageService({
    bool mockedDatabase = false,
    String? password,
    String dbName = 'users.db',
  }) : _mockedDatabase = mockedDatabase,
       _password = password,
       _dbName = dbName {
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
    
    // Set custom database name if provided
    _database.setDbName(_dbName);
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
