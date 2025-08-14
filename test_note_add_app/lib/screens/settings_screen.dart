import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import 'login_screen.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer3<ThemeProvider, AuthProvider, NoteProvider>(
        builder: (context, themeProvider, authProvider, noteProvider, child) {
          return ListView(
            children: [
              // Theme Section
              _buildSectionHeader(context, 'Appearance'),
              ListTile(
                leading: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                ),
                title: const Text('Theme'),
                subtitle: Text(_getThemeDescription(themeProvider.themeMode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeDialog(context, themeProvider),
              ),
              const Divider(),

              // Data & Storage Section
              _buildSectionHeader(context, 'Data & Storage'),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Storage Usage'),
                subtitle: Text(
                  '${noteProvider.notesCount} notes stored locally',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sync Data'),
                subtitle: const Text('Sync with server'),
                trailing: noteProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: noteProvider.isLoading
                    ? null
                    : () => _syncData(context, noteProvider),
              ),
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('API Server'),
                subtitle: Text(ApiService().effectiveBaseUrl),
                trailing: const Icon(Icons.edit),
                onTap: () => _showServerUrlDialog(context, noteProvider),
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export Notes'),
                subtitle: const Text('Export all notes to file'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportNotes(context, noteProvider),
              ),
              const Divider(),

              // Account Section
              if (authProvider.isAuthenticated) ...[
                _buildSectionHeader(context, 'Account'),
                ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: const Text('Account'),
                  subtitle: Text(authProvider.user?.email ?? 'Unknown'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Sign Out'),
                  onTap: () => _showLogoutDialog(context, authProvider),
                ),
                const Divider(),
              ] else ...[
                _buildSectionHeader(context, 'Account'),
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Sign In'),
                  subtitle: const Text('Sign in to sync your notes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _navigateToLogin(context),
                ),
                const Divider(),
              ],

              // About Section
              _buildSectionHeader(context, 'About'),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About'),
                subtitle: const Text('Notes App v1.0.0'),
                onTap: () => _showAboutDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openPrivacyPolicy(),
              ),
              ListTile(
                leading: const Icon(Icons.article),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openTermsOfService(),
              ),

              // Danger Zone
              if (authProvider.isAuthenticated) ...[
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Danger Zone'),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    'Clear All Data',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('Delete all notes and reset app'),
                  onTap: () => _showClearDataDialog(context, noteProvider),
                ),
              ],

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getThemeDescription(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _syncData(BuildContext context, NoteProvider noteProvider) async {
    try {
      await noteProvider.refreshNotes();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data synced successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showServerUrlDialog(
    BuildContext context,
    NoteProvider noteProvider,
  ) async {
    final api = ApiService();
    final current = api.effectiveBaseUrl;
    final controller = TextEditingController(text: current);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Server URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'e.g. http://10.0.2.2:8080/v1 (Android Emulator)',
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tips:\n- Android emulator: http://10.0.2.2:8080/v1\n- iOS simulator: http://127.0.0.1:8080/v1\n- Desktop: http://localhost:8080/v1',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Reset to compile-time default
              await api.setBaseUrlOverride(null);
              if (context.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API URL reset to default')),
                );
              }
            },
            child: const Text('Reset'),
          ),
          FilledButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isEmpty) return;

              final prev = api.effectiveBaseUrl;
              await api.setBaseUrlOverride(newUrl);

              // Quick health check
              final ok = await api.health();
              if (!ok) {
                await api.setBaseUrlOverride(prev);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Health check failed. Reverted URL.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              if (context.mounted) Navigator.of(ctx).pop();
              // Refresh notes from new server
              try {
                await noteProvider.refreshNotes();
              } catch (_) {}

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('API URL updated: $newUrl')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _exportNotes(BuildContext context, NoteProvider noteProvider) async {
    try {
      // Collect notes as JSON
      final notes = noteProvider.notes;
      final jsonList = notes.map((n) => n.toJson()).toList();
      final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonList);

      // Determine file path in temp directory
      final tempDir = await getTemporaryDirectory();
      final filename =
          'notes_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
      final filePath = p.join(tempDir.path, filename);

      // Write file
      final file = File(filePath);
      await file.writeAsString(prettyJson);

      // Share the file
      await Share.shareXFiles([XFile(filePath)], text: 'My Notes Export');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exported notes successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.logout();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out successfully')),
                );
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Notes App',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 Notes App. All rights reserved.',
      children: [
        const SizedBox(height: 16),
        const Text(
          'A simple and elegant note-taking app with offline support and sync capabilities.',
        ),
      ],
    );
  }

  void _openPrivacyPolicy() {
    // Open privacy policy URL
    // You would use url_launcher package for this
  }

  void _openTermsOfService() {
    // Open terms of service URL
    // You would use url_launcher package for this
  }

  void _showClearDataDialog(BuildContext context, NoteProvider noteProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all your notes and reset the app. '
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // This would clear all data
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Clear data functionality would be implemented here',
                    ),
                  ),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing data: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Clear All Data',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
