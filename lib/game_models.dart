import 'dart:math';

enum GameType { maze, platformer, driving }

extension GameTypeText on GameType {
  String get title => switch (this) {
        GameType.maze => 'هزارتو',
        GameType.platformer => 'سکوبازی',
        GameType.driving => 'رانندگی',
      };
  String get description => switch (this) {
        GameType.maze => 'از مسیرهای پیچ‌درپیچ عبور کن و گنج را پیدا کن.',
        GameType.platformer => 'بپر، از دشمن‌ها دوری کن و سکه جمع کن.',
        GameType.driving => 'در سه مسیر رانندگی کن و از موانع جاخالی بده.',
      };
  String get emoji => switch (this) {
        GameType.maze => '🧭',
        GameType.platformer => '🦸',
        GameType.driving => '🏎️',
      };
  int get columns => switch (this) {
        GameType.maze => 11,
        GameType.platformer => 12,
        GameType.driving => 3,
      };
  int get rows => switch (this) {
        GameType.maze => 11,
        GameType.platformer => 8,
        GameType.driving => 8,
      };
}

const characterOptions = ['🧒', '👧', '🐱', '🐸', '🦊', '🐼', '🦄', '🤖'];
const backgroundNames = ['جنگل جادویی', 'جزیره آفتابی', 'فضای کهکشانی', 'سرزمین آب‌نباتی'];
const backgroundTop = [0xFFB8E6C1, 0xFF9EDCF5, 0xFF202A64, 0xFFFFC6D8];
const backgroundBottom = [0xFFECF8C9, 0xFFFFE7A8, 0xFF7357A6, 0xFFFFE5A8];

class GameProject {
  GameProject({
    required this.id,
    required this.name,
    required this.type,
    required this.cells,
    this.character = 0,
    this.background = 0,
    this.soundEnabled = true,
    this.musicEnabled = false,
    List<List<int>>? stages,
    this.activeLevel = 0,
    List<List<List<int>>>? levelLayers,
    this.activeLayer = 0,
  })  : levels = stages ?? [List<int>.from(cells)],
        layersByLevel = levelLayers ??
            (stages ?? [List<int>.from(cells)])
                .map((stage) => [List<int>.from(stage)])
                .toList() {
    _normalizeLayers();
  }

  final String id;
  String name;
  GameType type;
  List<int> cells;
  int character;
  int background;
  bool soundEnabled;
  bool musicEnabled;
  List<List<int>> levels;
  int activeLevel;
  int activeLayer;
  List<List<List<int>>> layersByLevel;

  List<List<int>> get layers => layersByLevel[activeLevel];

  static const layerNames = ['لایه اصلی', 'پس‌زمینه', 'زمین و سکو', 'اشیا و جایزه‌ها', 'شخصیت‌ها و دشمنان'];

  void _normalizeLayers() {
    if (levels.isEmpty) levels = [List<int>.from(cells)];
    while (layersByLevel.length < levels.length) {
      layersByLevel.add([List<int>.from(levels[layersByLevel.length])]);
    }
    if (layersByLevel.length > levels.length) {
      layersByLevel = layersByLevel.take(levels.length).toList();
    }
    for (var stage = 0; stage < layersByLevel.length; stage++) {
      if (layersByLevel[stage].isEmpty) {
        layersByLevel[stage] = [List<int>.from(levels[stage])];
      }
      layersByLevel[stage] = layersByLevel[stage].take(layerNames.length).map((layer) =>
          List<int>.generate(columns * rows, (i) => i < layer.length ? layer[i] : 0)).toList();
    }
    activeLevel = activeLevel.clamp(0, levels.length - 1).toInt();
    activeLayer = activeLayer.clamp(0, layers.length - 1).toInt();
  }

  List<int> composeLayers([int? stageIndex]) {
    final stage = (stageIndex ?? activeLevel).clamp(0, layersByLevel.length - 1).toInt();
    return _composeLayerStack(layersByLevel[stage], columns * rows);
  }

  static List<int> _composeLayerStack(List<List<int>> layers, int length) {
    final result = List<int>.filled(length, 0);
    for (final layer in layers) {
      for (var i = 0; i < result.length; i++) {
        if (layer[i] == -1) {
          result[i] = 0;
        } else if (layer[i] != 0) {
          result[i] = layer[i];
        }
      }
    }
    return result;
  }

