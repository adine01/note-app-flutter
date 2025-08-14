import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../models/category.dart' as app_models;

class AddEditNoteScreen extends StatefulWidget {
  final Note? note;

  const AddEditNoteScreen({super.key, this.note});

  @override
  State<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends State<AddEditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();

  String? _selectedCategory;
  List<String> _tags = [];
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _selectedCategory = widget.note!.category;
      _tags = List.from(widget.note!.tags);
    }

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _hasChanges) {
          _showDiscardDialog();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Note' : 'New Note'),
          actions: [
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: _saveNote,
                child: Text(isEditing ? 'Update' : 'Save'),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title field
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter note title...',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Category row with dropdown and add button
                  Consumer<NoteProvider>(
                    builder: (context, noteProvider, child) {
                      final items = [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No Category'),
                        ),
                        ...noteProvider.categories.map(
                          (category) => DropdownMenuItem<String?>(
                            value: category.name,
                            child: Text(category.name),
                          ),
                        ),
                      ];
                      final hasExactOneMatch = _selectedCategory == null
                          ? true
                          : noteProvider.categories
                                    .where((c) => c.name == _selectedCategory)
                                    .length ==
                                1;
                      if (!hasExactOneMatch) {
                        // Reset invalid selection to avoid dropdown assertion
                        _selectedCategory = null;
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: items,
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                  _hasChanges = true;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Add category',
                            onPressed: () => _showAddCategoryDialog(context),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Tags section
                  _buildTagsSection(),
                  const SizedBox(height: 16),

                  // Content field (no Expanded/expands to avoid overflow)
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      hintText: 'Write your note here...',
                      alignLabelWithHint: true,
                    ),
                    minLines: 12,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter some content';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: isEditing ? _buildBottomActions() : null,
      ),
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final nameController = TextEditingController();
    String selectedColor = '#4CAF50'; // default green
    final presetColors = <String>[
      '#F44336', // red
      '#E91E63', // pink
      '#9C27B0', // purple
      '#3F51B5', // indigo
      '#2196F3', // blue
      '#03A9F4', // light blue
      '#00BCD4', // cyan
      '#009688', // teal
      '#4CAF50', // green
      '#8BC34A', // light green
      '#CDDC39', // lime
      '#FFC107', // amber
      '#FF9800', // orange
      '#FF5722', // deep orange
      '#795548', // brown
      '#607D8B', // blue grey
    ];

    Color _hexToColor(String hex) {
      final buffer = StringBuffer();
      if (hex.length == 7 && hex.startsWith('#')) {
        buffer.write('ff');
        buffer.write(hex.substring(1));
      }
      return Color(int.parse(buffer.toString(), radix: 16));
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
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
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Color',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presetColors.map((hex) {
                  final color = _hexToColor(hex);
                  final isSelected = selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setStateDialog(() => selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onSurface
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a category name'),
                    ),
                  );
                  return;
                }
                final provider = this.context.read<NoteProvider>();
                if (provider.getCategoryByName(name) != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Category already exists')),
                  );
                  return;
                }
                final newCategory = app_models.Category(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  color: selectedColor,
                  userId: 'offline_user',
                );
                try {
                  await provider.addCategory(newCategory);
                  if (mounted) {
                    setState(() {
                      _selectedCategory = name;
                      _hasChanges = true;
                    });
                  }
                  if (context.mounted) Navigator.pop(dialogContext);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add category: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _tagController,
                decoration: const InputDecoration(
                  labelText: 'Add Tag',
                  hintText: 'Enter tag name...',
                  prefixIcon: Icon(Icons.tag),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _addTag(_tagController.text),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _tags
                .map(
                  (tag) => Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeTag(tag),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomActions() {
    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _archiveNote(),
                  icon: Icon(
                    widget.note!.archived ? Icons.unarchive : Icons.archive,
                  ),
                ),
                Text(
                  widget.note!.archived ? 'Unarchive' : 'Archive',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _shareNote,
                  icon: const Icon(Icons.share),
                ),
                const Text('Share', style: TextStyle(fontSize: 12)),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _deleteNote,
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
                const Text('Delete', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty && !_tags.contains(trimmedTag)) {
      setState(() {
        _tags.add(trimmedTag);
        _tagController.clear();
        _hasChanges = true;
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _hasChanges = true;
    });
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final noteProvider = context.read<NoteProvider>();
      final now = DateTime.now();

      if (widget.note != null) {
        // Update existing note
        final updatedNote = widget.note!.copyWith(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _selectedCategory?.isNotEmpty == true
              ? _selectedCategory
              : null,
          tags: _tags,
          updatedAt: now,
        );

        await noteProvider.updateNote(updatedNote);
      } else {
        // Create new note
        final newNote = Note(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _selectedCategory?.isNotEmpty == true
              ? _selectedCategory
              : null,
          tags: _tags,
          archived: false,
          createdAt: now,
          updatedAt: now,
          userId: 'current_user', // This would come from auth provider
        );

        await noteProvider.addNote(newNote);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving note: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _archiveNote() async {
    if (widget.note == null) return;

    try {
      final noteProvider = context.read<NoteProvider>();
      await noteProvider.archiveNote(widget.note!.id, !widget.note!.archived);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.note!.archived ? 'Note unarchived' : 'Note archived',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _shareNote() {
    if (widget.note == null) return;

    final text = '${widget.note!.title}\n\n${widget.note!.content}';
    Share.share(text, subject: widget.note!.title);
  }

  void _deleteNote() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text(
          'Are you sure you want to delete "${widget.note!.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              try {
                final noteProvider = context.read<NoteProvider>();
                await noteProvider.deleteNote(widget.note!.id);

                if (!mounted) return;
                Navigator.pop(context); // Close screen
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Note deleted')));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting note: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
