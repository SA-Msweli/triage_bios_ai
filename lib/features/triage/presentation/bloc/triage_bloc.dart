import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import '../../domain/usecases/assess_symptoms_usecase.dart';
import '../../domain/repositories/triage_repository.dart';
import 'triage_event.dart';
import 'triage_state.dart';

class TriageBloc extends Bloc<TriageEvent, TriageState> {
  final AssessSymptomsUseCase assessSymptomsUseCase;
  final TriageRepository triageRepository;
  final Logger _logger = Logger();

  TriageBloc({
    required this.assessSymptomsUseCase,
    required this.triageRepository,
  }) : super(const TriageInitial()) {
    on<AssessSymptomsEvent>(_onAssessSymptoms);
    on<LoadVitalsEvent>(_onLoadVitals);
    on<RequestHealthPermissionsEvent>(_onRequestHealthPermissions);
    on<CheckHealthPermissionsEvent>(_onCheckHealthPermissions);
    on<ResetTriageEvent>(_onResetTriage);
  }

  Future<void> _onAssessSymptoms(
    AssessSymptomsEvent event,
    Emitter<TriageState> emit,
  ) async {
    emit(const TriageLoading());

    _logger.i('Starting triage assessment for symptoms: ${event.symptoms}');

    final result = await assessSymptomsUseCase(
      AssessSymptomsParams(
        symptoms: event.symptoms,
        vitals: event.vitals,
        demographics: event.demographics,
      ),
    );

    result.fold(
      (failure) {
        _logger.e('Triage assessment failed: ${failure.message}');
        emit(TriageError(failure.message));
      },
      (triageResult) {
        _logger.i('Triage assessment completed: Score ${triageResult.severityScore}');
        emit(TriageAssessmentComplete(
          result: triageResult,
          vitals: event.vitals,
        ));
      },
    );
  }

  Future<void> _onLoadVitals(
    LoadVitalsEvent event,
    Emitter<TriageState> emit,
  ) async {
    emit(const VitalsLoading());

    _logger.i('Loading patient vitals from wearable devices');

    // First check permissions
    final permissionsResult = await triageRepository.checkHealthPermissions();
    bool hasPermissions = false;
    
    permissionsResult.fold(
      (failure) => hasPermissions = false,
      (permissions) => hasPermissions = permissions,
    );

    if (!hasPermissions) {
      emit(VitalsError(
        message: 'Health data access not granted. Please enable permissions to access wearable data.',
        hasPermissions: false,
      ));
      return;
    }

    // Try to get vitals
    final vitalsResult = await triageRepository.getLatestVitals();

    vitalsResult.fold(
      (failure) {
        _logger.w('Failed to load vitals: ${failure.message}');
        emit(VitalsError(
          message: failure.message,
          hasPermissions: hasPermissions,
        ));
      },
      (vitals) {
        _logger.i('Vitals loaded successfully: HR=${vitals.heartRate}, SpO2=${vitals.oxygenSaturation}');
        emit(VitalsLoaded(
          vitals: vitals,
          hasPermissions: hasPermissions,
        ));
      },
    );
  }

  Future<void> _onRequestHealthPermissions(
    RequestHealthPermissionsEvent event,
    Emitter<TriageState> emit,
  ) async {
    emit(const HealthPermissionsState(hasPermissions: false, isRequesting: true));

    _logger.i('Requesting health data permissions');

    final result = await triageRepository.requestHealthPermissions();

    result.fold(
      (failure) {
        _logger.e('Failed to request permissions: ${failure.message}');
        emit(const HealthPermissionsState(hasPermissions: false, isRequesting: false));
      },
      (_) {
        _logger.i('Health permissions requested successfully');
        // Check if permissions were actually granted
        add(const CheckHealthPermissionsEvent());
      },
    );
  }

  Future<void> _onCheckHealthPermissions(
    CheckHealthPermissionsEvent event,
    Emitter<TriageState> emit,
  ) async {
    final result = await triageRepository.checkHealthPermissions();

    result.fold(
      (failure) {
        _logger.e('Failed to check permissions: ${failure.message}');
        emit(const HealthPermissionsState(hasPermissions: false));
      },
      (hasPermissions) {
        _logger.i('Health permissions status: $hasPermissions');
        emit(HealthPermissionsState(hasPermissions: hasPermissions));
      },
    );
  }

  Future<void> _onResetTriage(
    ResetTriageEvent event,
    Emitter<TriageState> emit,
  ) async {
    _logger.i('Resetting triage state');
    emit(const TriageInitial());
  }
}