  void addLayer() {
    if (layers.length >= layerNames.length) return;
    layers.add(List<int>.filled(columns * rows, 0));
    activeLayer = layers.length - 1;
    cells = composeLayers();
  }

  void removeActiveLayer() {
    if (layers.length <= 1) return;
    layers.removeLast();
    activeLayer = activeLayer.clamp(0, layers.length - 1).toInt();
    cells = composeLayers();
  }

  int get columns => type.columns;
  int get rows => type.rows;

  GameProject copy() {
    syncActiveLevel();
    return GameProject(
      id: id,
      name: name,
      type: type,
      cells: List<int>.from(cells),
      character: character,
      background: background,
      soundEnabled: soundEnabled,
      musicEnabled: musicEnabled,
      stages: levels.map((stage) => List<int>.from(stage)).toList(),
      activeLevel: activeLevel,
      activeLayer: activeLayer,
      levelLayers: layersByLevel.map((stage) => stage.map((layer) => List<int>.from(layer)).toList()).toList(),
    );
  }

  void syncActiveLevel() {
    if (levels.isEmpty) levels = [List<int>.from(cells)];
    _normalizeLayers();
    activeLevel = activeLevel.clamp(0, levels.length - 1).toInt();
    final composed = composeLayers();
    if (activeLayer == 0 && cells.toString() != composed.toString()) {
      layersByLevel[activeLevel][0] = List<int>.from(cells);
    }
    levels[activeLevel] = List<int>.from(cells);
  }

  void setActiveLevel(int index) {
    syncActiveLevel();
    activeLevel = index.clamp(0, levels.length - 1).toInt();
    activeLayer = 0;
    cells = composeLayers();
  }

  void addLevel({List<int>? copyFrom}) {
    syncActiveLevel();
    final next = copyFrom == null ? List<int>.filled(columns * rows, 0) : List<int>.from(copyFrom);
    levels.add(next);
    layersByLevel.add(copyFrom == null
        ? [List<int>.from(next)]
        : layers.map((layer) => List<int>.from(layer)).toList());
    activeLevel = levels.length - 1;
    activeLayer = 0;
    cells = List<int>.from(next);
  }

  void removeActiveLevel() {
    if (levels.length <= 1) return;
    syncActiveLevel();
    levels.removeAt(activeLevel);
    layersByLevel.removeAt(activeLevel);
    activeLevel = activeLevel.clamp(0, levels.length - 1).toInt();
    activeLayer = 0;
    cells = composeLayers();
  }

