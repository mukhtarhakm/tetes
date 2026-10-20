import 'brew_plan.dart';

class BrewSessionResult {
  const BrewSessionResult({
    required this.plan,
    required this.totalTimeS,
    required this.drawdownS,
  });

  final BrewPlan plan;
  final int totalTimeS;
  final int? drawdownS;
}
