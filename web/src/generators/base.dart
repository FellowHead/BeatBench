import 'dart:html';
import 'dart:web_audio';

import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';

import '../json.dart';
import '../notes.dart';
import '../project.dart';
import '../windows/piano_roll.dart';
import '../windows/windows.dart';

abstract class GeneratorInterface<G extends Generator> extends Window {
  GeneratorInterface() : super(DivElement()..className = 'generator', '');

  void _init(G gen) async {
    element.parent.firstChild.append(ButtonElement()
      ..className = 'reload'
      ..text = 'Reload'
      ..onClick.listen((e) {
        element.children.clear();
        _load(gen);
      }));
    _load(gen);
  }

  void _load(G gen) async {
    title = gen.name;
    element.id = styleId;

    Document html = await _loadFile('$htmlPath', 'document');
    var validNodes = html.querySelector('generator').children.toList();
    validNodes.forEach((v) => element.append(v));

    var srcCss = await _loadFile('$cssPath', 'text');

    var errors = <css.Message>[];
    var parsedStyleSheet = css.parse(srcCss, errors: errors);
    print('Parse error count: ${errors.length}');
    errors.forEach((err) {
      print('ERROR: ${err.level.index} - ${err.message}');
    });

    // create a stylesheet element
    var styleElement = StyleElement();
    document.head.append(styleElement);
    // use the styleSheet from that
    CssStyleSheet sheet = styleElement.sheet;

    parsedStyleSheet.topLevels.forEach((top) {
      var ruleset = '';
      if (top is RuleSet) {
        var printer = CssPrinter();
        top.selectorGroup.visit(printer);

        if (printer.toString() == 'generator') {
          ruleset = '.generator#$styleId';
        } else {
          // modify selectors
          var selectors = top.selectorGroup.selectors;
          for (var i = 0; i < selectors.length; i++) {
            var printer = CssPrinter();
            selectors[i].visit(printer);
            if (i > 0) {
              ruleset += ', ';
            }
            ruleset += '#$styleId ' + printer.toString();
          }
        }
        // include rules
        printer = CssPrinter();
        top.declarationGroup.visit(printer);
        var declaration = printer.toString();
        ruleset += '{ $declaration }';
      }
      //print('inserting rule');
      //print(rule);
      sheet.insertRule(ruleset);
    });

    domInit(gen);
  }

  static Future<dynamic> _loadFile(String path, String type) async {
    var request = await HttpRequest.request(
      Uri.file('src/generators/$path').toString(),
      responseType: type,
    );
    return request.response;
  }

  void domInit(G generator);
  String get htmlPath;
  String get cssPath;
  String get styleId;

  @override
  Element query(String selectors) => element.querySelector(selectors);
}

abstract class Generator<T extends NoteNodeChain> extends ContextDependent
    with NodeChain, Json {
  GainNode _gain;
  final List<T> _playingNodes = [];
  Iterable<T> get playingNodes => _playingNodes.toList(growable: false);

  final GeneratorInterface _interface;
  GeneratorInterface get interface => _interface;
  GeneratorInterface get visible => _interface.visible ? _interface : null;

  final String id;

  bool _rendering = false;
  bool get rendering => _rendering;
  Generator<T> _renderGen;

  Generator<T> cloneForRender(OfflineAudioContext ctx);

  void initOffline(OfflineAudioContext ctx) {
    _newContext(ctx, rendering: true);
    _renderGen = cloneForRender(ctx);
  }

  void initOnline(AudioContext ctx) {
    _newContext(ctx, rendering: false);
  }

  void _newContext(BaseAudioContext ctx, {bool rendering = false}) {
    _rendering = rendering;
    this.ctx = ctx;
    _gain = ctx.createGain()..connectNode(ctx.destination);
  }

  Generator(BaseAudioContext ctx, GeneratorInterface interface, this.id)
      : _interface = interface,
        super(ctx) {
    _newContext(ctx);
    _interface?._init(this);
    chainEnd.connectNode(_gain);
  }

  T _getNode(int pitch) => _playingNodes
      .firstWhere((node) => node.info.coarsePitch == pitch, orElse: () => null);

  PianoRoll get _pianoRoll => Project.instance.pianoRoll;
  bool get _activeInPianoRoll => _pianoRoll.component.generator == this;

  @override
  Map<String, dynamic> toJson() => {
        'type': id,
      };

  @override
  void fromJson(json) {
    print('load this bad boi');
  }

  void noteStart(NoteInfo note, double when, bool resume) {
    if (rendering) {
      return _renderGen.noteStart(note, when, resume);
    }
    noteEnd(note.coarsePitch, when);
    var node = createNode(note, resume);
    if (node != null) {
      node.chainEnd.connectNode(chainStart);
      _playingNodes.add(node);
      node.start(when);
    }
    if (_activeInPianoRoll) {
      _pianoRoll.setKeyVisuallyPlaying(note.coarsePitch, true);
    }
  }

  void noteEnd(int pitch, double when) {
    if (rendering) {
      return _renderGen.noteEnd(pitch, when);
    }
    var playingNode = _getNode(pitch);
    if (playingNode != null) {
      playingNode.stop(when);
      _playingNodes.remove(playingNode);
    }
    if (_activeInPianoRoll) {
      _pianoRoll.setKeyVisuallyPlaying(pitch, false);
    }
  }

  T createNode(NoteInfo info, bool resume);

  String get name;
}

// Container of connected AudioNodes
mixin NodeChain {
  AudioNode get chainStart => chain.first;
  AudioNode get chainEnd => chain.last;

  List<AudioNode> get chain;
}

abstract class ContextDependent {
  BaseAudioContext ctx;
  ContextDependent(this.ctx);
}

abstract class NoteNodeChain extends ContextDependent with NodeChain {
  final NoteInfo info;

  NoteNodeChain(this.info, BaseAudioContext ctx) : super(ctx);

  void start(double when);
  void stop(double when);
}
