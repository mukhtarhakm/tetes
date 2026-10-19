import 'brew_plan.dart';

class BrewStageActual {
  const BrewStageActual({
    required this.position,
    required this.name,
    required this.actualStartS,
    required this.actualDurationS,
    this.drawdownS,
  });

  final int position;
  final BrewStageName name;
  final int actualStartS;
  final int actualDurationS;
  final int? drawdownS;
}

class BrewSessionResult {
  const BrewSessionResult({
    required this.plan,
    required this.stages,
    required this.totalTimeS,
  });

  final BrewPlan plan;
  final List<BrewStageActual> stages;
  final int totalTimeS;
}