  Map<String, dynamic> toJson() {
    syncActiveLevel();
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'cells': cells,
      'levels': levels,
      'activeLevel': activeLevel,
      'activeLayer': activeLayer,
      'levelLayers': layersByLevel,
      'character': character,
      'background': background,
      'soundEnabled': soundEnabled,
      'musicEnabled': musicEnabled,
    };
  }

  factory GameProject.fromJson(Map<String, dynamic> json) {
    final type = GameType.values.firstWhere(
      (e) => e.name == (json['type'] ?? json['kind']),
      orElse: () => GameType.maze,
    );
    final expected = type.columns * type.rows;
    final rawValue = json['cells'];
    final allowedValues = switch (type) {
      GameType.maze => const {0, 1, 2, 4, 5},
      GameType.platformer => const {0, 1, 2, 3, 4, 5},
      GameType.driving => const {0, 2, 3},
    };
    List<int> normalizeCells(dynamic source) {
      final values = source is List
          ? source.map((e) => e is num ? e.toInt() : -999999).toList()
          : <int>[];
      return List<int>.generate(expected, (i) {
        final value = i < values.length ? values[i] : 0;
        return allowedValues.contains(value) ? value : 0;
      });
    }
    final cells = normalizeCells(rawValue);
    final rawStages = json['levels'];
    final levels = rawStages is List
        ? rawStages.whereType<List>().take(20).map(normalizeCells).toList()
        : <List<int>>[];
    if (levels.isEmpty) levels.add(List<int>.from(cells));
    final activeValue = json['activeLevel'];
    final activeLevel = (activeValue is num ? activeValue.toInt() : 0).clamp(0, levels.length - 1).toInt();
    final rawLayerStages = json['levelLayers'];
    final levelLayers = <List<List<int>>>[];
    if (rawLayerStages is List) {
      for (final stage in rawLayerStages.take(20)) {
        if (stage is List) {
          final parsed = stage.take(layerNames.length).map((rawLayer) {
            final values = rawLayer is List ? rawLayer : const <dynamic>[];
            return List<int>.generate(expected, (i) {
              final value = i < values.length && values[i] is num ? (values[i] as num).toInt() : 0;
              return value == -1 || allowedValues.contains(value) ? value : 0;
            });
          }).toList();
          levelLayers.add(parsed.isEmpty ? [List<int>.from(cells)] : parsed);
        } else {
          levelLayers.add([List<int>.from(cells)]);
        }
      }
    }
    while (levelLayers.length < levels.length) {
      levelLayers.add([List<int>.from(levels[levelLayers.length])]);
    }
    if (levelLayers.length > levels.length) levelLayers.removeRange(levels.length, levelLayers.length);
    final activeLayerValue = json['activeLayer'];
    final activeLayer = (activeLayerValue is num ? activeLayerValue.toInt() : 0)
        .clamp(0, levelLayers[activeLevel].length - 1).toInt();
    final activeCells = _composeLayerStack(levelLayers[activeLevel], expected);
    final characterValue = json['character'];
    final backgroundValue = json['background'];
    final nameValue = json['name']?.toString().trim() ?? '';
    final idValue = json['id']?.toString().trim() ?? '';
    return GameProject(
      id: idValue.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : idValue,
      name: nameValue.isEmpty ? 'بازی من' : nameValue,
      type: type,
      cells: activeCells,
      stages: levels,
      activeLevel: activeLevel,
      activeLayer: activeLayer,
      levelLayers: levelLayers,
      character: (characterValue is num ? characterValue.toInt() : 0).clamp(0, characterOptions.length - 1).toInt(),
      background: (backgroundValue is num ? backgroundValue.toInt() : 0).clamp(0, backgroundNames.length - 1).toInt(),
      soundEnabled: json['soundEnabled'] is bool ? json['soundEnabled'] as bool : true,
      musicEnabled: json['musicEnabled'] is bool ? json['musicEnabled'] as bool : false,
    );
  }

  static GameProject create(GameType type, String name) {
    final count = type.columns * type.rows;
    final cells = List<int>.filled(count, 0);
    final random = Random();
    if (type == GameType.maze) {
      for (var r = 0; r < 11; r++) {
        for (var c = 0; c < 11; c++) {
          cells[r * 11 + c] = 1;
        }
      }
      for (var r = 1; r < 10; r += 2) {
        for (var c = 1; c < 10; c += 2) {
          cells[r * 11 + c] = 0;
        }
      }
      final visited = <int>{12};
      final stack = <int>[12];
      cells[12] = 5;
      while (stack.isNotEmpty) {
        final current = stack.last;
        final candidates = <int>[];
        for (final delta in [-22, 22, -2, 2]) {
          final next = current + delta;
          final nr = next ~/ 11;
          final nc = next % 11;
          if (nr >= 1 && nr <= 9 && nc >= 1 && nc <= 9 && !visited.contains(next)) {
            candidates.add(next);
          }
        }
        if (candidates.isEmpty) {
          stack.removeLast();
        } else {
          final next = candidates[random.nextInt(candidates.length)];
          final between = (current + next) ~/ 2;
          cells[between] = 0;
          cells[next] = 0;
          visited.add(next);
          stack.add(next);
        }
      }
      cells[108] = 4;
      final open = <int>[];
      for (var i = 0; i < cells.length; i++) {
        if (cells[i] == 0 && i != 12 && i != 108) open.add(i);
      }
      open.shuffle(random);
      for (final i in open.take(8)) cells[i] = 2;
    } else if (type == GameType.platformer) {
      for (var c = 0; c < 12; c++) cells[7 * 12 + c] = 1;
      for (final i in [17, 20, 26, 30, 39, 43, 51, 56, 66, 70]) {
        if (i < cells.length) cells[i] = 2;
      }
      for (final i in [22, 34, 47, 61]) cells[i] = 3;
      for (final i in [27, 41, 53]) cells[i] = 1;
      cells[6 * 12 + 11] = 4;
      cells[6 * 12] = 5;
    } else if (type == GameType.driving) {
      for (final i in [2, 9, 14, 17]) {
        cells[i] = 3;
      }
      for (final i in [1, 4, 7, 13, 19]) {
        cells[i] = 2;
      }
    }
    return GameProject(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      type: type,
      cells: cells,
    );
  }
}
