import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import '../models/user.dart';
import '../models/category.dart';

class ApiService {
  // Base URL: compile-time default, with optional runtime override
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/v1',
  );
  static const String _baseUrlOverrideKey = 'api_base_url_override';
  String? _baseUrlOverride;

  String get effectiveBaseUrl {
    // If user set an override, respect it
    final override = _baseUrlOverride ?? _defaultBaseUrl;
    // On Android emulator, localhost must be 10.0.2.2
    if (override.contains('localhost') && Platform.isAndroid) {
      return override.replaceFirst('localhost', '10.0.2.2');
    }
    return override;
  }

  static const String authTokenKey = 'auth_token';
  static const String userIdKey = 'user_id';

  // Singleton instance
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _authToken;
  String? _userId;

  Uri _uri(String path, {Map<String, String>? query}) {
    final base = effectiveBaseUrl.endsWith('/')
        ? effectiveBaseUrl.substring(0, effectiveBaseUrl.length - 1)
        : effectiveBaseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p').replace(queryParameters: query);
  }

  // Initialize the service with stored credentials and base URL override
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(authTokenKey);
    _userId = prefs.getString(userIdKey);
    _baseUrlOverride = prefs.getString(_baseUrlOverrideKey);
  }

  Future<void> setBaseUrlOverride(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.isEmpty) {
      await prefs.remove(_baseUrlOverrideKey);
      _baseUrlOverride = null;
    } else {
      await prefs.setString(_baseUrlOverrideKey, url);
      _baseUrlOverride = url;
    }
  }

  // Simple health check
  Future<bool> health() async {
    try {
      final response = await http.get(_uri('/health'));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // Helper method to get headers with authentication
  Map<String, String> _getHeaders({bool withAuth = true}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (withAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // Helper method to handle API responses
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw ApiException(
        message: error['error'] ?? 'Unknown error occurred',
        statusCode: response.statusCode,
        code: error['code'],
      );
    }
  }

  // Authentication methods
  Future<AuthResult> register(
    String email,
    String password,
    String name,
  ) async {
    try {
      final response = await http.post(
        _uri('/auth/register'),
        headers: _getHeaders(withAuth: false),
        body: json.encode({'email': email, 'password': password, 'name': name}),
      );

      final data = _handleResponse(response);
      final user = User.fromJson(data['data']['user']);
      final token = data['data']['token'] as String;

      await _saveAuthData(token, user.id);

      return AuthResult(user: user, token: token);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await http.post(
        _uri('/auth/login'),
        headers: _getHeaders(withAuth: false),
        body: json.encode({'email': email, 'password': password}),
      );

      final data = _handleResponse(response);
      final user = User.fromJson(data['data']['user']);
      final token = data['data']['token'] as String;

      await _saveAuthData(token, user.id);

      return AuthResult(user: user, token: token);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    try {
      if (_authToken != null) {
        await http.post(_uri('/auth/logout'), headers: _getHeaders());
      }
    } catch (_) {
      // ignore
    } finally {
      await _clearAuthData();
    }
  }

  Future<void> _saveAuthData(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(authTokenKey, token);
    await prefs.setString(userIdKey, userId);
    _authToken = token;
    _userId = userId;
  }

  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(authTokenKey);
    await prefs.remove(userIdKey);
    _authToken = null;
    _userId = null;
  }

  // Note methods
  Future<NotesResponse> getNotes({
    int page = 1,
    int limit = 20,
    String? search,
    String? sort,
    String? category,
    bool archived = false,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'archived': archived.toString(),
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (sort != null) queryParams['sort'] = sort;
      if (category != null) queryParams['category'] = category;

      final response = await http.get(
        _uri('/notes', query: queryParams),
        headers: _getHeaders(),
      );
      final data = _handleResponse(response);
      final notesData = data['data'];
      final notes = (notesData['notes'] as List)
          .map((noteJson) => Note.fromJson(noteJson))
          .toList();
      final pagination = PaginationInfo.fromJson(notesData['pagination']);
      return NotesResponse(notes: notes, pagination: pagination);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Note> getNote(String id) async {
    try {
      final response = await http.get(
        _uri('/notes/$id'),
        headers: _getHeaders(),
      );
      final data = _handleResponse(response);
      return Note.fromJson(data['data']['note']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Note> createNote(Note note) async {
    try {
      final response = await http.post(
        _uri('/notes'),
        headers: _getHeaders(),
        body: json.encode({
          'title': note.title,
          'content': note.content,
          'category': note.category,
          'tags': note.tags,
        }),
      );
      final data = _handleResponse(response);
      return Note.fromJson(data['data']['note']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Note> updateNote(Note note) async {
    try {
      final response = await http.put(
        _uri('/notes/${note.id}'),
        headers: _getHeaders(),
        body: json.encode({
          'title': note.title,
          'content': note.content,
          'category': note.category,
          'tags': note.tags,
        }),
      );
      final data = _handleResponse(response);
      return Note.fromJson(data['data']['note']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      final response = await http.delete(
        _uri('/notes/$id'),
        headers: _getHeaders(),
      );
      _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Note> archiveNote(String id, bool archived) async {
    try {
      final response = await http.post(
        _uri('/notes/$id/archive'),
        headers: _getHeaders(),
        body: json.encode({'archived': archived}),
      );
      final data = _handleResponse(response);
      return Note.fromJson(data['data']['note']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<BulkDeleteResponse> bulkDeleteNotes(List<String> noteIds) async {
    try {
      final response = await http.post(
        _uri('/notes/bulk-delete'),
        headers: _getHeaders(),
        body: json.encode({'note_ids': noteIds}),
      );
      final data = _handleResponse(response);
      return BulkDeleteResponse.fromJson(data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Category methods
  Future<List<Category>> getCategories() async {
    try {
      final response = await http.get(
        _uri('/categories'),
        headers: _getHeaders(),
      );
      final data = _handleResponse(response);
      return (data['data']['categories'] as List)
          .map((categoryJson) => Category.fromJson(categoryJson))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Category> createCategory(Category category) async {
    try {
      final response = await http.post(
        _uri('/categories'),
        headers: _getHeaders(),
        body: json.encode({'name': category.name, 'color': category.color}),
      );
      final data = _handleResponse(response);
      return Category.fromJson(data['data']['category']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Search
  Future<SearchResponse> search({
    required String query,
    String searchIn = 'both',
    String? category,
    List<String>? tags,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final qp = <String, String>{'q': query, 'in': searchIn};
      if (category != null) qp['category'] = category;
      if (tags != null && tags.isNotEmpty) qp['tags'] = tags.join(',');
      if (dateFrom != null) qp['date_from'] = dateFrom.toIso8601String();
      if (dateTo != null) qp['date_to'] = dateTo.toIso8601String();

      final response = await http.get(
        _uri('/search', query: qp),
        headers: _getHeaders(),
      );
      final data = _handleResponse(response);
      return SearchResponse.fromJson(data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Sync
  Future<SyncResponse> getSync({
    DateTime? lastSync,
    bool includeDeleted = false,
  }) async {
    try {
      final qp = <String, String>{};
      if (lastSync != null) qp['last_sync'] = lastSync.toIso8601String();
      if (includeDeleted) qp['include_deleted'] = 'true';

      final response = await http.get(
        _uri('/sync', query: qp),
        headers: _getHeaders(),
      );
      final data = _handleResponse(response);
      return SyncResponse.fromJson(data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<SyncPushResponse> pushSync(SyncPushRequest syncData) async {
    try {
      final response = await http.post(
        _uri('/sync'),
        headers: _getHeaders(),
        body: json.encode(syncData.toJson()),
      );
      final data = _handleResponse(response);
      return SyncPushResponse.fromJson(data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Helper properties
  bool get isAuthenticated => _authToken != null;
  String? get userId => _userId;
  String? get authToken => _authToken;

  Exception _handleError(dynamic error) {
    if (error is ApiException) return error;
    if (error is SocketException) {
      return ApiException(message: 'No internet connection', statusCode: 0);
    }
    return ApiException(message: error.toString(), statusCode: 0);
  }
}

// Data classes for API responses
class AuthResult {
  final User user;
  final String token;

  AuthResult({required this.user, required this.token});
}

class NotesResponse {
  final List<Note> notes;
  final PaginationInfo pagination;

  NotesResponse({required this.notes, required this.pagination});
}

class PaginationInfo {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;

  PaginationInfo({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: json['current_page'] as int,
      totalPages: json['total_pages'] as int,
      totalItems: json['total_items'] as int,
      itemsPerPage: json['items_per_page'] as int,
    );
  }
}

class BulkDeleteResponse {
  final int deletedCount;
  final List<String> failedIds;

  BulkDeleteResponse({required this.deletedCount, required this.failedIds});

  factory BulkDeleteResponse.fromJson(Map<String, dynamic> json) {
    return BulkDeleteResponse(
      deletedCount: json['deleted_count'] as int,
      failedIds: List<String>.from(json['failed_ids'] as List),
    );
  }
}

class SearchResponse {
  final List<SearchResult> results;
  final int totalResults;
  final int searchTimeMs;

  SearchResponse({
    required this.results,
    required this.totalResults,
    required this.searchTimeMs,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      results: (json['results'] as List)
          .map((result) => SearchResult.fromJson(result))
          .toList(),
      totalResults: json['total_results'] as int,
      searchTimeMs: json['search_time_ms'] as int,
    );
  }
}

class SearchResult {
  final Note note;
  final double relevanceScore;
  final Map<String, List<String>> matches;

  SearchResult({
    required this.note,
    required this.relevanceScore,
    required this.matches,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final note = Note.fromJson(json);
    return SearchResult(
      note: note,
      relevanceScore: (json['relevance_score'] as num).toDouble(),
      matches: Map<String, List<String>>.from(
        json['matches'].map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      ),
    );
  }
}

class SyncResponse {
  final SyncData notes;
  final SyncData categories;
  final DateTime syncTimestamp;

  SyncResponse({
    required this.notes,
    required this.categories,
    required this.syncTimestamp,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      notes: SyncData.fromJson(json['notes']),
      categories: SyncData.fromJson(json['categories']),
      syncTimestamp: DateTime.parse(json['sync_timestamp']),
    );
  }
}

class SyncData {
  final List<Map<String, dynamic>> created;
  final List<Map<String, dynamic>> updated;
  final List<String> deleted;

  SyncData({
    required this.created,
    required this.updated,
    required this.deleted,
  });

  factory SyncData.fromJson(Map<String, dynamic> json) {
    return SyncData(
      created: List<Map<String, dynamic>>.from(json['created'] ?? []),
      updated: List<Map<String, dynamic>>.from(json['updated'] ?? []),
      deleted: List<String>.from(json['deleted'] ?? []),
    );
  }
}

class SyncPushRequest {
  final Map<String, dynamic> notes;
  final Map<String, dynamic> categories;
  final DateTime? lastSync;

  SyncPushRequest({
    required this.notes,
    required this.categories,
    this.lastSync,
  });

  Map<String, dynamic> toJson() {
    return {
      'notes': notes,
      'categories': categories,
      if (lastSync != null) 'last_sync': lastSync!.toIso8601String(),
    };
  }
}

class SyncPushResponse {
  final List<dynamic> conflicts;
  final Map<String, Map<String, String>> createdIds;
  final DateTime syncTimestamp;

  SyncPushResponse({
    required this.conflicts,
    required this.createdIds,
    required this.syncTimestamp,
  });

  factory SyncPushResponse.fromJson(Map<String, dynamic> json) {
    return SyncPushResponse(
      conflicts: json['conflicts'] as List,
      createdIds: Map<String, Map<String, String>>.from(
        json['created_ids'].map(
          (key, value) => MapEntry(key, Map<String, String>.from(value)),
        ),
      ),
      syncTimestamp: DateTime.parse(json['sync_timestamp']),
    );
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String? code;

  ApiException({required this.message, required this.statusCode, this.code});

  @override
  String toString() =>
      'ApiException: $message (Status: $statusCode, Code: $code)';
}
