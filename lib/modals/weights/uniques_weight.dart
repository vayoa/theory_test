import 'package:thoery_test/modals/scale_degree_chord.dart';
import 'package:thoery_test/modals/scale_degree_progression.dart';
import 'package:thoery_test/modals/weights/weight.dart';
import 'package:tonic/tonic.dart';

class UniquesWeight extends Weight {
  const UniquesWeight()
      : super(
          importance: 2,
          scoringStage: ScoringStage.afterSubstitution,
          description: WeightDescription.exotic,
        );

  // FIXME: Optimize this a bit more...
  @override
  double score(ScaleDegreeProgression progression) =>
      progression.values.toSet().length / progression.length;
}