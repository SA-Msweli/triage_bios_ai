import 'package:flutter/material.dart';
import '../../../../shared/services/integrated_auth_service.dart';
import '../../../../shared/services/ldap_service.dart';
import '../../../../shared/services/auth_service.dart';

/// LDAP/Active Directory configuration page for administrators
class LdapConfigPage extends StatefulWidget {
  const LdapConfigPage({super.key});

  @override
  State<LdapConfigPage> createState() => _LdapConfigPageState();
}

class _LdapConfigPageState extends State<LdapConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final IntegratedAuthService _authService = IntegratedAuthService();

  // Form controllers
  final _serverUrlController = TextEditingController();
  final _portController = TextEditingController(text: '389');
  final _baseDnController = TextEditingController();
  final _bindDnController = TextEditingController();
  final _bindPasswordController = TextEditingController();
  final _userSearchBaseController = TextEditingController();
  final _userSearchFilterController = TextEditingController(
    text: '(sAMAccountName={username})',
  );
  final _groupSearchBaseController = TextEditingController();
  final _groupSearchFilterController = TextEditingController(
    text: '(member={userDn})',
  );

  AuthenticationMode _selectedMode = AuthenticationMode.local;
  bool _useSSL = false;
  bool _useStartTLS = true;
  bool _isLoading = false;
  bool _isTestingConnection = false;
  String? _connectionTestResult;
  LdapSyncStatus? _syncStatus;

  final Map<String, UserRole> _groupRoleMapping = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
    _loadSyncStatus();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _portController.dispose();
    _baseDnController.dispose();
    _bindDnController.dispose();
    _bindPasswordController.dispose();
    _userSearchBaseController.dispose();
    _userSearchFilterController.dispose();
    _groupSearchBaseController.dispose();
    _groupSearchFilterController.dispose();
    super.dispose();
  }

  void _loadCurrentConfig() {
    final config = _authService.ldapConfig;
    if (config != null) {
      _serverUrlController.text = config.serverUrl;
      _portController.text = config.port.toString();
      _baseDnController.text = config.baseDn;
      _bindDnController.text = config.bindDn;
      _userSearchBaseController.text = config.userSearchBase;
      _userSearchFilterController.text = config.userSearchFilter;
      _groupSearchBaseController.text = config.groupSearchBase;
      _groupSearchFilterController.text = config.groupSearchFilter;
      _useSSL = config.useSSL;
      _useStartTLS = config.useStartTLS;
      _groupRoleMapping.addAll(config.groupRoleMapping);
    }

    _selectedMode = _authService.authenticationMode;
  }

  void _loadSyncStatus() {
    setState(() {
      _syncStatus = _authService.getLdapSyncStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LDAP/Active Directory Configuration'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 24),
              _buildAuthenticationModeSection(),
              const SizedBox(height: 24),
              _buildServerConfigSection(),
              const SizedBox(height: 24),
              _buildSearchConfigSection(),
              const SizedBox(height: 24),
              _buildGroupMappingSection(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _syncStatus?.isInitialized == true
                      ? Icons.check_circle
                      : Icons.error,
                  color: _syncStatus?.isInitialized == true
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'LDAP Integration Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Mode', _selectedMode.name.toUpperCase()),
            _buildStatusRow(
              'Server',
              _syncStatus?.serverUrl ?? 'Not configured',
            ),
            _buildStatusRow('Base DN', _syncStatus?.baseDn ?? 'Not configured'),
            if (_syncStatus?.lastSyncTime != null)
              _buildStatusRow(
                'Last Sync',
                _formatDateTime(_syncStatus!.lastSyncTime!),
              ),
            if (_connectionTestResult != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _connectionTestResult!.contains('Success')
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _connectionTestResult!,
                  style: TextStyle(
                    color: _connectionTestResult!.contains('Success')
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticationModeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Authentication Mode',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...AuthenticationMode.values.map(
              (mode) => RadioListTile<AuthenticationMode>(
                title: Text(_getAuthModeTitle(mode)),
                subtitle: Text(_getAuthModeDescription(mode)),
                value: mode,
                groupValue: _selectedMode,
                onChanged: (value) {
                  setState(() {
                    _selectedMode = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerConfigSection() {
    if (_selectedMode == AuthenticationMode.local) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'ldap://dc.hospital.com',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Server URL is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Port is required';
                      }
                      final port = int.tryParse(value);
                      if (port == null || port < 1 || port > 65535) {
                        return 'Invalid port number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('Use SSL'),
                        value: _useSSL,
                        onChanged: (value) {
                          setState(() {
                            _useSSL = value!;
                            if (_useSSL) {
                              _useStartTLS = false;
                              _portController.text = '636';
                            } else {
                              _portController.text = '389';
                            }
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Use StartTLS'),
                        value: _useStartTLS,
                        onChanged: (value) {
                          setState(() {
                            _useStartTLS = value!;
                            if (_useStartTLS) {
                              _useSSL = false;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _baseDnController,
              decoration: const InputDecoration(
                labelText: 'Base DN',
                hintText: 'DC=hospital,DC=com',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Base DN is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bindDnController,
              decoration: const InputDecoration(
                labelText: 'Bind DN',
                hintText:
                    'CN=service-account,OU=Service Accounts,DC=hospital,DC=com',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Bind DN is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bindPasswordController,
              decoration: const InputDecoration(
                labelText: 'Bind Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Bind password is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchConfigSection() {
    if (_selectedMode == AuthenticationMode.local) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _userSearchBaseController,
              decoration: const InputDecoration(
                labelText: 'User Search Base',
                hintText: 'OU=Users,DC=hospital,DC=com',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'User search base is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _userSearchFilterController,
              decoration: const InputDecoration(
                labelText: 'User Search Filter',
                hintText: '(sAMAccountName={username})',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupSearchBaseController,
              decoration: const InputDecoration(
                labelText: 'Group Search Base',
                hintText: 'OU=Groups,DC=hospital,DC=com',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Group search base is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupSearchFilterController,
              decoration: const InputDecoration(
                labelText: 'Group Search Filter',
                hintText: '(member={userDn})',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupMappingSection() {
    if (_selectedMode == AuthenticationMode.local) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Group Role Mapping',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addGroupMapping,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Mapping'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_groupRoleMapping.isEmpty)
              const Text(
                'No group mappings configured. Add mappings to automatically assign roles based on LDAP groups.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ..._groupRoleMapping.entries.map(
                (entry) => _buildGroupMappingItem(entry.key, entry.value),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupMappingItem(String group, UserRole role) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(group),
        subtitle: Text('Maps to: ${role.name}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            setState(() {
              _groupRoleMapping.remove(group);
            });
          },
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isTestingConnection ? null : _testConnection,
                icon: _isTestingConnection
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_protected_setup),
                label: Text(
                  _isTestingConnection ? 'Testing...' : 'Test Connection',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selectedMode == AuthenticationMode.local
                    ? null
                    : _syncUsers,
                icon: const Icon(Icons.sync),
                label: const Text('Sync Users'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveConfiguration,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isLoading ? 'Saving...' : 'Save Configuration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _addGroupMapping() {
    showDialog(
      context: context,
      builder: (context) => _GroupMappingDialog(
        onAdd: (group, role) {
          setState(() {
            _groupRoleMapping[group] = role;
          });
        },
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
    });

    try {
      final config = _buildLdapConfig();
      final success = await _authService.configureLdap(config, _selectedMode);

      setState(() {
        _connectionTestResult = success
            ? 'Connection test successful!'
            : 'Connection test failed. Please check your configuration.';
      });
    } catch (e) {
      setState(() {
        _connectionTestResult = 'Connection test failed: $e';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _syncUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.synchronizeUsersFromLdap();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Synchronized ${result.successCount} users successfully'
                  : 'Synchronization failed: ${result.error}',
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }

      _loadSyncStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synchronization error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedMode != AuthenticationMode.local) {
        final config = _buildLdapConfig();
        final success = await _authService.configureLdap(config, _selectedMode);

        if (!success) {
          throw Exception('Failed to configure LDAP');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadSyncStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  LdapConfig _buildLdapConfig() {
    return LdapConfig(
      serverUrl: _serverUrlController.text.trim(),
      port: int.parse(_portController.text.trim()),
      baseDn: _baseDnController.text.trim(),
      bindDn: _bindDnController.text.trim(),
      bindPassword: _bindPasswordController.text.trim(),
      userSearchBase: _userSearchBaseController.text.trim(),
      userSearchFilter: _userSearchFilterController.text.trim(),
      groupSearchBase: _groupSearchBaseController.text.trim(),
      groupSearchFilter: _groupSearchFilterController.text.trim(),
      useSSL: _useSSL,
      useStartTLS: _useStartTLS,
      groupRoleMapping: Map.from(_groupRoleMapping),
    );
  }

  String _getAuthModeTitle(AuthenticationMode mode) {
    switch (mode) {
      case AuthenticationMode.local:
        return 'Local Authentication Only';
      case AuthenticationMode.ldapOnly:
        return 'LDAP/AD Authentication Only';
      case AuthenticationMode.ldapWithFallback:
        return 'LDAP/AD with Local Fallback';
    }
  }

  String _getAuthModeDescription(AuthenticationMode mode) {
    switch (mode) {
      case AuthenticationMode.local:
        return 'Use only local user database for authentication';
      case AuthenticationMode.ldapOnly:
        return 'Authenticate users only against LDAP/Active Directory';
      case AuthenticationMode.ldapWithFallback:
        return 'Try LDAP first, fallback to local authentication if LDAP fails';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LDAP Configuration Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Server Configuration:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '• Server URL: The LDAP server address (e.g., ldap://dc.hospital.com)',
              ),
              Text('• Port: 389 for LDAP, 636 for LDAPS'),
              Text('• Base DN: The root of your directory tree'),
              Text('• Bind DN: Service account for LDAP queries'),
              SizedBox(height: 16),
              Text(
                'Search Configuration:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• User Search Base: Where to search for users'),
              Text(
                '• User Search Filter: How to find users (use {username} placeholder)',
              ),
              Text('• Group Search Base: Where to search for groups'),
              Text('• Group Search Filter: How to find group memberships'),
              SizedBox(height: 16),
              Text(
                'Group Mapping:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Map LDAP groups to application roles'),
              Text('• Users will get roles based on their group memberships'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _GroupMappingDialog extends StatefulWidget {
  final Function(String group, UserRole role) onAdd;

  const _GroupMappingDialog({required this.onAdd});

  @override
  State<_GroupMappingDialog> createState() => _GroupMappingDialogState();
}

class _GroupMappingDialogState extends State<_GroupMappingDialog> {
  final _groupController = TextEditingController();
  UserRole _selectedRole = UserRole.patient;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Group Mapping'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _groupController,
            decoration: const InputDecoration(
              labelText: 'LDAP Group DN',
              hintText: 'CN=Doctors,OU=Groups,DC=hospital,DC=com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<UserRole>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Application Role',
              border: OutlineInputBorder(),
            ),
            items: UserRole.values
                .map(
                  (role) =>
                      DropdownMenuItem(value: role, child: Text(role.name)),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedRole = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_groupController.text.trim().isNotEmpty) {
              widget.onAdd(_groupController.text.trim(), _selectedRole);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
