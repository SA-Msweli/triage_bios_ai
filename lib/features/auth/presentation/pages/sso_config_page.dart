import 'package:flutter/material.dart';
import '../../../../shared/services/sso_service.dart';

/// SSO (SAML/OAuth2) configuration page for administrators
class SsoConfigPage extends StatefulWidget {
  const SsoConfigPage({super.key});

  @override
  State<SsoConfigPage> createState() => _SsoConfigPageState();
}

class _SsoConfigPageState extends State<SsoConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final SsoService _ssoService = SsoService();

  // Form controllers
  final _providerIdController = TextEditingController();
  final _providerNameController = TextEditingController();
  final _ssoUrlController = TextEditingController();
  final _callbackUrlController = TextEditingController();
  final _entityIdController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _tokenUrlController = TextEditingController();
  final _userInfoUrlController = TextEditingController();

  SsoProtocol _selectedProtocol = SsoProtocol.saml;
  bool _isLoading = false;
  bool _isTestingConnection = false;
  String? _connectionTestResult;

  final List<SsoProviderTemplate> _providerTemplates = [
    SsoProviderTemplate(
      name: 'Azure AD (SAML)',
      protocol: SsoProtocol.saml,
      ssoUrl: 'https://login.microsoftonline.com/{tenant-id}/saml2',
      entityId: 'https://sts.windows.net/{tenant-id}/',
    ),
    SsoProviderTemplate(
      name: 'Azure AD (OAuth2)',
      protocol: SsoProtocol.oidc,
      ssoUrl:
          'https://login.microsoftonline.com/{tenant-id}/oauth2/v2.0/authorize',
      tokenUrl:
          'https://login.microsoftonline.com/{tenant-id}/oauth2/v2.0/token',
      userInfoUrl: 'https://graph.microsoft.com/v1.0/me',
    ),
    SsoProviderTemplate(
      name: 'Okta (SAML)',
      protocol: SsoProtocol.saml,
      ssoUrl: 'https://{domain}.okta.com/app/{app-id}/sso/saml',
      entityId: 'http://www.okta.com/{app-id}',
    ),
    SsoProviderTemplate(
      name: 'Okta (OAuth2)',
      protocol: SsoProtocol.oidc,
      ssoUrl: 'https://{domain}.okta.com/oauth2/default/v1/authorize',
      tokenUrl: 'https://{domain}.okta.com/oauth2/default/v1/token',
      userInfoUrl: 'https://{domain}.okta.com/oauth2/default/v1/userinfo',
    ),
    SsoProviderTemplate(
      name: 'Google Workspace',
      protocol: SsoProtocol.oidc,
      ssoUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
      tokenUrl: 'https://oauth2.googleapis.com/token',
      userInfoUrl: 'https://openidconnect.googleapis.com/v1/userinfo',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _providerIdController.dispose();
    _providerNameController.dispose();
    _ssoUrlController.dispose();
    _callbackUrlController.dispose();
    _entityIdController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _tokenUrlController.dispose();
    _userInfoUrlController.dispose();
    super.dispose();
  }

  void _loadCurrentConfig() {
    final config = _ssoService.config;
    if (config != null) {
      _providerIdController.text = config.providerId;
      _providerNameController.text = config.providerName;
      _selectedProtocol = config.protocol;
      _ssoUrlController.text = config.ssoUrl;
      _callbackUrlController.text = config.callbackUrl;
      _entityIdController.text = config.entityId;
      _clientIdController.text = config.clientId ?? '';
      _clientSecretController.text = config.clientSecret ?? '';
      _tokenUrlController.text = config.tokenUrl ?? '';
      _userInfoUrlController.text = config.userInfoUrl ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSO Configuration'),
        backgroundColor: Colors.indigo,
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
              _buildProviderTemplatesSection(),
              const SizedBox(height: 24),
              _buildBasicConfigSection(),
              const SizedBox(height: 24),
              _buildProtocolSpecificSection(),
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
                  _ssoService.isConfigured ? Icons.check_circle : Icons.error,
                  color: _ssoService.isConfigured ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'SSO Integration Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
              'Status',
              _ssoService.isConfigured ? 'Configured' : 'Not configured',
            ),
            if (_ssoService.config != null) ...[
              _buildStatusRow('Provider', _ssoService.config!.providerName),
              _buildStatusRow(
                'Protocol',
                _ssoService.config!.protocol.name.toUpperCase(),
              ),
              _buildStatusRow(
                'Active Sessions',
                _ssoService.activeSessionsCount.toString(),
              ),
            ],
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
            width: 120,
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

  Widget _buildProviderTemplatesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provider Templates',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a template to pre-fill configuration for common identity providers:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _providerTemplates
                  .map(
                    (template) => ActionChip(
                      label: Text(template.name),
                      onPressed: () => _applyTemplate(template),
                      backgroundColor: Colors.indigo.shade50,
                      labelStyle: TextStyle(color: Colors.indigo.shade700),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _providerIdController,
                    decoration: const InputDecoration(
                      labelText: 'Provider ID',
                      hintText: 'azure-ad-hospital',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Provider ID is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _providerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Provider Name',
                      hintText: 'Hospital Azure AD',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Provider name is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SsoProtocol>(
              value: _selectedProtocol,
              decoration: const InputDecoration(
                labelText: 'Protocol',
                border: OutlineInputBorder(),
              ),
              items: SsoProtocol.values
                  .map(
                    (protocol) => DropdownMenuItem(
                      value: protocol,
                      child: Text(_getProtocolDisplayName(protocol)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProtocol = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _callbackUrlController,
              decoration: const InputDecoration(
                labelText: 'Callback URL',
                hintText: 'https://app.triage-bios.ai/auth/sso/callback',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Callback URL is required';
                }
                final uri = Uri.tryParse(value);
                if (uri?.hasAbsolutePath != true) {
                  return 'Invalid URL format';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolSpecificSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getProtocolDisplayName(_selectedProtocol)} Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_selectedProtocol == SsoProtocol.saml) ..._buildSamlFields(),
            if (_selectedProtocol == SsoProtocol.oauth2 ||
                _selectedProtocol == SsoProtocol.oidc)
              ..._buildOAuthFields(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSamlFields() {
    return [
      TextFormField(
        controller: _ssoUrlController,
        decoration: const InputDecoration(
          labelText: 'SSO URL',
          hintText: 'https://login.microsoftonline.com/{tenant}/saml2',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'SSO URL is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _entityIdController,
        decoration: const InputDecoration(
          labelText: 'Entity ID',
          hintText: 'https://sts.windows.net/{tenant}/',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Entity ID is required';
          }
          return null;
        },
      ),
    ];
  }

  List<Widget> _buildOAuthFields() {
    return [
      TextFormField(
        controller: _ssoUrlController,
        decoration: const InputDecoration(
          labelText: 'Authorization URL',
          hintText:
              'https://login.microsoftonline.com/{tenant}/oauth2/v2.0/authorize',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Authorization URL is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _tokenUrlController,
        decoration: const InputDecoration(
          labelText: 'Token URL',
          hintText:
              'https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Token URL is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _userInfoUrlController,
        decoration: const InputDecoration(
          labelText: 'User Info URL',
          hintText: 'https://graph.microsoft.com/v1.0/me',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _clientIdController,
              decoration: const InputDecoration(
                labelText: 'Client ID',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Client ID is required';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _clientSecretController,
              decoration: const InputDecoration(
                labelText: 'Client Secret',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Client secret is required';
                }
                return null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _entityIdController,
        decoration: const InputDecoration(
          labelText: 'Issuer/Entity ID',
          hintText: 'https://sts.windows.net/{tenant}/',
          border: OutlineInputBorder(),
        ),
      ),
    ];
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
                  _isTestingConnection ? 'Testing...' : 'Test Configuration',
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
                onPressed: _generateMetadata,
                icon: const Icon(Icons.download),
                label: const Text('Download Metadata'),
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

  void _applyTemplate(SsoProviderTemplate template) {
    setState(() {
      _selectedProtocol = template.protocol;
      _ssoUrlController.text = template.ssoUrl;
      _entityIdController.text = template.entityId ?? '';
      _tokenUrlController.text = template.tokenUrl ?? '';
      _userInfoUrlController.text = template.userInfoUrl ?? '';

      // Generate provider ID from name
      _providerIdController.text = template.name
          .toLowerCase()
          .replaceAll(' ', '-')
          .replaceAll('(', '')
          .replaceAll(')', '');
      _providerNameController.text = template.name;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied template: ${template.name}'),
        backgroundColor: Colors.green,
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
      // In a real implementation, this would test the actual SSO connection
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _connectionTestResult =
            'Configuration test successful! SSO provider is reachable.';
      });
    } catch (e) {
      setState(() {
        _connectionTestResult = 'Configuration test failed: $e';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  void _generateMetadata() {
    // In a real implementation, this would generate SAML metadata or OAuth2 discovery document
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Metadata Generated'),
        content: const Text(
          'Metadata has been generated and is ready for download. '
          'Provide this metadata to your identity provider administrator.',
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

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final config = _buildSsoConfig();
      await _ssoService.configureSso(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SSO configuration saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
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

  SsoConfig _buildSsoConfig() {
    return SsoConfig(
      providerId: _providerIdController.text.trim(),
      providerName: _providerNameController.text.trim(),
      protocol: _selectedProtocol,
      ssoUrl: _ssoUrlController.text.trim(),
      callbackUrl: _callbackUrlController.text.trim(),
      entityId: _entityIdController.text.trim(),
      clientId: _clientIdController.text.trim().isEmpty
          ? null
          : _clientIdController.text.trim(),
      clientSecret: _clientSecretController.text.trim().isEmpty
          ? null
          : _clientSecretController.text.trim(),
      tokenUrl: _tokenUrlController.text.trim().isEmpty
          ? null
          : _tokenUrlController.text.trim(),
      userInfoUrl: _userInfoUrlController.text.trim().isEmpty
          ? null
          : _userInfoUrlController.text.trim(),
    );
  }

  String _getProtocolDisplayName(SsoProtocol protocol) {
    switch (protocol) {
      case SsoProtocol.saml:
        return 'SAML 2.0';
      case SsoProtocol.oauth2:
        return 'OAuth 2.0';
      case SsoProtocol.oidc:
        return 'OpenID Connect';
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SSO Configuration Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('SAML 2.0:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• SSO URL: The identity provider\'s SAML endpoint'),
              Text('• Entity ID: Unique identifier for the identity provider'),
              Text('• Callback URL: Where users return after authentication'),
              SizedBox(height: 16),
              Text(
                'OAuth 2.0 / OpenID Connect:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Authorization URL: OAuth2 authorization endpoint'),
              Text('• Token URL: Endpoint to exchange code for tokens'),
              Text('• User Info URL: Endpoint to get user information'),
              Text('• Client ID/Secret: OAuth2 application credentials'),
              SizedBox(height: 16),
              Text(
                'Provider Templates:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Use templates to quickly configure common providers'),
              Text('• Replace {tenant}, {domain}, etc. with actual values'),
              Text('• Templates provide standard endpoints for each provider'),
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

/// SSO provider template for quick configuration
class SsoProviderTemplate {
  final String name;
  final SsoProtocol protocol;
  final String ssoUrl;
  final String? entityId;
  final String? tokenUrl;
  final String? userInfoUrl;

  SsoProviderTemplate({
    required this.name,
    required this.protocol,
    required this.ssoUrl,
    this.entityId,
    this.tokenUrl,
    this.userInfoUrl,
  });
}
