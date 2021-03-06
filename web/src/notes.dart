import 'package:meta/meta.dart';

import 'bar_fraction.dart';
import 'patterns.dart';
import 'project.dart';
import 'transformable.dart';
import 'windows/piano_roll.dart';

class CommonPitch {
  static const _keyNames = [
    'C',
    null,
    'D',
    null,
    'E',
    'F',
    null,
    'G',
    null,
    'A',
    null,
    'B'
  ];

  final int pitch;
  final int mod; // pitch % 12
  String get description => '$name$octave';
  bool get whiteKey => _keyNames[mod] != null;
  String get name => _keyNames[mod] ?? _keyNames[mod - 1] + '#';
  int get octave => (pitch / 12).floor();

  CommonPitch(this.pitch) : mod = pitch % 12;
}

class NoteInfo {
  final int coarsePitch;
  final double velocity;

  const NoteInfo(this.coarsePitch, this.velocity);
}

class Note with Transformable {
  final PatternNotesComponent comp;
  static int octave(int tone, int octave) => tone + octave * 12;

  Note(this.comp,
      {@required int pitch,
      start = const BarFraction.zero(),
      length = const BarFraction(1, 16)}) {
    y = pitch;
    this.start = start;
    this.length = length;
  }

  NoteInfo createInfo() => NoteInfo(y, 1);

  static const int C = 0;
  static const int D = 2;
  static const int E = 4;
  static const int F = 5;
  static const int G = 7;
  static const int A = 9;
  static const int B = 11;

  @override
  void onTransformed() {
    _pianoRollRef?.onUpdate();
    comp.streamController.add('transformed');
  }

  Map<String, dynamic> toJson() => {
        'pitch': y,
        'start': start.toJson(),
        'length': length.toJson(),
      };

  Note.fromJson(PatternNotesComponent comp, json)
      : this(
          comp,
          pitch: json['pitch'],
          start: BarFraction.parse(json['start']),
          length: BarFraction.parse(json['length']),
        );

  PianoRollNote get _pianoRollRef => Project.instance.pianoRoll.items
      .firstWhere((pn) => pn.note == this, orElse: () => null);
}
