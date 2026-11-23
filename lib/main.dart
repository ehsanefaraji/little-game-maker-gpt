import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_audio.dart';
import 'game_models.dart';
import 'platformer_flame_game.dart';
import 'game_art.dart';
import 'premium_art.dart';

const purple = Color(0xFF7657D5);
const ink = Color(0xFF302747);
const pageBg = Color(0xFFF4F5FB);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LittleGameMaker());
}

class LittleGameMaker extends StatelessWidget {
  const LittleGameMaker({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'بازی‌ساز کوچولو',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: purple),
          scaffoldBackgroundColor: pageBg,
          visualDensity: VisualDensity.standard,
          splashFactory: InkSparkle.splashFactory,
          cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
          inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFFF8F6FD), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
          filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13))),
          appBarTheme: const AppBarTheme(backgroundColor: pageBg, foregroundColor: ink, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
        ),
        home: const HomePage(),
      );
}

class ProjectStore {
  static const _key = 'little_game_maker_projects_v2';
  static const _legacyKey = 'lgm_projects_v1';
  static Future<List<GameProject>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? prefs.getString(_legacyKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => GameProject.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<GameProject> projects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(projects.map((e) => e.toJson()).toList()));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<GameProject> projects = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final result = await ProjectStore.load();
    if (mounted) setState(() { projects = result; loading = false; });
  }

  Future<void> _exportProjects() async {
    final data = JsonEncoder.withIndent('  ').convert(projects.map((p) => p.toJson()).toList());
    await Clipboard.setData(ClipboardData(text: data));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پشتیبان بازی‌ها در حافظه موقت کپی شد. آن را در یک فایل متنی ذخیره کن.')));
  }

  Future<void> _importProjects() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بازی‌ها را وارد کن'),
        content: SizedBox(width: 520, child: TextField(
          controller: controller,
          minLines: 5,
          maxLines: 10,
          decoration: const InputDecoration(hintText: 'متن پشتیبان JSON را اینجا جای‌گذاری کن'),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('وارد کردن')),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      final incoming = decoded is List
          ? decoded.whereType<Map>().map((e) => GameProject.fromJson(Map<String, dynamic>.from(e))).toList()
          : decoded is Map
              ? [GameProject.fromJson(Map<String, dynamic>.from(decoded))]
              : <GameProject>[];
      if (incoming.isEmpty) throw const FormatException('empty project list');
      final merged = List<GameProject>.from(projects);
      for (final project in incoming) {
        final index = merged.indexWhere((p) => p.id == project.id);
        if (index < 0) {
          merged.add(project);
        } else {
          merged[index] = project;
        }
      }
      await ProjectStore.save(merged);
      if (!mounted) return;
      setState(() => projects = merged);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${incoming.length} بازی با موفقیت وارد شد.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فایل پشتیبان معتبر نیست یا ساختار آن پشتیبانی نمی‌شود.')));
    }
  }

  Future<void> _create(GameType type) async {
    final controller = TextEditingController(text: 'بازی ' + type.title + ' من');
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('ساخت ' + type.title),
        content: TextField(controller: controller, autofocus: true, maxLength: 28, decoration: const InputDecoration(labelText: 'نام بازی')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(d, controller.text.trim()), child: const Text('ساخت بازی')),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    await _openEditor(GameProject.create(type, name.isEmpty ? 'بازی من' : name));
  }

  Future<void> _openEditor(GameProject project) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditorPage(project: project.copy())));
    await _refresh();
  }

  Future<void> _delete(GameProject project) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('حذف بازی'),
        content: Text('«' + project.name + '» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('نه')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حذف')),
        ],
      ),
    );
    if (yes != true) return;
    projects.removeWhere((e) => e.id == project.id);
    await ProjectStore.save(projects);
    if (mounted) setState(() {});
  }

  void _showHelp() {
    showDialog<void>(context: context, builder: (d) => AlertDialog(
      title: const Text('راهنمای بازی‌ساز 🌟'),
      content: const Text('۱. یک قالب بازی انتخاب کن.\n۲. با ابزارهای طراحی، خانه‌های مرحله را بچین.\n۳. شخصیت و پس‌زمینه را انتخاب کن.\n۴. ذخیره را بزن و بازی را امتحان کن.\n\nبازی‌ها روی همین دستگاه ذخیره می‌شوند و برای ویرایش و بازی‌کردن به اینترنت نیاز ندارند.'),
      actions: [FilledButton(onPressed: () => Navigator.pop(d), child: const Text('فهمیدم'))],
    ));
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      title: const Text('بازی‌ساز کوچولو', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -.3)),
                      actions: [
                        PopupMenuButton<String>(
                          tooltip: 'پشتیبان‌گیری و انتقال بازی‌ها',
                          onSelected: (value) { if (value == 'export') _exportProjects(); if (value == 'import') _importProjects(); },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'export', child: ListTile(dense: true, leading: Icon(Icons.copy_all_rounded), title: Text('کپی پشتیبان بازی‌ها'))),
                            PopupMenuItem(value: 'import', child: ListTile(dense: true, leading: Icon(Icons.file_download_outlined), title: Text('وارد کردن پشتیبان'))),
                          ],
                        ),
                        IconButton(tooltip: 'راهنما', onPressed: _showHelp, icon: const Icon(Icons.help_outline_rounded)),
                        const SizedBox(width: 6),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                        child: AdventureHero(projectCount: projects.length, onCreate: () => _create(GameType.platformer)),
                      ),
                    ),
                    const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, 10), child: Text('ماجراجویی بعدی تو کدام است؟', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)))),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final type = GameType.values[index];
                          final colors = [const Color(0xFFE7E0FF), const Color(0xFFFFE9C8), const Color(0xFFDDF5E6), const Color(0xFFFFDFE8)];
                          return InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => _create(type),
                            child: Ink(
                              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.white, colors[index].withOpacity(.78)]), borderRadius: BorderRadius.circular(25), border: Border.all(color: colors[index].withOpacity(.95), width: 1.3), boxShadow: [BoxShadow(color: colors[index].withOpacity(.65), blurRadius: 18, offset: const Offset(0, 8)), const BoxShadow(color: Color(0x0C302747), blurRadius: 4, offset: Offset(0, 2))]),
                              child: Stack(children: [
                                Positioned(left: 9, top: 8, child: Icon(Icons.auto_awesome_rounded, color: Colors.white.withOpacity(.9), size: 18)),
                                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Container(width: 78, height: 72, padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: colors[index].withOpacity(.78), borderRadius: BorderRadius.circular(23), boxShadow: [BoxShadow(color: colors[index].withOpacity(.65), blurRadius: 12, offset: const Offset(0, 5))]), alignment: Alignment.center, child: GameTileArt(type: type, value: type == GameType.driving ? 4 : 0, isPlayer: type == GameType.maze || type == GameType.platformer || type == GameType.driving)),
                                  const SizedBox(height: 10),
                                  Text(type.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ink)),
                                  Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 0), child: Text(type.description, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 10, height: 1.4, color: Color(0xFF665D78)))),
                                ]),
                              ]),
                            ),
                          );
                        }, childCount: GameType.values.length),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.02),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 26, 18, 10),
                        child: Row(children: [
                          const Expanded(child: Text('بازی‌های من', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink))),
                          Text(projects.length.toString() + ' بازی', style: const TextStyle(color: Colors.black54)),
                        ]),
                      ),
                    ),
                    if (projects.isEmpty)
                      const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 28), child: Card(child: Padding(padding: EdgeInsets.all(22), child: Column(children: [Icon(Icons.toys_rounded, size: 36, color: Color(0xFF9B83E5)), SizedBox(height: 8), Text('کارگاه بازی‌سازی تو آماده است!', style: TextStyle(fontWeight: FontWeight.w900, color: ink)), SizedBox(height: 5), Text('اولین ماجراجویی‌ات را از کارت‌های بالا انتخاب کن.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12))])))))
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                          final project = projects[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 11),
                            child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Colors.white, Color(0xFFF9F7FF)])), child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              leading: Container(width: 52, height: 52, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFECE5FF), Color(0xFFFFEBC9)]), borderRadius: BorderRadius.circular(17)), child: Padding(padding: const EdgeInsets.all(6), child: GameTileArt(type: project.type, value: project.type == GameType.driving ? 4 : 0, character: project.character, isPlayer: true))),
                              title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Text(project.type.title + ' • ' + backgroundNames[project.background] + ' • ' + project.levels.length.toString() + ' مرحله'),
                              onTap: () => _openEditor(project),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _openEditor(project);
                                  if (value == 'play') Navigator.push(context, MaterialPageRoute(builder: (_) => GamePage(project: project.copy())));
                                  if (value == 'delete') _delete(project);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'play', child: ListTile(dense: true, leading: Icon(Icons.play_arrow), title: Text('بازی کن'))),
                                  PopupMenuItem(value: 'edit', child: ListTile(dense: true, leading: Icon(Icons.edit), title: Text('ویرایش مرحله'))),
                                  PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_outline), title: Text('حذف'))),
                                ],
                              ),
                            )),
                          );
                        }, childCount: projects.length)),
                      ),
                  ],
                ),
        ),
      );
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.project});
  final GameProject project;
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late GameProject project;
  int selected = 1;
  bool saving = false;
  final List<List<int>> undoStack = [];
  final List<List<int>> redoStack = [];

  @override
  void initState() {
    super.initState();
    project = widget.project;
    if (project.cells.length != project.columns * project.rows) project.cells = List<int>.filled(project.columns * project.rows, 0);
  }

  List<int> get tools => switch (project.type) {
        GameType.maze => [0, 1, 2, 4, 5],
        GameType.platformer => [0, 1, 2, 3, 4, 5],
        GameType.driving => [0, 2, 3],
      };

  String toolLabel(int value) => switch (project.type) {
        GameType.maze => {0: 'پاک‌کن', 1: 'دیوار', 2: 'گوهر', 4: 'پایان', 5: 'شروع'}[value]!,
        GameType.platformer => {0: 'پاک‌کن', 1: 'سکو', 2: 'سکه', 3: 'دشمن', 4: 'پایان', 5: 'شروع'}[value]!,
        GameType.driving => {0: 'خالی', 2: 'جایزه', 3: 'مانع'}[value]!,
      };

  void _paintCell(int index, int value) {
    if (index < 0 || index >= project.cells.length) return;
    if (project.type == GameType.platformer && project.activeLayer > 0 && (value == 4 || value == 5)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نقطه شروع و پایان را در لایه اصلی قرار بده.')),
      );
      return;
    }
    final before = List<int>.from(project.type == GameType.platformer ? project.layers[project.activeLayer] : project.cells);
    var targetIndex = index;
    if (project.type == GameType.platformer && value == 5) {
      targetIndex = (project.rows - 2) * project.columns + index % project.columns;
    }
    final targetLayer = project.type == GameType.platformer ? project.layers[project.activeLayer] : project.cells;
    if ((project.type == GameType.maze || project.type == GameType.platformer) && (value == 4 || value == 5)) {
      for (var i = 0; i < targetLayer.length; i++) {
        if (targetLayer[i] == value) targetLayer[i] = 0;
      }
    }
    targetLayer[targetIndex] = project.type == GameType.platformer && value == 0 && project.activeLayer > 0 ? -1 : value;
    if (before.toString() == targetLayer.toString()) return;
    if (project.type == GameType.platformer) project.cells = project.composeLayers();
    project.syncActiveLevel();
    undoStack.add(before);
    if (undoStack.length > 80) undoStack.removeAt(0);
    redoStack.clear();
    setState(() {});
  }

  void _undo() {
    if (undoStack.isEmpty) return;
    redoStack.add(List<int>.from(project.type == GameType.platformer ? project.layers[project.activeLayer] : project.cells));
    setState(() {
      final restored = undoStack.removeLast();
      if (project.type == GameType.platformer) {
        project.layers[project.activeLayer] = restored;
        project.cells = project.composeLayers();
      } else {
        project.cells = restored;
      }
      project.syncActiveLevel();
    });
  }

  void _redo() {
    if (redoStack.isEmpty) return;
    undoStack.add(List<int>.from(project.type == GameType.platformer ? project.layers[project.activeLayer] : project.cells));
    setState(() {
      final restored = redoStack.removeLast();
      if (project.type == GameType.platformer) {
        project.layers[project.activeLayer] = restored;
        project.cells = project.composeLayers();
      } else {
        project.cells = restored;
      }
      project.syncActiveLevel();
    });
  }

  void _clearBoard() {
    undoStack.add(List<int>.from(project.type == GameType.platformer ? project.layers[project.activeLayer] : project.cells));
    redoStack.clear();
    setState(() {
      final cleared = List<int>.filled(project.columns * project.rows, project.type == GameType.platformer && project.activeLayer > 0 ? -1 : 0);
      if (project.type == GameType.platformer) {
        project.layers[project.activeLayer] = cleared;
        project.cells = project.composeLayers();
      } else {
        project.cells = cleared;
      }
      project.syncActiveLevel();
    });
  }

  void _selectLevel(int index) {
    if (index < 0 || index >= project.levels.length) return;
    setState(() {
      project.setActiveLevel(index);
      undoStack.clear();
      redoStack.clear();
    });
  }

  void _addLevel({bool duplicate = false}) {
    if (project.levels.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حداکثر ۲۰ مرحله برای هر بازی مجاز است.')));
      return;
    }
    project.syncActiveLevel();
    setState(() {
      project.addLevel(copyFrom: duplicate ? project.cells : null);
      undoStack.clear();
      redoStack.clear();
    });
  }

  void _deleteLevel() {
    if (project.levels.length <= 1) return;
    setState(() {
      project.removeActiveLevel();
      undoStack.clear();
      redoStack.clear();
    });
  }

  void _selectLayer(int index) {
    if (index < 0 || index >= project.layers.length) return;
    setState(() {
      project.activeLayer = index;
      project.cells = project.composeLayers();
      undoStack.clear();
      redoStack.clear();
    });
  }

  void _addLayer() {
    if (project.layers.length >= GameProject.layerNames.length) return;
    setState(() {
      project.addLayer();
      undoStack.clear();
      redoStack.clear();
    });
  }

  void _removeLayer() {
    if (project.layers.length <= 1) return;
    setState(() {
      project.removeActiveLayer();
      undoStack.clear();
      redoStack.clear();
    });
  }

  bool _mazeHasPath() {
    final start = project.cells.indexOf(5);
    final goal = project.cells.indexOf(4);
    if (start < 0 || goal < 0) return false;
    final visited = <int>{start};
    final queue = Queue<int>()..add(start);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current == goal) return true;
      final candidates = [
        current - project.columns,
        current + project.columns,
        current - 1,
        current + 1,
      ];
      for (final next in candidates) {
        if (next < 0 || next >= project.cells.length) continue;
        if ((next - current).abs() == 1 && next ~/ project.columns != current ~/ project.columns) continue;
        if (project.cells[next] == 1 || !visited.add(next)) continue;
        queue.add(next);
      }
    }
    return false;
  }

  void _preview() {
    if (project.type == GameType.maze && !_mazeHasPath()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مسیر شروع تا خروجی بسته است؛ دیوارها را طوری بچین که راه باز بماند.')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => GamePage(project: project.copy())));
  }

  Future<void> _save() async {
    project.syncActiveLevel();
    setState(() => saving = true);
    final all = await ProjectStore.load();
    final index = all.indexWhere((p) => p.id == project.id);
    if (index < 0) {
      all.insert(0, project.copy());
    } else {
      all[index] = project.copy();
    }
    await ProjectStore.save(all);
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مرحله با موفقیت ذخیره شد 💾')));
  }

  Widget _tool(int value) {
    final selectedNow = selected == value;
    Widget chip() => Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
      decoration: BoxDecoration(
        color: selectedNow ? const Color(0xFFE9E1FF) : const Color(0xFFF8F6FC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: selectedNow ? purple : Colors.black12, width: selectedNow ? 2 : 1),
      ),
      child: Column(children: [
        SizedBox(width: 38, height: 30, child: GameTileArt(type: project.type, value: value, character: project.character, isPlayer: value == 5 && project.type == GameType.maze)),
        const SizedBox(height: 3),
        Text(toolLabel(value), maxLines: 1, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
    return Draggable<int>(
      data: value,
      feedback: Material(color: Colors.transparent, child: Transform.scale(scale: 1.08, child: chip())),
      childWhenDragging: Opacity(opacity: .35, child: InkWell(onTap: () => setState(() => selected = value), child: chip())),
      child: InkWell(onTap: () => setState(() => selected = value), borderRadius: BorderRadius.circular(13), child: chip()),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(tooltip: 'پیش‌نمایش بازی', onPressed: _preview, icon: const Icon(Icons.play_circle_fill_rounded, color: purple)),
              IconButton(tooltip: 'ذخیره', onPressed: saving ? null : _save, icon: const Icon(Icons.save_rounded)),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
              children: [
                Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Row(children: [
                  Text(project.type.emoji, style: const TextStyle(fontSize: 29)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('طراحی مرحله ' + project.type.title, style: const TextStyle(fontWeight: FontWeight.w900)), const Text('ابزار را انتخاب کن و روی خانه‌های صفحه بزن.', style: TextStyle(fontSize: 11, color: Colors.black54))])),
                  Text(project.columns.toString() + ' × ' + project.rows.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: purple)),
                ])),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    IconButton(tooltip: 'مرحله قبلی', onPressed: project.activeLevel > 0 ? () => _selectLevel(project.activeLevel - 1) : null, icon: const Icon(Icons.chevron_right_rounded)),
                    Expanded(child: Text('مرحله ${project.activeLevel + 1} از ${project.levels.length}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: ink))),
                    IconButton(tooltip: 'مرحله بعدی', onPressed: project.activeLevel < project.levels.length - 1 ? () => _selectLevel(project.activeLevel + 1) : null, icon: const Icon(Icons.chevron_left_rounded)),
                    const VerticalDivider(width: 12),
                    IconButton(tooltip: 'تکثیر مرحله', onPressed: () => _addLevel(duplicate: true), icon: const Icon(Icons.copy_rounded)),
                    IconButton(tooltip: 'افزودن مرحله خالی', onPressed: () => _addLevel(), icon: const Icon(Icons.add_circle_rounded, color: purple)),
                    IconButton(tooltip: 'حذف مرحله', onPressed: project.levels.length > 1 ? _deleteLevel : null, icon: const Icon(Icons.delete_outline_rounded)),
                  ]),
                ),
                if (project.type == GameType.platformer) ...[
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Expanded(child: Text('لایه‌های طراحی', style: TextStyle(fontWeight: FontWeight.w900))),
                        IconButton(tooltip: 'افزودن لایه', onPressed: project.layers.length < GameProject.layerNames.length ? _addLayer : null, icon: const Icon(Icons.add_circle, color: purple)),
                        IconButton(tooltip: 'حذف آخرین لایه', onPressed: project.layers.length > 1 ? _removeLayer : null, icon: const Icon(Icons.delete_outline)),
                      ]),
                      Wrap(spacing: 6, runSpacing: 6, children: List.generate(project.layers.length, (i) => ChoiceChip(
                        label: Text(GameProject.layerNames[i]),
                        selected: project.activeLayer == i,
                        onSelected: (_) => _selectLayer(i),
                        selectedColor: const Color(0xFFE9E1FF),
                      ))),
                      const SizedBox(height: 4),
                      const Text('اشیا را در لایه مناسب قرار بده؛ لایه‌های بالاتر روی لایه‌های زیرین نمایش داده می‌شوند.', style: TextStyle(fontSize: 10, color: Colors.black54)),
                    ]),
                  ),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  const Spacer(),
                  IconButton.filledTonal(tooltip: 'واگرد', onPressed: undoStack.isEmpty ? null : _undo, icon: const Icon(Icons.undo_rounded)),
                  const SizedBox(width: 5),
                  IconButton.filledTonal(tooltip: 'انجام دوباره', onPressed: redoStack.isEmpty ? null : _redo, icon: const Icon(Icons.redo_rounded)),
                  const SizedBox(width: 5),
                  IconButton.filledTonal(tooltip: 'پاک کردن صفحه', onPressed: _clearBoard, icon: const Icon(Icons.delete_sweep_rounded)),
                ]),
                _buildBoard(),
                const SizedBox(height: 14),
                _sectionTitle('ابزارهای طراحی'),
                const SizedBox(height: 8),
                Wrap(spacing: 7, runSpacing: 7, children: tools.map(_tool).toList()),
                const SizedBox(height: 16),
                _sectionTitle('شخصیت بازی'),
                const SizedBox(height: 8),
                SizedBox(height: 58, child: ListView(scrollDirection: Axis.horizontal, children: List.generate(characterOptions.length, (i) => GestureDetector(
                  onTap: () => setState(() => project.character = i),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: 54, margin: const EdgeInsets.only(left: 8), decoration: BoxDecoration(color: project.character == i ? const Color(0xFFE9E1FF) : Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: project.character == i ? purple : Colors.black12, width: project.character == i ? 2 : 1)), alignment: Alignment.center, child: GameTileArt(type: GameType.maze, value: 0, character: i, isPlayer: true)),
                )))),
                const SizedBox(height: 15),
                _sectionTitle('پس‌زمینه کارتونی'),
                const SizedBox(height: 8),
                SizedBox(height: 82, child: ListView(scrollDirection: Axis.horizontal, children: List.generate(backgroundNames.length, (i) => GestureDetector(
                  onTap: () => setState(() => project.background = i),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 160), width: 122, margin: const EdgeInsets.only(left: 9), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(backgroundTop[i]), Color(backgroundBottom[i])]), borderRadius: BorderRadius.circular(16), border: Border.all(color: project.background == i ? purple : Colors.transparent, width: 3)), alignment: Alignment.center, child: Text(backgroundNames[i], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: ink))),
                )))),
                const SizedBox(height: 10),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: project.soundEnabled, onChanged: (v) => setState(() => project.soundEnabled = v), secondary: const Icon(Icons.volume_up_rounded, color: purple), title: const Text('صداهای بازی', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('صدای جمع‌آوری جایزه و برخورد')),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: project.musicEnabled, onChanged: (v) => setState(() => project.musicEnabled = v), secondary: const Icon(Icons.music_note_rounded, color: purple), title: const Text('موسیقی پس‌زمینه', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('موسیقی شاد ساخته‌شده برای بازی')),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: saving ? null : _save, icon: const Icon(Icons.save), label: Text(saving ? 'در حال ذخیره...' : 'ذخیره بازی')),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: _preview, icon: const Icon(Icons.sports_esports), label: const Text('اجرای بازی')),
              ],
            ),
          ),
        ),
      );

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ink));

  Widget _buildBoard() => Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFFFF), Color(0xFFF0EDFA)]), borderRadius: BorderRadius.circular(23), border: Border.all(color: const Color(0xFFE3DDF3), width: 1.2), boxShadow: [BoxShadow(color: purple.withOpacity(.13), blurRadius: 20, offset: const Offset(0, 8)), const BoxShadow(color: Color(0x0E332B4D), blurRadius: 3, offset: Offset(0, 2))]),
        child: AspectRatio(
          aspectRatio: project.columns / project.rows,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: project.cells.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: project.columns, crossAxisSpacing: 3, mainAxisSpacing: 3),
            itemBuilder: (context, index) => DragTarget<int>(
              onAcceptWithDetails: (details) => _paintCell(index, details.data),
              builder: (context, candidates, rejected) => GestureDetector(
                onTap: () => _paintCell(index, selected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: candidates.isNotEmpty ? [const Color(0xFFFFF0A8), const Color(0xFFFFCF58)] : [tileColor(project.type, project.cells[index]), tileColor(project.type, project.cells[index]).withOpacity(.82)]), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white.withOpacity(.72), width: .8), boxShadow: project.cells[index] == 0 ? const [] : [BoxShadow(color: Colors.black.withOpacity(.09), blurRadius: 3, offset: const Offset(0, 1))]),
                  alignment: Alignment.center,
                  child: GameTileArt(type: project.type, value: project.cells[index], character: project.character),
                ),
              ),
            ),
          ),
        ),
      );
}

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.project});
  final GameProject project;
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameProject project;
  late List<int> cells;
  final random = Random();
  Timer? ticker;
  int score = 0, moves = 0, lives = 3;
  bool paused = false, finished = false;
  int player = 0, playerX = 0, playerY = 0, jumpTicks = 0, lane = 1, roadTick = 0;
  final List<int> roadObjects = [];
  final List<int> roadCoins = [];

  @override
  void initState() {
    super.initState();
    project = widget.project;
    cells = List<int>.from(project.cells);
    GameAudio.instance.configure(sound: project.soundEnabled, music: project.musicEnabled);
    if (project.type == GameType.maze) {
      player = cells.indexOf(5);
      if (player < 0) player = 12;
    } else if (project.type == GameType.platformer) {
      final start = cells.indexOf(5);
      playerX = start >= 0 ? start % project.columns : 0;
      playerY = project.rows - 2;
    } else if (project.type == GameType.driving) {
      _resetRoadObjects();
      ticker = Timer.periodic(const Duration(milliseconds: 530), (_) => _driveTick());
    }
  }


  void _resetRoadObjects() {
    roadObjects.clear();
    roadCoins.clear();
    for (var i = 0; i < cells.length; i++) {
      final roadPosition = (i ~/ project.columns) * 3 + i % 3;
      if (cells[i] == 3) roadObjects.add(roadPosition);
      if (cells[i] == 2) roadCoins.add(roadPosition);
    }
    if (roadObjects.isEmpty) roadObjects.add(1);
  }

  @override
  void dispose() {
    ticker?.cancel();
    GameAudio.instance.configure(sound: project.soundEnabled, music: false);
    super.dispose();
  }

  void _moveMaze(int delta) {
    if (paused || finished) return;
    final next = player + delta;
    if (next < 0 || next >= cells.length) return;
    if ((delta == 1 || delta == -1) && next ~/ project.columns != player ~/ project.columns) return;
    if (cells[next] == 1) { GameAudio.instance.bump(); return; }
    final collected = cells[next] == 2;
    setState(() {
      player = next;
      moves++;
      if (collected) { cells[next] = 0; score++; }
    });
    if (collected) GameAudio.instance.collect();
    if (cells[next] == 4) _finish(true, 'از هزارتو بیرون آمدی و ' + score.toString() + ' گوهر جمع کردی!');
  }

  void _platformMove(int dx) {
    if (paused || finished) return;
    final nextX = (playerX + dx).clamp(0, project.columns - 1).toInt();
    final target = playerY * project.columns + nextX;
    if (cells[target] == 1) { GameAudio.instance.bump(); return; }
    setState(() { playerX = nextX; moves++; _checkPlatformCell(); });
  }

  void _jump() {
    if (paused || finished || jumpTicks > 0 || playerY < project.rows - 2) return;
    setState(() { jumpTicks = 3; playerY = max(0, playerY - 2); moves++; _checkPlatformCell(); });
    GameAudio.instance.effect(frequency: 520, durationMs: 90);
  }


  void _checkPlatformCell() {
    final index = playerY * project.columns + playerX;
    if (index < 0 || index >= cells.length) return;
    if (cells[index] == 2) {
      cells[index] = 0; score++; GameAudio.instance.collect();
    } else if (cells[index] == 3) {
      lives--; GameAudio.instance.bump(); playerX = 0;
      if (lives <= 0) _finish(false, 'این بار دشمن‌ها قوی‌تر بودند. دوباره تلاش کن!');
    } else if (cells[index] == 4 || playerX == project.columns - 1) {
      _finish(true, 'به خط پایان رسیدی! امتیاز تو: ' + score.toString());
    }
  }

  void _driveTick() {
    if (!mounted || paused || finished) return;
    setState(() {
      roadTick++;
      for (var i = 0; i < roadObjects.length; i++) { roadObjects[i] += 3; }
      for (var i = 0; i < roadCoins.length; i++) { roadCoins[i] += 3; }
      roadObjects.removeWhere((v) => v >= 24);
      roadCoins.removeWhere((v) => v >= 24);
      if (random.nextDouble() < .62) {
        final newLane = random.nextInt(3);
        final busy = roadObjects.any((v) => v < 3 && v % 3 == newLane);
        if (!busy) roadObjects.add(newLane);
      }
      final collision = roadObjects.any((v) => v >= 21 && v < 24 && v % 3 == lane);
      if (collision) {
        lives--;
        roadObjects.removeWhere((v) => v >= 21 && v < 24 && v % 3 == lane);
        GameAudio.instance.bump();
        if (lives <= 0) _finish(false, 'ماشینت سه بار به مانع خورد. امتیاز: ' + score.toString());
      } else {
        final collectedCoins = roadCoins.where((v) => v >= 21 && v < 24 && v % 3 == lane).length;
        roadCoins.removeWhere((v) => v >= 21 && v < 24 && v % 3 == lane);
        score += 1 + collectedCoins * 5;
        if (collectedCoins > 0 || roadTick % 4 == 0) GameAudio.instance.collect();
      }
    });
  }

  void _changeLane(int delta) {
    if (paused || finished) return;
    setState(() { lane = (lane + delta).clamp(0, 2).toInt(); moves++; });
  }


  void _finish(bool success, String message) {
    if (finished || !mounted) return;
    finished = true;
    ticker?.cancel();
    if (success) { GameAudio.instance.success(); } else { GameAudio.instance.bump(); }
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (d) => AlertDialog(
          title: Text(success ? 'آفرین، قهرمان! 🏆' : 'تلاش خوبی بود! 💪'),
          content: Text(message),
          actions: [
            TextButton(onPressed: () { Navigator.pop(d); Navigator.pop(context); }, child: const Text('بازگشت به ویرایشگر')),
            if (success && project.activeLevel < project.levels.length - 1)
              OutlinedButton(onPressed: () {
                Navigator.pop(d);
                project.setActiveLevel(project.activeLevel + 1);
                _restart();
              }, child: const Text('مرحله بعدی')),
            FilledButton(onPressed: () { Navigator.pop(d); _restart(); }, child: const Text('دوباره بازی کن')),
          ],
        ),
      );
    });
  }

  void _restart() {
    ticker?.cancel();
    setState(() {
      cells = List<int>.from(project.cells);
      score = 0; moves = 0; lives = 3; paused = false; finished = false;
      player = cells.indexOf(5); if (player < 0) player = 12;
      final platformStart = cells.indexOf(5);
      playerX = platformStart >= 0 ? platformStart % project.columns : 0;
      playerY = project.rows - 2; jumpTicks = 0; lane = 1; roadTick = 0;
      _resetRoadObjects();
    });
    if (project.type == GameType.driving) ticker = Timer.periodic(const Duration(milliseconds: 530), (_) => _driveTick());
  }

  @override
  Widget build(BuildContext context) {
    if (project.type == GameType.platformer) {
      return PlatformerGameScreen(project: project);
    }
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              IconButton(tooltip: paused ? 'ادامه' : 'مکث', onPressed: finished ? null : () => setState(() => paused = !paused), icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded)),
              IconButton(tooltip: 'شروع دوباره', onPressed: _restart, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: Stack(children: [
            GameBackdrop(background: project.background),
            SafeArea(child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 5, 12, 14),
              child: Column(children: [
                _scoreBar(),
                const SizedBox(height: 10),
                Expanded(child: _gameBoard()),
                const SizedBox(height: 10),
                if (paused)
                  FilledButton.icon(onPressed: () => setState(() => paused = false), icon: const Icon(Icons.play_arrow), label: const Text('ادامه بازی'))
                else
                  _controls(),
              ]),
            )),
            if (paused) Positioned.fill(child: Container(color: Colors.black38, alignment: Alignment.center, child: Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: const Text('⏸ بازی متوقف شده', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))))),
          ]),
        ),
      );
  }

  Widget _scoreBar() => Row(children: [
        _pill('⭐ ' + score.toString(), const Color(0xFFFFF0BD)),
        const SizedBox(width: 7),
        _pill('حرکت ' + moves.toString(), Colors.white),
        _pill('مرحله ${project.activeLevel + 1}/${project.levels.length}', const Color(0xFFE9E1FF)),
        const Spacer(),
        _pill('❤️ ' + lives.toString(), const Color(0xFFFFE0E6)),
      ]);

  Widget _pill(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: ink)));

  Widget _gameBoard() {
    switch (project.type) {
      case GameType.maze: return _mazeBoard();
      case GameType.platformer: return _platformBoard();
      case GameType.driving: return _drivingBoard();
    }
  }

  Widget _mazeBoard() => Center(child: AspectRatio(
    aspectRatio: 1,
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.85), borderRadius: BorderRadius.circular(20)),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cells.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: project.columns, crossAxisSpacing: 2, mainAxisSpacing: 2),
        itemBuilder: (context, i) {
          final isPlayer = i == player;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(color: cells[i] == 1 ? const Color(0xFF6D5A9E) : cells[i] == 4 ? const Color(0xFFFFD96B) : const Color(0xFFEAF5DF), borderRadius: BorderRadius.circular(4)),
            alignment: Alignment.center,
            child: GameTileArt(type: GameType.maze, value: cells[i], character: project.character, isPlayer: isPlayer),
          );
        },
      ),
    ),
  ));

  Widget _platformBoard() => Center(child: AspectRatio(
    aspectRatio: 1.2,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.85), borderRadius: BorderRadius.circular(20)),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cells.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: project.columns, crossAxisSpacing: 3, mainAxisSpacing: 3),
        itemBuilder: (context, i) {
          final row = i ~/ project.columns, col = i % project.columns;
          final isPlayer = row == playerY && col == playerX;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(color: cells[i] == 1 ? const Color(0xFF9B7A53) : const Color(0xFFDDF2FF), borderRadius: BorderRadius.circular(5)),
            alignment: Alignment.center,
            child: GameTileArt(type: GameType.platformer, value: cells[i], character: project.character, isPlayer: isPlayer),
          );
        },
      ),
    ),
  ));

  Widget _drivingBoard() => Center(child: AspectRatio(
    aspectRatio: .72,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFF44475A), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white, width: 4)),
      child: Column(children: List.generate(8, (row) => Expanded(child: Row(children: List.generate(3, (col) {
        final object = roadObjects.any((v) => v ~/ 3 == row && v % 3 == col);
        final coin = roadCoins.any((v) => v ~/ 3 == row && v % 3 == col);
        final car = row == 7 && col == lane;
        return Expanded(child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: col == 1 ? const Color(0xFF656879) : const Color(0xFF55596B), borderRadius: BorderRadius.circular(5)),
          alignment: Alignment.center,
          child: GameTileArt(type: GameType.driving, value: car ? 4 : object ? 3 : coin ? 2 : 0, character: project.character, isPlayer: car),
        ));
      }))))),
    ),
  ));


  Widget _controls() {
    switch (project.type) {
      case GameType.maze:
        return Column(children: [
          _controlButton(Icons.keyboard_arrow_up_rounded, () => _moveMaze(-project.columns)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _controlButton(Icons.keyboard_arrow_right_rounded, () => _moveMaze(-1)),
            const SizedBox(width: 14),
            _controlButton(Icons.keyboard_arrow_down_rounded, () => _moveMaze(project.columns)),
            const SizedBox(width: 14),
            _controlButton(Icons.keyboard_arrow_left_rounded, () => _moveMaze(1)),
          ]),
        ]);
      case GameType.platformer:
        return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _controlButton(Icons.arrow_back_rounded, () => _platformMove(-1)),
          FilledButton.icon(onPressed: _jump, icon: const Icon(Icons.arrow_upward), label: const Text('پرش'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16))),
          _controlButton(Icons.arrow_forward_rounded, () => _platformMove(1)),
        ]);
      case GameType.driving:
        return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _controlButton(Icons.arrow_back_rounded, () => _changeLane(-1)),
          FilledButton.icon(onPressed: () { if (!paused && !finished) setState(() { lane = 1; moves++; }); }, icon: const Icon(Icons.sports_score), label: const Text('مسیر وسط')),
          _controlButton(Icons.arrow_forward_rounded, () => _changeLane(1)),
        ]);
    }
  }

  Widget _controlButton(IconData icon, VoidCallback onPressed) => SizedBox(width: 58, height: 52, child: FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: purple), child: Icon(icon, size: 30)));
}

