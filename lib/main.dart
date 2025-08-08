import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'shared/services/health_service.dart';
import 'shared/services/watsonx_service.dart';
import 'features/triage/data/repositories/triage_repository_impl.dart';
import 'features/triage/domain/usecases/assess_symptoms_usecase.dart';
import 'features/triage/presentation/bloc/triage_bloc.dart';
import 'features/triage/presentation/pages/triage_page.dart';
import 'features/hospital_routing/presentation/widgets/hospital_map_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await HealthService().initialize();

  // Initialize Watson X.ai service with real IBM Cloud credentials
  // TODO: Replace with your actual IBM Cloud API key and project ID
  WatsonxService().initialize(
    apiKey: const String.fromEnvironment(
      'WATSONX_API_KEY',
      defaultValue: 'your_ibm_cloud_api_key_here',
    ),
    projectId: const String.fromEnvironment(
      'WATSONX_PROJECT_ID',
      defaultValue: 'your_watsonx_project_id_here',
    ),
  );

  runApp(const TriageBiosApp());
}

class TriageBiosApp extends StatelessWidget {
  const TriageBiosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TriageBloc>(
          create: (context) {
            final repository = TriageRepositoryImpl(
              watsonxService: WatsonxService(),
              healthService: HealthService(),
            );
            return TriageBloc(
              assessSymptomsUseCase: AssessSymptomsUseCase(repository),
              triageRepository: repository,
            );
          },
        ),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32), // Medical green
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/triage', builder: (context, state) => const TriagePage()),
    GoRoute(
      path: '/hospitals',
      builder: (context, state) => const HospitalsPage(),
    ),
  ],
);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appName,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              AppConstants.appTagline,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.medical_services,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Emergency Triage Assessment',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get instant AI-powered severity assessment using your symptoms and wearable device data.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go('/triage'),
                      icon: const Icon(Icons.start),
                      label: const Text('Start Triage Assessment'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.local_hospital,
                      size: 64,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Find Nearby Hospitals',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'View real-time hospital capacity and get optimal routing recommendations.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/hospitals'),
                      icon: const Icon(Icons.map),
                      label: const Text('View Hospital Map'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Version ${AppConstants.appVersion}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class HospitalsPage extends StatelessWidget {
  const HospitalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Hospitals'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh hospital data
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing hospital data...')),
              );
            },
          ),
        ],
      ),
      body: const HospitalMapWidget(),
    );
  }
}
