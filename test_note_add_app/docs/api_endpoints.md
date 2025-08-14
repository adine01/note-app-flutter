# Notes API Documentation

## Base URL
```
https://api.notes-app.com/v1
```

## Authentication
All authenticated endpoints require a Bearer token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

---

## Endpoints

### Authentication

#### POST /auth/register
Register a new user account.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123",
  "name": "John Doe"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "User registered successfully",
  "data": {
    "user": {
      "id": "user_123",
      "email": "user@example.com",
      "name": "John Doe",
      "created_at": "2025-08-07T10:30:00Z"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Error Response (400 Bad Request):**
```json
{
  "success": false,
  "error": "Email already exists",
  "code": "EMAIL_EXISTS"
}
```

---

#### POST /auth/login
Authenticate user and get access token.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": "user_123",
      "email": "user@example.com",
      "name": "John Doe"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Error Response (401 Unauthorized):**
```json
{
  "success": false,
  "error": "Invalid credentials",
  "code": "INVALID_CREDENTIALS"
}
```

---

#### POST /auth/logout
Logout user and invalidate token.

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Logout successful"
}
```

---

### Notes Management

#### GET /notes
Get all notes for authenticated user with optional pagination and filtering.

**Headers:** `Authorization: Bearer <token>`

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20, max: 100)
- `search` (optional): Search term for title/content
- `sort` (optional): Sort order (`date_desc`, `date_asc`, `title_asc`, `title_desc`, `modified_desc`, `modified_asc`)
- `category` (optional): Filter by category
- `archived` (optional): Include archived notes (`true`/`false`, default: `false`)

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "notes": [
      {
        "id": "note_123",
        "title": "My First Note",
        "content": "This is the content of my note...",
        "category": "personal",
        "tags": ["important", "todo"],
        "archived": false,
        "created_at": "2025-08-07T10:30:00Z",
        "updated_at": "2025-08-07T11:45:00Z"
      }
    ],
    "pagination": {
      "current_page": 1,
      "total_pages": 5,
      "total_items": 95,
      "items_per_page": 20
    }
  }
}
```

---

#### GET /notes/:id
Get a specific note by ID.

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "note": {
      "id": "note_123",
      "title": "My First Note",
      "content": "This is the content of my note...",
      "category": "personal",
      "tags": ["important", "todo"],
      "archived": false,
      "created_at": "2025-08-07T10:30:00Z",
      "updated_at": "2025-08-07T11:45:00Z"
    }
  }
}
```

**Error Response (404 Not Found):**
```json
{
  "success": false,
  "error": "Note not found",
  "code": "NOTE_NOT_FOUND"
}
```

---

#### POST /notes
Create a new note.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "title": "My New Note",
  "content": "This is the content of my new note...",
  "category": "work",
  "tags": ["meeting", "project"]
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Note created successfully",
  "data": {
    "note": {
      "id": "note_124",
      "title": "My New Note",
      "content": "This is the content of my new note...",
      "category": "work",
      "tags": ["meeting", "project"],
      "archived": false,
      "created_at": "2025-08-07T12:00:00Z",
      "updated_at": "2025-08-07T12:00:00Z"
    }
  }
}
```

**Error Response (400 Bad Request):**
```json
{
  "success": false,
  "error": "Title is required",
  "code": "VALIDATION_ERROR",
  "details": {
    "title": "Title cannot be empty"
  }
}
```

---

#### PUT /notes/:id
Update an existing note.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "title": "Updated Note Title",
  "content": "Updated content...",
  "category": "personal",
  "tags": ["updated", "important"]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Note updated successfully",
  "data": {
    "note": {
      "id": "note_123",
      "title": "Updated Note Title",
      "content": "Updated content...",
      "category": "personal",
      "tags": ["updated", "important"],
      "archived": false,
      "created_at": "2025-08-07T10:30:00Z",
      "updated_at": "2025-08-07T12:30:00Z"
    }
  }
}
```

---

#### DELETE /notes/:id
Delete a note (soft delete).

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Note deleted successfully"
}
```

**Error Response (404 Not Found):**
```json
{
  "success": false,
  "error": "Note not found",
  "code": "NOTE_NOT_FOUND"
}
```

---

#### POST /notes/:id/archive
Archive or unarchive a note.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "archived": true
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Note archived successfully",
  "data": {
    "note": {
      "id": "note_123",
      "title": "My Note",
      "archived": true,
      "updated_at": "2025-08-07T12:45:00Z"
    }
  }
}
```

---

#### POST /notes/bulk-delete
Delete multiple notes at once.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "note_ids": ["note_123", "note_124", "note_125"]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "3 notes deleted successfully",
  "data": {
    "deleted_count": 3,
    "failed_ids": []
  }
}
```

---

### Categories

#### GET /categories
Get all categories for the authenticated user.

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "categories": [
      {
        "id": "cat_1",
        "name": "personal",
        "color": "#FF5733",
        "note_count": 15
      },
      {
        "id": "cat_2",
        "name": "work",
        "color": "#3498DB",
        "note_count": 23
      }
    ]
  }
}
```

---

#### POST /categories
Create a new category.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "name": "travel",
  "color": "#28B463"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Category created successfully",
  "data": {
    "category": {
      "id": "cat_3",
      "name": "travel",
      "color": "#28B463",
      "note_count": 0
    }
  }
}
```

