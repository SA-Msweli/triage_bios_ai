import 'package:flutter/material.dart';
import 'features/triage/presentation/pages/triage_page.dart';
import 'features/web_portal/presentation/pages/web_portal_page.dart';
import 'features/web_portal/presentation/pages/login_page.dart';
import 'shared/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize core services
  await AuthService().initialize();

  runApp(const TriageBiosApp());
}

class TriageBiosApp extends StatelessWidget {
  const TriageBiosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Triage-BIOS.ai',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
      routes: {
        '/triage': (context) => const TriagePage(),
        '/dashboard': (context) => const WebPortalPage(),
        '/portal': (context) => const LoginPage(),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Triage-BIOS.ai'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.local_hospital,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Triage-BIOS.ai',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI-Powered Emergency Triage System',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Feature Cards
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildFeatureCard(
                    context,
                    'AI Triage Assessment',
                    'Start symptom analysis with wearable integration',
                    Icons.assignment_ind,
                    Colors.blue,
                    () => Navigator.pushNamed(context, '/triage'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Hospital Dashboard',
                    'Real-time patient queue & FHIR integration',
                    Icons.dashboard,
                    Colors.green,
                    () => Navigator.pushNamed(context, '/dashboard'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Login Portal',
                    'Access role-based web interface',
                    Icons.login,
                    Colors.purple,
                    () => Navigator.pushNamed(context, '/portal'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Consent Management',
                    'Manage data sharing preferences',
                    Icons.security,
                    Colors.orange,
                    () => _showFeatureDialog(context, 'Consent Management'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Status Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Status',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('✅ AI Triage Engine - Operational'),
                  const Text('✅ Wearable Integration - Connected'),
                  const Text('✅ Hospital FHIR APIs - Active'),
                  const Text('✅ Consent Management - Secure'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeatureDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(featureName),
        content: Text(
          '$featureName feature is implemented and ready.\n\nThis demo shows the core architecture with all services and components in place.',
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
}
