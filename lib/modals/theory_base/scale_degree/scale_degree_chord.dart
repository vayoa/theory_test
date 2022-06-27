import 'dart:convert';

import 'package:harmony_theory/extensions/scale_pattern_extension.dart';
import 'package:tonic/tonic.dart';

import '../../../extensions/chord_extension.dart';
import '../../../extensions/interval_extension.dart';
import '../../identifiable.dart';
import '../../pitch_chord.dart';
import '../generic_chord.dart';
import '../pitch_scale.dart';
import 'scale_degree.dart';
import 'tonicized_scale_degree_chord.dart';

class ScaleDegreeChord extends GenericChord<ScaleDegree>
    implements Identifiable {
  final bool _bassInChord;

  static const int maxInversionNumbers = 2;

  static final RegExp chordNamePattern = RegExp(
      r"^([#b♯♭𝄪𝄫]*(?:III|II|IV|I|VII|VI|V))([^\^]*)(?:\^([#b♯♭𝄪𝄫]*\d))?$",
      caseSensitive: false);

  static const List<String> _canBeTonicizedPatterns = [
    'Major',
    'Minor',
    'Major 7th',
    'Minor 7th',
    'Dominant 7th',
  ];

  // TODO: Optimize.
  // TODO: When we get a chord like A/B we need it to become B11 for instance...
  /// If the bass isn't an inversion and there's a problem with calculating an
  /// interval, this constructor takes the in-harmonic equivalent of the bass.
  ///
  /// Example: In C major, a ScaleDegreeChord that was parsed from C/F##
  /// will turn to I⁶₄ (C/G)...
  factory ScaleDegreeChord._inharmonicityHandler(
    ChordPattern pattern,
    ScaleDegree rootDegree, {
    ScaleDegree? bass,
  }) {
    if (bass == null) {
      return ScaleDegreeChord.raw(pattern, rootDegree);
    }
    Interval? tryFrom = rootDegree.tryFrom(bass);
    if (tryFrom == null) {
      int semitones = ScalePatternExtension.majorKeySemitones[bass.degree] +
          bass.accidentals;
      bass = ScaleDegree.fromPitch(
          PitchScale.cMajor, Pitch.fromMidiNumber(semitones));
    }
    return ScaleDegreeChord.raw(pattern, rootDegree, bass: bass);
  }

  factory ScaleDegreeChord(PitchScale scale, PitchChord chord) =>
      ScaleDegreeChord._inharmonicityHandler(
        chord.pattern,
        ScaleDegree.fromPitch(scale, chord.root),
        bass: !chord.hasDifferentBass
            ? null
            : ScaleDegree.fromPitch(scale, chord.bass),
      );

  ScaleDegreeChord.raw(
    ChordPattern pattern,
    ScaleDegree rootDegree, {
    ScaleDegree? bass,
    bool? bassInChord,
  })  : _bassInChord = bassInChord ??
            (bass == null
                ? true
                : pattern.intervals.contains(bass.tryFrom(rootDegree))),
        super(pattern, rootDegree, bass: bass);

  ScaleDegreeChord.copy(ScaleDegreeChord chord)
      : _bassInChord = chord._bassInChord,
        super(
          ChordPattern(
              name: chord.pattern.name,
              fullName: chord.pattern.fullName,
              abbrs: chord.pattern.abbrs,
              intervals: chord.pattern.intervals),
          ScaleDegree.copy(chord.root),
          bass: ScaleDegree.copy(chord.bass),
        );

  factory ScaleDegreeChord.parse(String name) {
    List<String> split = name.split(r'/');
    if (split.length == 1) {
      return _parseInternal(name);
    } else {
      return _parseInternal(split[0]).tonicizedFor(_parseInternal(split[1]));
    }
  }

  static ScaleDegreeChord _parseInternal(String chord) {
    final match = chordNamePattern.matchAsPrefix(chord);
    if (match == null) {
      throw FormatException("invalid ScaleDegreeChord name: $chord");
    }
    // If the degree is a lowercase letter (meaning the chord contains a minor
    // triad).
    ChordPattern _cPattern = ChordPattern.parse(match[2]!.replaceAll('b', '♭'));
    if (match[1]!.toLowerCase() == match[1]) {
      // We don't want to change any of the generated chord patterns (for some
      // reason they aren't const so I can change them and screw up that entire
      // ChordPattern.
      // The ... operator de-folds the list.
      final List<Interval> _intervals = [..._cPattern.intervals];
      // Make the 2nd interval (the one between the root and the 3rd) minor.
      _intervals[1] = Interval.m3;
      _cPattern = ChordPattern.fromIntervals(_intervals);
    }
    ScaleDegree rootDegree = ScaleDegree.parse(match[1]!);
    String? bass = match[3];
    return ScaleDegreeChord._inharmonicityHandler(
      _cPattern,
      rootDegree,
      bass: _parseBass(bass, rootDegree, _cPattern),
    );
  }

  /// Returns [degree, accidentals].
  static ScaleDegree? _parseBass(
      String? name, ScaleDegree root, ChordPattern pattern) {
    if (name == null || name.isEmpty) return null;
    int degree, accidentals;
    final int startIndex = name.indexOf(RegExp(r'\d', caseSensitive: false));
    String degreeStr = name.substring(startIndex);
    String offsetStr = name.substring(0, startIndex);
    degree = int.parse(degreeStr) - 1;
    if (degree < 0 || degree > 7) {
      throw FormatException("invalid bass interval name: $name");
    }
    if (offsetStr.isNotEmpty) {
      if (offsetStr.startsWith(RegExp(r'[#b♯♭𝄪𝄫]'))) {
        accidentals = offsetStr[0].allMatches(offsetStr).length *
            (offsetStr[0].contains(RegExp(r'[b♭𝄫]')) ? -1 : 1);
      } else {
        throw FormatException("invalid bass interval name: $name");
      }
    } else {
      accidentals = 0;
    }
    if (degree == 0 && accidentals == 0) return null;
    Interval regular;
    // If the number is odd and there's such degree in the pattern use it from
    // the pattern...
    // degree is the number parsed - 1...
    /* TODO: Make a harmonic analysis to choose which interval to use on the
             7th when the chord doesn't have one - for instance a V should have
             a min7 like other minor chords instead of a maj7 like other maj
             chords etc... */
    if (degree % 2 == 0 && degree ~/ 2 < pattern.intervals.length) {
      regular = pattern.intervals[degree ~/ 2];
    } else {
      // else default it to major / perfect...
      regular = Interval(number: degree + 1);
    }
    ScaleDegree bass = root.add(regular);
    return ScaleDegree.raw(bass.degree, bass.accidentals + accidentals);
  }

  ScaleDegreeChord.fromJson(Map<String, dynamic> json)
      : this.raw(
          ChordPatternExtension.fromFullName(json['p']),
          ScaleDegree.fromJson(json['rd']),
          bass: json['b'] == null ? null : ScaleDegree.fromJson(json['b']),
        );

  Map<String, dynamic> toJson() => {
        'rd': root.toJson(),
        'p': pattern.fullName,
        if (hasDifferentBass) 'b': bass.toJson(),
      };

  @override
  List<ScaleDegree> get patternMapped =>
      pattern.intervals.map((i) => root.add(i)).toList();

  /// Returns a list of [ScaleDegree] that represents the degrees that make up
  /// the [ScaleDegreeChord] in the major scale.
  List<ScaleDegree> get degrees => patternMapped;

  int get degreesLength => patternLength;

  /// Returns true if the chord is diatonic in the major scale.
  bool get isDiatonic => degrees.every((degree) => degree.isDiatonic);

  bool get canBeTonic {
    if (_canBeTonicizedPatterns.contains(pattern.name)) return true;
    final List<Interval> _intervals = pattern.intervals;
    if ((_intervals[2] - _intervals[0]).equals(Interval.P5)) {
      final Interval third = _intervals[1] - _intervals[0];
      if (third.equals(Interval.M3) || third.equals(Interval.m3)) {
        if (_intervals.length < 4) return true;
        final Interval seventh = (_intervals[3] - _intervals[0]);
        if (seventh.equals(Interval.m7)) {
          return true;
        }
        return third.equals(Interval.M3) || seventh.equals(Interval.M7);
      }
    }
    return false;
  }

  /// Returns a new [ScaleDegreeChord] converted such that [tonic] is the new
  /// tonic. Everything is still represented in the major scale, besides to degree the function is called on...
  ///
  /// Example: V.tonicizedFor(VI) => III, I.tonicizedFor(VI) => VI,
  /// ii.tonicizedFor(VI) => vii.
  ScaleDegreeChord tonicizedFor(ScaleDegreeChord tonic) {
    if (tonic.root == ScaleDegree.tonic) {
      return ScaleDegreeChord.copy(this);
    } else if (weakEqual(majorTonicTriad)) {
      return ScaleDegreeChord.raw(tonic.pattern, root.tonicizedFor(tonic.root));
    }
    return TonicizedScaleDegreeChord(
      tonic: tonic,
      tonicizedToTonic: ScaleDegreeChord.copy(this),
      tonicizedToMajorScale: ScaleDegreeChord.raw(
        pattern,
        root.tonicizedFor(tonic.root),
        bass: bass.tonicizedFor(tonic.root),
      ),
    );
  }

  /// We get a tonic and a chord and decide what chord it is for the new tonic
  ScaleDegreeChord shiftFor(ScaleDegreeChord tonic) {
    if (weakEqual(tonic)) {
      return ScaleDegreeChord.copy(ScaleDegreeChord.majorTonicTriad);
    } else {
      return ScaleDegreeChord.raw(pattern, root.shiftFor(tonic.root));
    }
  }

  /// Will return a new [ScaleDegreeChord] with an added 7th if possible.
  /// [harmonicFunction] can be given for slightly more relevant results.
  @override
  ScaleDegreeChord addSeventh({HarmonicFunction? harmonicFunction}) {
    if (pattern.intervals.length >= 4) return ScaleDegreeChord.copy(this);
    switch (pattern.fullName) {
      case "Minor":
        return ScaleDegreeChord.raw(ChordPattern.parse('Minor 7th'), root);
      case "Major":
        if (root == ScaleDegree.V ||
            (harmonicFunction != null &&
                harmonicFunction == HarmonicFunction.dominant)) {
          return ScaleDegreeChord.raw(ChordPattern.parse('Dominant 7th'), root);
        } else {
          return ScaleDegreeChord.raw(ChordPattern.parse('Major 7th'), root);
        }
      case "Augmented":
        return ScaleDegreeChord.raw(ChordPattern.parse('Augmented 7th'), root);
      case "Diminished":
        // not sure if to add 'Diminished 7th' here somehow...
        return ScaleDegreeChord.raw(ChordPattern.parse('Minor 7th ♭5'), root);
      default:
        return ScaleDegreeChord.copy(this);
    }
  }

  @override
  String get rootString {
    if (pattern.hasMinor3rd) {
      return root.toString().toLowerCase();
    }
    return root.toString();
  }

  List<int>? get inversionNumbers {
    if (!_bassInChord) return null;
    Interval bassToRoot = bass.from(root);
    int first = degrees[0].from(bass).number;
    switch (bassToRoot.number) {
      case 3:
        if (patternLength > 3) {
          return [first, degrees.last.from(bass).number];
        } else {
          return [first];
        }
      case 5:
        if (patternLength > 3) {
          return [first, degrees.last.from(bass).number];
        } else {
          int third = degrees[1].from(bass).number;
          return [third, first];
        }
      case 7:
        int third = degrees[1].from(bass).number;
        return [third, first];
      default:
        return [
          for (int i = 0; i < patternLength; i++)
            if (pattern.intervals[i] != bassToRoot) degrees[i].from(bass).number
        ]..sort((a, b) => -1 * a.compareTo(b));
    }
  }

  static const String _upperBass = '⁰¹²³⁴⁵⁶⁷⁸⁹';
  static const String _lowerBass = '₀₁₂₃₄₅₆₇₈₉';

  @override
  String get bassString {
    if (!hasDifferentBass) return '';
    List<int>? nums = inversionNumbers;
    if (nums == null) return _generateInputBass;
    switch (nums.length) {
      case 1:
      case 2:
        String str = '', bass = _upperBass;
        for (int i = 0; i < nums.length; i++) {
          str += bass[nums[i]];
          bass = _lowerBass;
        }
        return str;
      default:
        return '^(${nums.join('-')})';
    }
  }

  @override
  String toString() =>
      rootString + (hasDifferentBass ? bassString : patternString);

  String get inputString =>
      rootString + patternString + (hasDifferentBass ? _generateInputBass : '');

  String get _generateInputBass {
    Interval bassToRoot = bass.from(root);
    int degree = bassToRoot.number, accidentals;
    List<int> nums =
        pattern.intervals.map((e) => e.number).toList(growable: false);
    int index = nums.indexOf(degree);
    Interval d;
    if (index == -1) {
      /* TODO: Make a harmonic analysis to choose which interval to use on the
             7th when the chord doesn't have one - for instance a V should have
             a min7 like other minor chords instead of a maj7 like other maj
             chords etc... */
      d = Interval(number: degree);
    } else {
      d = pattern.intervals[index];
    }
    accidentals = bassToRoot.semitones - d.semitones;
    return '^${(accidentals < 0 ? 'b' : '#') * accidentals.abs()}$degree';
  }

  PitchChord inScale(PitchScale scale) => PitchChord(
      pattern: pattern, root: root.inScale(scale), bass: bass.inScale(scale));

  @override
  bool operator ==(Object other) =>
      other is ScaleDegreeChord &&
      (other.pattern.equals(pattern) && other.root == root);

  @override
  int get hashCode => Object.hash(pattern.fullName, root);

  @override
  int get id => Identifiable.hash2(
      Identifiable.hashAllInts(utf8.encode(pattern.fullName)), root.id);

  /// Returns true if the chord is equal to [other], such that their triads + 7
  /// are equal. Tensions aren't taken into consideration.
  /// If there's no 7 in only one of the chords we treat it as if it had the
  /// relevant diatonic 7, base on the Major Scale. Meaning that in a major key
  /// a ii would be weakly equal to a ii7 but not a iimaj7.
  bool weakEqual(ScaleDegreeChord other) {
    if (root != other.root) {
      return false;
    } else if (pattern == other.pattern) {
      return true;
    }
    List<Interval> ownIntervals = pattern.intervals.sublist(1, 3);
    List<Interval> otherIntervals = other.pattern.intervals.sublist(1, 3);
    for (int i = 0; i < 2; i++) {
      if (!ownIntervals[i].equals(otherIntervals[i])) return false;
    }
    if (pattern.intervals.length >= 4) {
      if (other.pattern.intervals.length >= 4) {
        if (!pattern.intervals[3].equals(other.pattern.intervals[3])) {
          return false;
        }
      } else {
        if (!root.add(pattern.intervals[3]).isDiatonic) {
          return false;
        }
      }
    } else {
      if (other.pattern.intervals.length >= 4) {
        if (!other.root.add(other.pattern.intervals[3]).isDiatonic) {
          return false;
        }
      }
    }
    return true;
  }

  /// Returns a hash of the chord with no tensions. 7th are hashed in if
  /// they're not diatonic (based on the major scale).
  int get weakHash {
    List<Interval> intervals = pattern.intervals.sublist(1, 3);
    if (intervals.length >= 4) {
      if (!root.add(pattern.intervals[3]).isDiatonic) {
        intervals.add(pattern.intervals[3]);
      }
    }
    return Object.hash(
        root,
        Object.hashAll(
            [for (Interval interval in intervals) interval.getHash]));
  }

  /// Like [weakHash] but is consistent over executions.
  int get weakID {
    List<Interval> intervals = pattern.intervals.sublist(1, 3);
    if (intervals.length >= 4) {
      if (!root.add(pattern.intervals[3]).isDiatonic) {
        intervals.add(pattern.intervals[3]);
      }
    }
    return Identifiable.hash2(
        root.id,
        Identifiable.hashAllInts(
            [for (Interval interval in intervals) interval.id]));
  }

  HarmonicFunction deriveHarmonicFunction({ScaleDegreeChord? next}) {
    int weakHash = this.weakHash;
    if (defaultFunctions.containsKey(weakHash)) {
      Map<List<int>?, HarmonicFunction> forChord = defaultFunctions[weakHash]!;
      if (next != null) {
        for (MapEntry<List<int>?, HarmonicFunction> entry in forChord.entries) {
          if (entry.key != null && entry.key!.contains(weakHash)) {
            return entry.value;
          }
        }
      }
      return forChord[null]!;
    }
    return HarmonicFunction.undefined;
  }

  static final Map<int, Map<List<int>?, HarmonicFunction>> defaultFunctions =
      <ScaleDegreeChord, Map<List<String>?, HarmonicFunction>>{
    ScaleDegreeChord.majorTonicTriad: {
      null: HarmonicFunction.tonic,
    },
    ScaleDegreeChord.ii: {
      null: HarmonicFunction.subDominant,
    },
    ScaleDegreeChord.parse('iidim'): {
      null: HarmonicFunction.subDominant,
    },
    ScaleDegreeChord.parse('bVII'): {
      null: HarmonicFunction.subDominant,
    },
    ScaleDegreeChord.iii: {
      null: HarmonicFunction.tonic,
    },
    ScaleDegreeChord.parse('III'): {
      null: HarmonicFunction.dominant,
    },
    ScaleDegreeChord.parse('iv'): {
      null: HarmonicFunction.subDominant,
    },
    ScaleDegreeChord.IV: {
      null: HarmonicFunction.subDominant,
    },
    ScaleDegreeChord.V: {
      null: HarmonicFunction.dominant,
    },
    ScaleDegreeChord.vi: {
      null: HarmonicFunction.tonic,
      ['V', 'V7', 'viidim']: HarmonicFunction.subDominant,
    },
    ScaleDegreeChord.viidim: {
      null: HarmonicFunction.dominant,
      ['I']: HarmonicFunction.dominant,
      ['vi']: HarmonicFunction.subDominant,
    }
  }.map((ScaleDegreeChord key, Map<List<String>?, HarmonicFunction> value) =>
          MapEntry<int, Map<List<int>?, HarmonicFunction>>(key.weakHash, {
            for (MapEntry<List<String>?, HarmonicFunction> entry
                in value.entries)
              (entry.key == null
                  ? null
                  : [
                      for (String chord in entry.key!)
                        ScaleDegreeChord.parse(chord).weakHash
                    ]): entry.value
          }));

  static final ScaleDegreeChord majorTonicTriad = ScaleDegreeChord.parse('I');
  static final ScaleDegreeChord ii = ScaleDegreeChord.parse('ii');
  static final ScaleDegreeChord iii = ScaleDegreeChord.parse('iii');

// ignore: non_constant_identifier_names
  static final ScaleDegreeChord IV = ScaleDegreeChord.parse('IV');
  static final ScaleDegreeChord V = ScaleDegreeChord.parse('V');
  static final ScaleDegreeChord vi = ScaleDegreeChord.parse('vi');
  static final ScaleDegreeChord viidim = ScaleDegreeChord.parse('viidim');
}

enum HarmonicFunction {
  tonic,
  subDominant,
  dominant,
  undefined,
}
