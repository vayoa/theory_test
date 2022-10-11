import '../../modals/substitution_context.dart';
import '../../state/progression_bank.dart';
import '../progression/degree_progression.dart';
import 'weight.dart';

class UserSavedWeight extends Weight {
  const UserSavedWeight()
      : super(
    name: 'UserSaved',
    description:
    "Prefers progressions that have substitutions the user saved "
        "rather than the built-in substitutions.",
    importance: 2,
    weightDescription: WeightDescription.exotic,
  );

  @override
  Score score({
    required DegreeProgression progression,
    required DegreeProgression base,
    SubstitutionContext? subContext,
  }) {
    final bool builtIn = subContext != null &&
        subContext.location != null &&
        ProgressionBank.isBuiltIn(subContext.location!);
    return Score(
      score: builtIn ? 0.0 : 1.0,
      details: builtIn
          ? 'The progression is built-in, so the score is 0.'
          : "The progression isn't built-in, so the score is 1.",
    );
  }
}
