import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import '../models/category.dart' as app_models;
import '../services/database_service.dart';
import '../services/api_service.dart';

class NoteProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final ApiService _apiService = ApiService();

  List<Note> _notes = [];
  List<app_models.Category> _categories = [];
  String _searchQuery = '';
  String? _selectedCategory;
  String _sortBy = 'updated_at';
  bool _sortAscending = false;
  bool _showArchived = false;
  bool _isLoading = false;
  bool _isOnline = false;
  String? _error;
  String? _currentUserId;

  // Getters
  List<Note> get notes => _filteredNotes;
  List<app_models.Category> get categories {
    final map = <String, app_models.Category>{};
    for (final c in _categories) {
      map.putIfAbsent(c.name, () => c);
    }
    final list = map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  bool get showArchived => _showArchived;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  String? get error => _error;
  bool get hasNotes => _notes.isNotEmpty;
  int get notesCount =>
      _notes.where((note) => !note.archived || _showArchived).length;

  List<Note> get _filteredNotes {
    List<Note> filtered = List.from(_notes);

    // Filter by archived status
    if (!_showArchived) {
      filtered = filtered.where((note) => !note.archived).toList();
    }

    // Filter by category
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where((note) => note.category == _selectedCategory)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (note) =>
                note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                note.content.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                note.tags.any(
                  (tag) =>
                      tag.toLowerCase().contains(_searchQuery.toLowerCase()),
                ),
          )
          .toList();
    }

    // Sort notes
    switch (_sortBy) {
      case 'title':
        filtered.sort(
          (a, b) => _sortAscending
              ? a.title.compareTo(b.title)
              : b.title.compareTo(a.title),
        );
        break;
      case 'created_at':
        filtered.sort(
          (a, b) => _sortAscending
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt),
        );
        break;
      case 'updated_at':
      default:
        filtered.sort(
          (a, b) => _sortAscending
              ? a.updatedAt.compareTo(b.updatedAt)
              : b.updatedAt.compareTo(a.updatedAt),
        );
        break;
    }

    return filtered;
  }

  // Initialize provider
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.initialize();
      _currentUserId = _apiService.userId;
      _isOnline = _apiService.isAuthenticated;

      // Load data from local database
      await _loadLocalData();

      // Try to sync with server if online
      if (_isOnline) {
        await _syncWithServer();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadLocalData() async {
    try {
      _notes = await _databaseService.getAllNotes(
        userId: _currentUserId,
        includeArchived: true,
      );
      _categories = await _databaseService.getAllCategories(
        userId: _currentUserId,
      );
      await _databaseService.updateCategoryNoteCounts();
    } catch (e) {
      _error = 'Failed to load local data: $e';
    }
  }

  Future<void> _syncWithServer() async {
    try {
      if (!_isOnline) return;

      // Get last sync timestamp
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString('last_sync');
      DateTime? lastSync;
      if (lastSyncString != null) {
        lastSync = DateTime.parse(lastSyncString);
      }

      // Pull changes from server
      final syncResponse = await _apiService.getSync(lastSync: lastSync);

      // Apply server changes to local database
      await _applySyncChanges(syncResponse);

      // Push local changes to server
      await _pushLocalChanges();

      // Update last sync timestamp
      await prefs.setString('last_sync', DateTime.now().toIso8601String());

      // Reload data
      await _loadLocalData();
    } catch (e) {
      _error = 'Sync failed: $e';
    }
  }

  Future<void> _applySyncChanges(SyncResponse syncResponse) async {
    // Apply note changes
    for (final noteData in syncResponse.notes.created) {
      final note = Note.fromJson(noteData);
      // upsert
      await _databaseService.updateNote(note);
      await _databaseService.markAsSynced('notes', note.id);
    }

    for (final noteData in syncResponse.notes.updated) {
      final note = Note.fromJson(noteData);
      await _databaseService.updateNote(note);
      await _databaseService.markAsSynced('notes', note.id);
    }

    for (final noteId in syncResponse.notes.deleted) {
      await _databaseService.permanentDeleteNote(noteId);
    }

    // Apply category changes
    for (final categoryData in syncResponse.categories.created) {
      final category = app_models.Category.fromJson(categoryData);
      await _databaseService.updateCategory(category);
      await _databaseService.markAsSynced('categories', category.id);
    }

    for (final categoryData in syncResponse.categories.updated) {
      final category = app_models.Category.fromJson(categoryData);
      await _databaseService.updateCategory(category);
      await _databaseService.markAsSynced('categories', category.id);
    }

    for (final categoryId in syncResponse.categories.deleted) {
      await _databaseService.deleteCategory(categoryId);
    }
  }

  Future<void> _pushLocalChanges() async {
    try {
      final unsyncedNotes = await _databaseService.getUnsyncedItems('notes');
      final unsyncedCategories = await _databaseService.getUnsyncedItems(
        'categories',
      );

      if (unsyncedNotes.isEmpty && unsyncedCategories.isEmpty) {
        return;
      }

      final syncRequest = SyncPushRequest(
        notes: {
          'create': [], // Handle creation logic
          'update': [], // Handle update logic
          'delete': [], // Handle deletion logic
        },
        categories: {
          'create': [], // Handle creation logic
          'update': [], // Handle update logic
          'delete': [], // Handle deletion logic
        },
      );

      final response = await _apiService.pushSync(syncRequest);

      // Update local IDs with server IDs
      for (final entry in response.createdIds.entries) {
        // TODO: Update local records with server IDs
        debugPrint('Created ID mapping: ${entry.key} -> ${entry.value}');
      }
    } catch (e) {
      debugPrint('Failed to push changes: $e');
    }
  }

  // Note operations
  Future<void> addNote(Note note) async {
    try {
      _isLoading = true;
      notifyListeners();

      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final noteWithId = note.copyWith(
        id: localId,
        userId: _currentUserId ?? 'offline_user',
      );

      // Save locally
      await _databaseService.insertNote(noteWithId);

      // Try to sync with server
      if (_isOnline) {
        try {
          final serverNote = await _apiService.createNote(noteWithId);
          await _databaseService.updateNote(serverNote);
          await _databaseService.markAsSynced('notes', serverNote.id);
        } catch (e) {
          debugPrint('Failed to sync note creation: $e');
        }
      }

      await _loadLocalData();
      _error = null;
    } catch (e) {
      _error = 'Failed to add note: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      _isLoading = true;
      notifyListeners();

      final updatedNote = note.copyWith(updatedAt: DateTime.now());

      // Update locally
      await _databaseService.updateNote(updatedNote);

      // Try to sync with server
      if (_isOnline) {
        try {
          final serverNote = await _apiService.updateNote(updatedNote);
          await _databaseService.updateNote(serverNote);
          await _databaseService.markAsSynced('notes', serverNote.id);
        } catch (e) {
          debugPrint('Failed to sync note update: $e');
        }
      }

      await _loadLocalData();
      _error = null;
    } catch (e) {
      _error = 'Failed to update note: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Mark as deleted locally (soft delete)
      await _databaseService.deleteNote(noteId);

      // Try to sync with server
      if (_isOnline) {
        try {
          await _apiService.deleteNote(noteId);
          await _databaseService.markAsSynced('notes', noteId);
        } catch (e) {
          debugPrint('Failed to sync note deletion: $e');
        }
      }

      await _loadLocalData();
      _error = null;
    } catch (e) {
      _error = 'Failed to delete note: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> archiveNote(String noteId, bool archived) async {
    try {
      final note = _notes.firstWhere((n) => n.id == noteId);
      final updatedNote = note.copyWith(
        archived: archived,
        updatedAt: DateTime.now(),
      );

      await updateNote(updatedNote);
    } catch (e) {
      _error = 'Failed to archive note: $e';
      notifyListeners();
    }
  }

  Future<void> bulkDeleteNotes(List<String> noteIds) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Delete locally
      for (final noteId in noteIds) {
        await _databaseService.deleteNote(noteId);
      }

      // Try to sync with server
      if (_isOnline) {
        try {
          await _apiService.bulkDeleteNotes(noteIds);
          for (final noteId in noteIds) {
            await _databaseService.markAsSynced('notes', noteId);
          }
        } catch (e) {
          debugPrint('Failed to sync bulk deletion: $e');
        }
      }

      await _loadLocalData();
      _error = null;
    } catch (e) {
      _error = 'Failed to delete notes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Category operations
  Future<void> addCategory(app_models.Category category) async {
    try {
      _isLoading = true;
      notifyListeners();

      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final categoryWithId = category.copyWith(
        id: localId,
        userId: _currentUserId ?? 'offline_user',
      );

      // Save locally
      await _databaseService.insertCategory(categoryWithId);

      // Try to sync with server
      if (_isOnline) {
        try {
          final serverCategory = await _apiService.createCategory(
            categoryWithId,
          );
          await _databaseService.updateCategory(serverCategory);
          await _databaseService.markAsSynced('categories', serverCategory.id);
        } catch (e) {
          debugPrint('Failed to sync category creation: $e');
        }
      }

      await _loadLocalData();
      _error = null;
    } catch (e) {
      _error = 'Failed to add category: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filter and sort operations
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSortBy(String sortBy, {bool? ascending}) {
    _sortBy = sortBy;
    if (ascending != null) {
      _sortAscending = ascending;
    }
    notifyListeners();
  }

  void toggleSortOrder() {
    _sortAscending = !_sortAscending;
    notifyListeners();
  }

  void setShowArchived(bool showArchived) {
    _showArchived = showArchived;
    notifyListeners();
  }

  // Utility methods
  Future<void> refreshNotes() async {
    await initialize();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Note? getNoteById(String id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }

  app_models.Category? getCategoryByName(String name) {
    try {
      return categories.firstWhere((category) => category.name == name);
    } catch (e) {
      return null;
    }
  }

  List<String> getAllTags() {
    final Set<String> tags = {};
    for (final note in _notes) {
      tags.addAll(note.tags);
    }
    return tags.toList()..sort();
  }
}
