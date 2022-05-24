import 'package:thoery_test/modals/scale_degree_chord.dart';
import 'package:thoery_test/modals/scale_degree_progression.dart';
import 'package:thoery_test/modals/substitution.dart';
import 'package:thoery_test/modals/weights/climactic_ending_weight.dart';
import 'package:thoery_test/modals/weights/complex_weight.dart';
import 'package:thoery_test/modals/weights/harmonic_function_weight.dart';
import 'package:thoery_test/modals/weights/important_chords_weight.dart';
import 'package:thoery_test/modals/weights/in_scale_weight.dart';
import 'package:thoery_test/modals/weights/keep_harmonic_function_weight.dart';
import 'package:thoery_test/modals/weights/overtaking_weight.dart';
import 'package:thoery_test/modals/weights/rhythm_and_placement_weight.dart';
import 'package:thoery_test/modals/weights/uniques_weight.dart';
import 'package:thoery_test/modals/weights/user_saved_weight.dart';
import 'package:thoery_test/modals/weights/weight.dart';
import 'package:thoery_test/state/progression_bank.dart';

abstract class SubstitutionHandler {
  static List<Weight> weights = [
    const InScaleWeight(),
    const OvertakingWeight(),
    const UniquesWeight(),
    const HarmonicFunctionWeight(),
    const RhythmAndPlacementWeight(),
    const ImportantChordsWeight(),
    const ClimacticEndingWeight(),
    const UserSavedWeight(),
    const ComplexWeight(),
  ]..sort(
      (Weight w1, Weight w2) => -1 * w1.importance.compareTo(w2.importance));

  static const KeepHarmonicFunctionWeight keepHarmonicFunction =
      KeepHarmonicFunctionWeight();

  static KeepHarmonicFunctionAmount keepAmount = KeepHarmonicFunctionAmount.med;

  static final Map<String, Weight> weightsMap = {
    for (Weight weight in weights) weight.name: weight
  };

  static List<Substitution> _getPossibleSubstitutions(
    ScaleDegreeProgression base, {
    int start = 0,
    double startDur = 0.0,
    int? end,
    double? endDur,
  }) {
    final List<Substitution> substitutions = [];
    end ??= base.length;
    for (int i = start; i < end; i++) {
      ScaleDegreeChord? chord = base[i];
      if (chord != null) {
        List<List<dynamic>>? progressions =
            ProgressionBank.getByGroup(chord: chord, withTonicization: false);
        if (progressions != null && progressions.isNotEmpty) {
          for (List<dynamic> pair in progressions) {
            substitutions.addAll(base.getPossibleSubstitutions(
              pair[1],
              start: start,
              startDur: startDur,
              end: end,
              endDur: endDur,
              forIndex: i,
              substitutionTitle: pair[0],
            ));
          }
        }
      }
    }
    // We do this here since it's more efficient...
    List<List<dynamic>> tonicizations = ProgressionBank.tonicizations;
    for (List<dynamic> sub in tonicizations) {
      substitutions.addAll(base.getPossibleSubstitutions(
        sub[1],
        start: start,
        startDur: startDur,
        end: end,
        endDur: endDur,
        substitutionTitle: sub[0],
      ));
    }
    return substitutions.toSet().toList();
  }

  static List<Substitution> getRatedSubstitutions(
    ScaleDegreeProgression base, {
    Sound? sound,
    KeepHarmonicFunctionAmount? keepAmount,
    ScaleDegreeProgression? harmonicFunctionBase,
    int start = 0,
    double startDur = 0.0,
    int? end,
    double? endDur,
  }) {
    if (keepAmount != null) SubstitutionHandler.keepAmount = keepAmount;
    List<Substitution> substitutions = _getPossibleSubstitutions(
      base,
      start: start,
      startDur: startDur,
      end: end,
      endDur: endDur,
    );
    List<Substitution> sorted = [];
    bool shouldCalc = keepAmount != KeepHarmonicFunctionAmount.low;
    for (Substitution sub in substitutions) {
      SubstitutionScore? score = sub.scoreWith(
        weights,
        keepHarmonicFunction: shouldCalc,
        sound: sound,
        harmonicFunctionBase: harmonicFunctionBase,
      );
      if (score != null) {
        sorted.add(sub);
      }
    }
    sorted.sort((Substitution a, Substitution b) => -1 * a.compareTo(b));
    return sorted;
  }

  /// Substitutes the best option for [maxIterations] iterations.
  static Substitution substituteBy({
    required ScaleDegreeProgression base,
    required int maxIterations,
    Sound? sound,
    KeepHarmonicFunctionAmount? keepHarmonicFunction,
    int start = 0,
    double startDur = 0.0,
    int? end,
    double? endDur,
  }) {
    ScaleDegreeProgression prev = base;
    List<Substitution> rated;
    do {
      rated = getRatedSubstitutions(
        prev,
        sound: sound,
        keepAmount: keepHarmonicFunction,
        harmonicFunctionBase: base,
        start: start,
        startDur: startDur,
        end: end,
        endDur: endDur,
      );
      if (prev == rated.first.substitutedBase) break;
      prev = rated.first.substitutedBase;
      maxIterations--;
    } while (maxIterations > 0);
    Substitution result = rated.first.copyWith(base: base);
    return result;
  }
}