---

### Search

#### GET /search
Advanced search across notes.

**Headers:** `Authorization: Bearer <token>`

**Query Parameters:**
- `q` (required): Search query
- `in` (optional): Search scope (`title`, `content`, `both` - default: `both`)
- `category` (optional): Filter by category
- `tags` (optional): Comma-separated list of tags
- `date_from` (optional): ISO date string
- `date_to` (optional): ISO date string

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "results": [
      {
        "id": "note_123",
        "title": "Meeting Notes",
        "content": "Important meeting with clients...",
        "category": "work",
        "tags": ["meeting", "clients"],
        "relevance_score": 0.95,
        "matches": {
          "title": ["Meeting"],
          "content": ["clients", "important"]
        },
        "created_at": "2025-08-07T10:30:00Z"
      }
    ],
    "total_results": 1,
    "search_time_ms": 45
  }
}
```

---

### File Attachments

#### POST /notes/:id/attachments
Upload file attachment to a note.

**Headers:** 
- `Authorization: Bearer <token>`
- `Content-Type: multipart/form-data`

**Request Body:**
```
file: <binary file data>
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "File uploaded successfully",
  "data": {
    "attachment": {
      "id": "att_123",
      "filename": "document.pdf",
      "size": 1024000,
      "mime_type": "application/pdf",
      "url": "https://cdn.notes-app.com/files/att_123/document.pdf",
      "uploaded_at": "2025-08-07T13:00:00Z"
    }
  }
}
```

---

#### DELETE /attachments/:id
Delete a file attachment.

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Attachment deleted successfully"
}
```

---

### Sync

#### GET /sync
Get incremental sync data for offline-first clients.

**Headers:** `Authorization: Bearer <token>`

**Query Parameters:**
- `last_sync` (optional): ISO timestamp of last sync
- `include_deleted` (optional): Include soft-deleted items (`true`/`false`)

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "notes": {
      "created": [/* new notes */],
      "updated": [/* modified notes */],
      "deleted": ["note_123", "note_124"]
    },
    "categories": {
      "created": [/* new categories */],
      "updated": [/* modified categories */],
      "deleted": ["cat_1"]
    },
    "sync_timestamp": "2025-08-07T13:30:00Z"
  }
}
```

---

#### POST /sync
Push local changes to server for sync.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "notes": {
    "create": [/* notes to create */],
    "update": [/* notes to update */],
    "delete": ["local_note_id_1"]
  },
  "categories": {
    "create": [/* categories to create */],
    "update": [/* categories to update */],
    "delete": ["local_cat_id_1"]
  },
  "last_sync": "2025-08-07T12:00:00Z"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Sync completed successfully",
  "data": {
    "conflicts": [],
    "created_ids": {
      "notes": {"local_temp_id_1": "note_125"},
      "categories": {"local_temp_cat_1": "cat_4"}
    },
    "sync_timestamp": "2025-08-07T13:35:00Z"
  }
}
```

---

## Error Codes

| Code | Description |
|------|-------------|
| `INVALID_CREDENTIALS` | Login credentials are incorrect |
| `EMAIL_EXISTS` | Email already registered |
| `TOKEN_EXPIRED` | JWT token has expired |
| `TOKEN_INVALID` | JWT token is malformed or invalid |
| `NOTE_NOT_FOUND` | Requested note doesn't exist |
| `CATEGORY_NOT_FOUND` | Requested category doesn't exist |
| `VALIDATION_ERROR` | Request data validation failed |
| `RATE_LIMIT_EXCEEDED` | Too many requests in time window |
| `FILE_TOO_LARGE` | Uploaded file exceeds size limit |
| `UNSUPPORTED_FILE_TYPE` | File type not allowed |
| `STORAGE_QUOTA_EXCEEDED` | User storage limit reached |

---

## Rate Limiting

- Authentication endpoints: 5 requests per minute per IP
- CRUD operations: 100 requests per minute per user
- Search endpoints: 30 requests per minute per user
- File upload: 10 requests per minute per user

Rate limit headers are included in responses:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1691412000
```

---

## Data Models

### Note
```json
{
  "id": "string",
  "title": "string (required, max 200 chars)",
  "content": "string (max 10000 chars)",
  "category": "string (optional)",
  "tags": ["string"] (optional, max 10 tags),
  "archived": "boolean",
  "created_at": "ISO 8601 timestamp",
  "updated_at": "ISO 8601 timestamp",
  "user_id": "string"
}
```

### Category
```json
{
  "id": "string",
  "name": "string (required, max 50 chars)",
  "color": "string (hex color, optional)",
  "note_count": "number",
  "user_id": "string"
}
```

### User
```json
{
  "id": "string",
  "email": "string (required, valid email)",
  "name": "string (required, max 100 chars)",
  "created_at": "ISO 8601 timestamp",
  "storage_used": "number (bytes)",
  "storage_limit": "number (bytes)"
}
```
