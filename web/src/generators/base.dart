import 'dart:web_audio';

import '../notes.dart';

abstract class Generator {
  final GainNode node;

  Generator(AudioContext ctx)
      : node = ctx.createGain()..connectNode(ctx.destination);

  void playNote(Note note, double when);
}
