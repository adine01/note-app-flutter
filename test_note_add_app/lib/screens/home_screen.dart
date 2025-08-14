import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../providers/note_provider.dart';
import '../models/note.dart';
import '../models/category.dart' as app_models;
import '../widgets/note_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/search_bar.dart';
import 'add_edit_note_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<String> _selectedNotes = [];
  bool _isSelectionMode = false;

  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _searchController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: _isSearching
                ? CustomSearchBar(
                    controller: _searchController,
                    onChanged: (query) => noteProvider.setSearchQuery(query),
                    onCancel: () => _toggleSearch(),
                  )
                : const Text('My Notes'),
            actions: _buildAppBarActions(context, noteProvider),
            elevation: 0,
          ),
          body: _buildBody(context, noteProvider),
          floatingActionButton: _isSelectionMode
              ? null
              : ScaleTransition(
                  scale: _fabAnimation,
                  child: FloatingActionButton(
                    onPressed: () => _navigateToAddNote(context),
                    child: const Icon(Icons.add),
                  ),
                ),
          bottomNavigationBar: _isSelectionMode
              ? _buildSelectionBottomBar(context, noteProvider)
              : null,
        );
      },
    );
  }

  List<Widget> _buildAppBarActions(
    BuildContext context,
    NoteProvider noteProvider,
  ) {
    if (_isSelectionMode) {
      return [
        TextButton(
          onPressed: () => _exitSelectionMode(),
          child: const Text('Cancel'),
        ),
      ];
    }

    return [
      if (!_isSearching) ...[
        IconButton(icon: const Icon(Icons.search), onPressed: _toggleSearch),
        PopupMenuButton<String>(
          onSelected: (value) =>
              _handleMenuAction(context, value, noteProvider),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'sort',
              child: Row(
                children: [Icon(Icons.sort), SizedBox(width: 8), Text('Sort')],
              ),
            ),
            const PopupMenuItem(
              value: 'filter',
              child: Row(
                children: [
                  Icon(Icons.filter_list),
                  SizedBox(width: 8),
                  Text('Filter'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'archived',
              child: Row(
                children: [
                  Icon(
                    noteProvider.showArchived ? Icons.unarchive : Icons.archive,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    noteProvider.showArchived
                        ? 'Hide Archived'
                        : 'Show Archived',
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
          ],
        ),
      ] else ...[
        IconButton(icon: const Icon(Icons.close), onPressed: _toggleSearch),
      ],
    ];
  }

  Widget _buildBody(BuildContext context, NoteProvider noteProvider) {
    if (noteProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (noteProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: ${noteProvider.error}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => noteProvider.refreshNotes(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!noteProvider.hasNotes) {
      return EmptyState(
        icon: Icons.note_add,
        title: 'No notes yet',
        subtitle: 'Tap the + button to create your first note',
        onAction: () => _navigateToAddNote(context),
        actionText: 'Create Note',
      );
    }

    return SmartRefresher(
      controller: _refreshController,
      onRefresh: () => _onRefresh(noteProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: noteProvider.notes.length,
        itemBuilder: (context, index) {
          final note = noteProvider.notes[index];
          return NoteCard(
            note: note,
            isSelected: _selectedNotes.contains(note.id),
            onTap: () => _onNoteTap(context, note),
            onLongPress: () => _onNoteLongPress(note.id),
            onArchive: () => noteProvider.archiveNote(note.id, !note.archived),
            onDelete: () => _confirmDeleteNote(context, noteProvider, note),
          );
        },
      ),
    );
  }

  Widget _buildSelectionBottomBar(
    BuildContext context,
    NoteProvider noteProvider,
  ) {
    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.archive),
                  onPressed: () => _bulkArchiveNotes(noteProvider),
                ),
                const Text('Archive', style: TextStyle(fontSize: 12)),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _confirmBulkDelete(context, noteProvider),
                ),
                const Text('Delete', style: TextStyle(fontSize: 12)),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () => _selectAllNotes(noteProvider),
                ),
                const Text('Select All', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Event handlers
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        context.read<NoteProvider>().setSearchQuery('');
      }
    });
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    NoteProvider noteProvider,
  ) {
    switch (action) {
      case 'sort':
        _showSortDialog(context, noteProvider);
        break;
      case 'filter':
        _showFilterDialog(context, noteProvider);
        break;
      case 'archived':
        noteProvider.setShowArchived(!noteProvider.showArchived);
        break;
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        break;
    }
  }

  void _onRefresh(NoteProvider noteProvider) async {
    await noteProvider.refreshNotes();
    _refreshController.refreshCompleted();
  }

  void _onNoteTap(BuildContext context, Note note) {
    if (_isSelectionMode) {
      _toggleNoteSelection(note.id);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddEditNoteScreen(note: note)),
      );
    }
  }

  void _onNoteLongPress(String noteId) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedNotes.clear();
      });
    }
    _toggleNoteSelection(noteId);
  }

  void _toggleNoteSelection(String noteId) {
    setState(() {
      if (_selectedNotes.contains(noteId)) {
        _selectedNotes.remove(noteId);
        if (_selectedNotes.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedNotes.add(noteId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedNotes.clear();
    });
  }

  void _selectAllNotes(NoteProvider noteProvider) {
    setState(() {
      _selectedNotes = noteProvider.notes.map((note) => note.id).toList();
    });
  }

  void _navigateToAddNote(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditNoteScreen()),
    );
  }

  void _confirmDeleteNote(
    BuildContext context,
    NoteProvider noteProvider,
    Note note,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              noteProvider.deleteNote(note.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmBulkDelete(BuildContext context, NoteProvider noteProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notes'),
        content: Text(
          'Are you sure you want to delete ${_selectedNotes.length} notes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              noteProvider.bulkDeleteNotes(_selectedNotes);
              _exitSelectionMode();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _bulkArchiveNotes(NoteProvider noteProvider) {
    for (final noteId in _selectedNotes) {
      noteProvider.archiveNote(noteId, true);
    }
    _exitSelectionMode();
  }

  void _showSortDialog(BuildContext context, NoteProvider noteProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Notes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Date Modified'),
              value: 'updated_at',
              groupValue: noteProvider.sortBy,
              onChanged: (value) {
                if (value != null) {
                  noteProvider.setSortBy(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Date Created'),
              value: 'created_at',
              groupValue: noteProvider.sortBy,
              onChanged: (value) {
                if (value != null) {
                  noteProvider.setSortBy(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Title'),
              value: 'title',
              groupValue: noteProvider.sortBy,
              onChanged: (value) {
                if (value != null) {
                  noteProvider.setSortBy(value);
                  Navigator.pop(context);
                }
              },
            ),
            SwitchListTile(
              title: const Text('Ascending Order'),
              value: noteProvider.sortAscending,
              onChanged: (value) {
                noteProvider.setSortBy(noteProvider.sortBy, ascending: value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context, NoteProvider noteProvider) {
    final deduped = noteProvider.categories;
    if (noteProvider.selectedCategory != null &&
        !deduped.any((c) => c.name == noteProvider.selectedCategory)) {
      noteProvider.setSelectedCategory(null);
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Notes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Notes'),
              leading: Radio<String?>(
                value: null,
                groupValue: noteProvider.selectedCategory,
                onChanged: (value) {
                  noteProvider.setSelectedCategory(value);
                  Navigator.pop(context);
                },
              ),
            ),
            ...deduped.map(
              (category) => ListTile(
                title: Text(category.name),
                leading: Radio<String>(
                  value: category.name,
                  groupValue: noteProvider.selectedCategory,
                  onChanged: (value) {
                    noteProvider.setSelectedCategory(value);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  // Navigate to add note screen just to open add category dialog
                  // or reuse logic by showing a minimal dialog here
                  final nameController = TextEditingController();
                  String selectedColor = '#4CAF50';
                  final colors = [
                    '#F44336',
                    '#E91E63',
                    '#9C27B0',
                    '#3F51B5',
                    '#2196F3',
                    '#03A9F4',
                    '#00BCD4',
                    '#009688',
                    '#4CAF50',
                    '#8BC34A',
                    '#CDDC39',
                    '#FFC107',
                    '#FF9800',
                    '#FF5722',
                    '#795548',
                    '#607D8B',
                  ];
                  Color _hexToColor(String hex) {
                    final b = StringBuffer('ff');
                    b.write(hex.substring(1));
                    return Color(int.parse(b.toString(), radix: 16));
                  }

                  await showDialog(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx, setStateDialog) => AlertDialog(
                        title: const Text('Add Category'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Category name',
                                prefixIcon: Icon(Icons.label),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: colors.map((hex) {
                                final c = _hexToColor(hex);
                                final sel = selectedColor == hex;
                                return GestureDetector(
                                  onTap: () =>
                                      setStateDialog(() => selectedColor = hex),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: sel
                                            ? Theme.of(
                                                ctx,
                                              ).colorScheme.onSurface
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Enter a name')),
                                );
                                return;
                              }
                              if (noteProvider.getCategoryByName(name) !=
                                  null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Category already exists'),
                                  ),
                                );
                                return;
                              }
                              final cat = app_models.Category(
                                id: DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                                name: name,
                                color: selectedColor,
                                userId: 'offline_user',
                              );
                              await noteProvider.addCategory(cat);
                              if (mounted) {
                                noteProvider.setSelectedCategory(name);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add category'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              noteProvider.setSelectedCategory(null);
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
