import 'load_plan.dart';

/// Eine mögliche Ladevariante mit Gewichts- und Stabilitätswerten
class LoadVariant {
  final String name;
  final LoadPlan loadPlan;
  final double weight;
  final double grogScore;
  final bool isValid;

  const LoadVariant({
    required this.name,
    required this.loadPlan,
    required this.weight,
    required this.grogScore,
    required this.isValid,
  });
}
