import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;
  
  const Failure(this.message, {this.code});
  
  @override
  List<Object?> get props => [message, code];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.code});
}

class TriageFailure extends Failure {
  const TriageFailure(super.message, {super.code});
}

class HealthDataFailure extends Failure {
  const HealthDataFailure(super.message, {super.code});
}

class LocationFailure extends Failure {
  const LocationFailure(super.message, {super.code});
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.code});
}