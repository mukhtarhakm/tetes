import 'brew_plan.dart';

class BrewSessionResult {
  const BrewSessionResult({
    required this.plan,
    required this.totalTimeS,
    required this.drawdownS,
    required this.brewedAtUtc,
  });

  final BrewPlan plan;
  final int totalTimeS;
  final int? drawdownS;
  final String brewedAtUtc;
}