class GameBackdrop extends StatelessWidget {
  const GameBackdrop({super.key, required this.background});
  final int background;
  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: CustomPaint(painter: GameBackdropPainter(background)),
      );
}

Color tileColor(GameType type, int value) {
  if (value == 0) return const Color(0xFFF8F8FF);
  if (type == GameType.maze) return value == 1 ? const Color(0xFFB9A9E8) : value == 2 ? const Color(0xFFFFE9A9) : const Color(0xFFD7F2D6);
  if (type == GameType.platformer) return value == 1 ? const Color(0xFFC9A77D) : value == 2 ? const Color(0xFFFFE9A9) : value == 3 ? const Color(0xFFFFD8D8) : const Color(0xFFDDF2FF);
  if (type == GameType.driving) return value == 3 ? const Color(0xFFFFD8D8) : value == 2 ? const Color(0xFFFFE9A9) : const Color(0xFFE7E7EF);
  return const Color(0xFFE9E1FF);
}

String tileEmoji(GameType type, int value) {
  if (value == 0) return '▫️';
  if (type == GameType.maze) return {1: '🧱', 2: '💎', 4: '🚪', 5: '🏁'}[value] ?? '';
  if (type == GameType.platformer) return {1: '🟫', 2: '🪙', 3: '👾', 4: '🏆', 5: '🏁'}[value] ?? '';
  if (type == GameType.driving) return {2: '🪙', 3: '🚧'}[value] ?? '';
  return '';
}
