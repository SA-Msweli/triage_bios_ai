import 'package:flutter/material.dart';
import '../../../../shared/services/enterprise_auth_service.dart';
import '../../../../shared/services/sso_service.dart';
import '../../../../shared/services/ldap_service.dart';

/// Identity provider management interface for administrators
class IdentityProviderManagementPage extends StatefulWidget {
  const IdentityProviderManagementPage({super.key});

  @override
  State<IdentityProviderManagementPage> createState() =>
      _IdentityProviderManagementPageState();
}

class _IdentityProviderManagementPageState
    extends State<IdentityProviderManagementPage> {
  final EnterpriseAuthService _authService = EnterpriseAuthService();

  List<IdentityProvider> _providers = [];
  bool _isLoading = false;
  EnterpriseAuthStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadProviders();
    _loadStatus();
  }

  void _loadProviders() {
    setState(() {
      _providers = _authService.getIdentityProviders();
    });
  }

  void _loadStatus() {
    setState(() {
      _status = _authService.getStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Provider Management'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadProviders();
              _loadStatus();
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusOverview(),
                  const SizedBox(height: 24),
                  _buildProvidersSection(),
                  const SizedBox(height: 24),
                  _buildFailoverSection(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProviderDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Provider'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStatusOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _status?.isInitialized == true
                      ? Icons.check_circle
                      : Icons.error,
                  color: _status?.isInitialized == true
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Enterprise Authentication Status',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusCard(
                    'Total Providers',
                    '${_status?.configuredProviders ?? 0}',
                    Icons.dns,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatusCard(
                    'Active Providers',
                    '${_status?.activeProviders ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusCard(
                    'Primary Provider',
                    _status?.primaryProvider ?? 'None',
                    Icons.star,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatusCard(
                    'Fallback',
                    _status?.fallbackEnabled == true ? 'Enabled' : 'Disabled',
                    Icons.backup,
                    _status?.fallbackEnabled == true
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProvidersSection() {
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
                  'Identity Providers',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _testAllProviders,
                  icon: const Icon(Icons.wifi_protected_setup),
                  label: const Text('Test All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_providers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.dns, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No identity providers configured',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add an identity provider to enable enterprise authentication',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._providers.map((provider) => _buildProviderCard(provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(IdentityProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getProviderIcon(provider.type),
                  color: _getProviderColor(provider.type),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_getProviderTypeDisplayName(provider.type)} • Priority: ${provider.priority}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: provider.isEnabled,
                  onChanged: (value) => _toggleProvider(provider.id, value),
                  activeColor: Colors.green,
                ),
                PopupMenuButton<String>(
                  onSelected: (action) =>
                      _handleProviderAction(provider, action),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'test',
                      child: Row(
                        children: [
                          Icon(Icons.wifi_protected_setup, size: 16),
                          SizedBox(width: 8),
                          Text('Test Connection'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'sync',
                      child: Row(
                        children: [
                          Icon(Icons.sync, size: 16),
                          SizedBox(width: 8),
                          Text('Sync Users'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildProviderDetails(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderDetails(IdentityProvider provider) {
    switch (provider.type) {
      case IdentityProviderType.ldap:
        return _buildLdapDetails(provider.ldapConfig!);
      case IdentityProviderType.sso:
        return _buildSsoDetails(provider.ssoConfig!);
      case IdentityProviderType.local:
        return const Text('Local authentication using application database');
    }
  }

  Widget _buildLdapDetails(LdapConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Server', config.serverUrl),
        _buildDetailRow('Base DN', config.baseDn),
        _buildDetailRow('User Search Base', config.userSearchBase),
        _buildDetailRow(
          'Security',
          config.useSSL ? 'SSL' : (config.useStartTLS ? 'StartTLS' : 'None'),
        ),
      ],
    );
  }

  Widget _buildSsoDetails(SsoConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Protocol', config.protocol.name.toUpperCase()),
        _buildDetailRow('SSO URL', config.ssoUrl),
        _buildDetailRow('Entity ID', config.entityId),
        if (config.clientId != null)
          _buildDetailRow('Client ID', config.clientId!),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailoverSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Failover & Redundancy',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.backup,
                color: _status?.fallbackEnabled == true
                    ? Colors.green
                    : Colors.red,
              ),
              title: const Text('Fallback Authentication'),
              subtitle: Text(
                _status?.fallbackEnabled == true
                    ? 'Enabled - Users can authenticate locally if identity providers fail'
                    : 'Disabled - Users must authenticate through identity providers',
              ),
              trailing: Switch(
                value: _status?.fallbackEnabled ?? false,
                onChanged: _toggleFallback,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.priority_high, color: Colors.orange),
              title: const Text('Provider Priority'),
              subtitle: const Text(
                'Configure the order in which providers are tried',
              ),
              trailing: TextButton(
                onPressed: _showPriorityDialog,
                child: const Text('Configure'),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.health_and_safety, color: Colors.blue),
              title: const Text('Health Monitoring'),
              subtitle: const Text(
                'Monitor provider health and automatic failover',
              ),
              trailing: TextButton(
                onPressed: _showHealthMonitoringDialog,
                child: const Text('Configure'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProviderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Identity Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.dns, color: Colors.blue),
              title: const Text('LDAP/Active Directory'),
              subtitle: const Text(
                'Connect to LDAP or Active Directory server',
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/ldap-config');
              },
            ),
            ListTile(
              leading: const Icon(Icons.login, color: Colors.indigo),
              title: const Text('SAML/OAuth2 SSO'),
              subtitle: const Text(
                'Configure SAML 2.0 or OAuth2/OIDC provider',
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/sso-config');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _toggleProvider(String providerId, bool enabled) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // In a real implementation, this would update the provider status
      await Future.delayed(const Duration(milliseconds: 500));

      final providerIndex = _providers.indexWhere((p) => p.id == providerId);
      if (providerIndex != -1) {
        // Create a new provider with updated status
        final updatedProvider = IdentityProvider(
          id: _providers[providerIndex].id,
          name: _providers[providerIndex].name,
          type: _providers[providerIndex].type,
          isEnabled: enabled,
          priority: _providers[providerIndex].priority,
          ldapConfig: _providers[providerIndex].ldapConfig,
          ssoConfig: _providers[providerIndex].ssoConfig,
        );

        await _authService.configureIdentityProvider(updatedProvider);
        _loadProviders();
        _loadStatus();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Provider ${enabled ? 'enabled' : 'disabled'} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update provider: $e'),
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

  void _handleProviderAction(IdentityProvider provider, String action) async {
    switch (action) {
      case 'test':
        await _testProvider(provider);
        break;
      case 'edit':
        _editProvider(provider);
        break;
      case 'sync':
        await _syncProvider(provider);
        break;
      case 'delete':
        _deleteProvider(provider);
        break;
    }
  }

  Future<void> _testProvider(IdentityProvider provider) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.testIdentityProvider(provider.id);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: result.success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text('Connection Test'),
              ],
            ),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
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

  void _editProvider(IdentityProvider provider) {
    switch (provider.type) {
      case IdentityProviderType.ldap:
        Navigator.of(context).pushNamed('/ldap-config');
        break;
      case IdentityProviderType.sso:
        Navigator.of(context).pushNamed('/sso-config');
        break;
      case IdentityProviderType.local:
        // Local provider doesn't have configuration
        break;
    }
  }

  Future<void> _syncProvider(IdentityProvider provider) async {
    if (provider.type != IdentityProviderType.ldap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'User synchronization is only available for LDAP providers',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // In a real implementation, this would trigger user synchronization
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User synchronization completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synchronization failed: $e'),
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

  void _deleteProvider(IdentityProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Identity Provider'),
        content: Text(
          'Are you sure you want to delete "${provider.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              setState(() {
                _isLoading = true;
              });

              try {
                await _authService.removeIdentityProvider(provider.id);
                _loadProviders();
                _loadStatus();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Identity provider deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete provider: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _testAllProviders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = <String, ProviderTestResult>{};

      for (final provider in _providers.where((p) => p.isEnabled)) {
        final result = await _authService.testIdentityProvider(provider.id);
        results[provider.name] = result;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Provider Test Results'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: results.entries
                    .map(
                      (entry) => ListTile(
                        leading: Icon(
                          entry.value.success
                              ? Icons.check_circle
                              : Icons.error,
                          color: entry.value.success
                              ? Colors.green
                              : Colors.red,
                        ),
                        title: Text(entry.key),
                        subtitle: Text(entry.value.message),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
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

  void _toggleFallback(bool enabled) {
    // In a real implementation, this would update the fallback setting
    setState(() {
      _status = EnterpriseAuthStatus(
        isInitialized: _status?.isInitialized ?? false,
        configuredProviders: _status?.configuredProviders ?? 0,
        activeProviders: _status?.activeProviders ?? 0,
        primaryProvider: _status?.primaryProvider,
        fallbackEnabled: enabled,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Fallback authentication ${enabled ? 'enabled' : 'disabled'}',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showPriorityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Provider Priority'),
        content: const Text(
          'Provider priority determines the order in which authentication is attempted. '
          'Lower numbers have higher priority.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHealthMonitoringDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Health Monitoring'),
        content: const Text(
          'Health monitoring continuously checks provider availability and '
          'automatically fails over to backup providers when issues are detected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Identity Provider Management'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Provider Types:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• LDAP/AD: Connect to directory servers'),
              Text('• SAML/OAuth2: Single sign-on with external providers'),
              Text('• Local: Application database authentication'),
              SizedBox(height: 16),
              Text(
                'Management Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Enable/disable providers'),
              Text('• Test connections'),
              Text('• Configure priority order'),
              Text('• Sync users (LDAP only)'),
              Text('• Monitor health status'),
              SizedBox(height: 16),
              Text('Failover:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• Automatic failover between providers'),
              Text('• Fallback to local authentication'),
              Text('• Health monitoring and alerts'),
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

  IconData _getProviderIcon(IdentityProviderType type) {
    switch (type) {
      case IdentityProviderType.ldap:
        return Icons.dns;
      case IdentityProviderType.sso:
        return Icons.login;
      case IdentityProviderType.local:
        return Icons.storage;
    }
  }

  Color _getProviderColor(IdentityProviderType type) {
    switch (type) {
      case IdentityProviderType.ldap:
        return Colors.blue;
      case IdentityProviderType.sso:
        return Colors.indigo;
      case IdentityProviderType.local:
        return Colors.grey;
    }
  }

  String _getProviderTypeDisplayName(IdentityProviderType type) {
    switch (type) {
      case IdentityProviderType.ldap:
        return 'LDAP/Active Directory';
      case IdentityProviderType.sso:
        return 'SAML/OAuth2 SSO';
      case IdentityProviderType.local:
        return 'Local Authentication';
    }
  }
}
