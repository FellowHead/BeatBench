import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'drag.dart';
import 'notes.dart';
import 'beat_fraction.dart';
import 'timeline.dart';
import 'utils.dart';

abstract class PatternDataComponent {
  final StreamController _streamController = StreamController.broadcast(
    sync: true,
    onListen: () => print('hello there?'),
  );
  Stream get stream => _streamController.stream;

  BeatFraction length();
}

class PatternNotesComponent extends PatternDataComponent {
  final List<Note> _notes;
  Iterable<Note> get notes => Iterable.castFrom(_notes);

  PatternNotesComponent(Iterable<Note> notes) : _notes = notes.toList();

  @override
  BeatFraction length() {
    return notes.fold(
        BeatFraction.washy(0), (v, n) => n.end.beats > v.beats ? n.end : v);
  }

  void add(Note note) {
    _notes.add(note);
    _streamController.add('add');
  }

  void remove(Note note) {
    _notes.remove(note);
    _streamController.add('remoof');
  }
}

class PatternData {
  final Map<int, PatternNotesComponent> _instrumentNotes = {};
  String name;

  PatternData(this.name, Map<int, PatternNotesComponent> instrumentNotes) {
    _instrumentNotes.addAll(instrumentNotes);
  }

  PatternNotesComponent component(int instrument) {
    return _instrumentNotes[instrument];
  }

  Map<int, PatternNotesComponent> notes() => Map.unmodifiable(_instrumentNotes);

  BeatFraction length() {
    return _instrumentNotes.values.fold(BeatFraction.washy(0), (v, n) {
      var l = n.length();
      return l.beats > v.beats ? l : v;
    });
  }

  void listenToEdits(void Function(dynamic) handler) {
    _instrumentNotes.values.forEach((comp) => comp.stream.listen(handler));
  }
}

class PatternInstance {
  BeatFraction _start;
  BeatFraction get start => _start;
  set start(BeatFraction start) {
    _silentStart(start);
    _onMove();
  }

  void _silentStart(BeatFraction start) {
    _start = start.beats >= 0 ? start : BeatFraction(0, 1);
    _e.style.left = cssCalc(_start.beats, Timeline.pixelsPerBeat);
  }

  BeatFraction _length;
  BeatFraction get length => _length;
  set length(BeatFraction length) {
    _silentLength(length);
    _draw();
    _onMove();
  }

  void _silentLength(BeatFraction length) {
    _length = length.beats >= 1 ? length : BeatFraction(1, 4);
    _e.style.width = cssCalc(_length.beats, Timeline.pixelsPerBeat);
    _canvas.width = (_length.beats * Timeline.pixelsPerBeat.value).ceil();
  }

  int _track;
  int get track => _track;
  set track(int track) {
    _track = max(0, track);
    _e.style.top = cssCalc(_track, Timeline.pixelsPerTrack);
  }

  final void Function() _onMove;
  final PatternData data;

  HtmlElement _e;
  InputElement _input;
  CanvasElement _canvas;

  BeatFraction get end => start + length;

  PatternInstance(
    this.data,
    BeatFraction start,
    BeatFraction length,
    int track,
    void Function() onMove,
  ) : _onMove = onMove {
    _input = InputElement(type: 'text')
      ..className = 'shy'
      ..value = data.name;

    _e = querySelector('#patterns').append(DivElement()
      ..className = 'pattern'
      ..append(_input)
      ..append(
          _canvas = CanvasElement(height: Timeline.pixelsPerTrack.value.ceil()))
      ..append(stretchElem(false))
      ..append(stretchElem(true)));

    Draggable(_e, () => this.start, () => this.track,
        (firstStart, firstTrack, pixelOff) {
      this.start = (firstStart as BeatFraction) +
          BeatFraction((pixelOff.x / Timeline.pixelsPerBeat.value).round(), 4);
      this.track = (firstTrack as int) +
          (pixelOff.y / Timeline.pixelsPerTrack.value + 0.5).floor();
    });

    _silentStart(start);
    _silentLength(length ?? data.length().ceilTo(2));
    this.track = track;
    _draw();

    data.listenToEdits((ev) {
      _draw();
    });
  }

  DivElement stretchElem(bool right) {
    var out = DivElement()..className = 'stretch ${right ? 'right' : 'left'}';
    Draggable(out, right ? () => length : () => null, () => null,
        (srcLength, y, off) {
      length = (srcLength as BeatFraction) +
          BeatFraction((off.x / Timeline.pixelsPerBeat.value).round(), 4);
    });
    return out;
  }

  void _draw() {
    var ctx = _canvas.context2D;
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
    var minPitch = 1000;
    var maxPitch = 0;
    data._instrumentNotes.forEach((instrument, component) {
      component.notes.forEach((n) {
        if (n.coarsePitch > maxPitch) maxPitch = n.coarsePitch;
        if (n.coarsePitch < minPitch) minPitch = n.coarsePitch;
      });
    });

    var diff = maxPitch - minPitch;
    var noteHeight = Timeline.pixelsPerTrack.value / max(diff + 1, 8);

    ctx.fillStyle = '#fff';

    data._instrumentNotes.forEach((instrument, component) {
      component.notes.forEach((n) {
        ctx.fillRect(
            Timeline.pixelsPerBeat.value * n.start.beats,
            Timeline.pixelsPerTrack.value -
                (n.coarsePitch - minPitch + 1) * noteHeight,
            Timeline.pixelsPerBeat.value * n.length.beats - 1,
            noteHeight);
      });
    });
  }
}
