import '../modals/progression/scale_degree_progression.dart';

class ProgressionBankEntry {
  final ScaleDegreeProgression progression;
  final bool usedInSubstitutions;

  const ProgressionBankEntry({
    required this.progression,
    this.usedInSubstitutions = false,
  });

  ProgressionBankEntry copyWith({
    ScaleDegreeProgression? progression,
    bool? builtIn,
    bool? usedInSubstitutions,
  }) =>
      ProgressionBankEntry(
        progression: progression ?? this.progression,
        usedInSubstitutions: usedInSubstitutions ?? this.usedInSubstitutions,
      );

  ProgressionBankEntry.fromJson({
    required Map<String, dynamic> json,
  })  : usedInSubstitutions = json['s'],
        progression = ScaleDegreeProgression.fromJson(json['p']);

  Map<String, dynamic> toJson() => {
        's': usedInSubstitutions,
        'p': progression.toJson(),
      };

  @override
  String toString() => '(s: $usedInSubstitutions)- $progression';
}
