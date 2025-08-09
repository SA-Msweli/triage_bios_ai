import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// Import pages
import 'features/triage/presentation/pages/triage_page.dart';
import 'features/hospital_dashboard/presentation/pages/hospital_dashboard_page.dart';
import 'features/web_portal/presentation/pages/patient_web_portal_page.dart';
import 'features/triage/presentation/pages/consent_management_page.dart';

// Import services
import 'shared/services/fhir_service.dart';
import 'shared/services/health_service.dart';
import 'shared/services/watsonx_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  FhirService().initialize();
  
  runApp(TriageBiosApp());
}

class TriageBiosApp extends StatelessWidget {
  TriageBiosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Add BLoC providers here when needed
      ],
      child: MaterialApp.router(
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
        routerConfig: _router,
      ),
    );
  }

  final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/triage',
        builder: (context, state) => const TriagePage(),
      ),
      GoRoute(
        path: '/hospital-dashboard',
        builder: (context, state) => const HospitalDashboardPage(),
      ),
      GoRoute(
        path: '/web-portal',
        builder: (context, state) => const PatientWebPortalPage(),
      ),
      GoRoute(
        path: '/consent',
        builder: (context, state) => const ConsentManagementPage(patientId: 'demo_patient'),
      ),
    ],
  );
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
                    'Patient Triage',
                    'Start AI-powered symptom assessment',
                    Icons.assignment_ind,
                    Colors.blue,
                    () => context.go('/triage'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Hospital Dashboard',
                    'View patient queue and capacity',
                    Icons.dashboard,
                    Colors.green,
                    () => context.go('/hospital-dashboard'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Web Portal',
                    'Access responsive web interface',
                    Icons.web,
                    Colors.purple,
                    () => context.go('/web-portal'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Consent Management',
                    'Manage data sharing preferences',
                    Icons.security,
                    Colors.orange,
                    () => context.go('/consent'),
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
                color: Theme.of(context).colorScheme.surfaceVariant,
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
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
}