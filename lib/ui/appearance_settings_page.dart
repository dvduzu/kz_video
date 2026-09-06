import 'package:flutter/material.dart';
import '../data/models.dart';

class AppearanceSettingsPage extends StatefulWidget {
  final ThemeMode mode;
  final SeedTheme? theme;
  final bool useDynamic;
  final Future<void> Function(ThemeMode, SeedTheme?, {bool? dynamic}) onSetTheme;
  const AppearanceSettingsPage({super.key, required this.mode, required this.theme, required this.useDynamic, required this.onSetTheme});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  late ThemeMode _mode;
  late SeedTheme? _theme;
  late bool _useDynamic;
  late final PageController _pageCtrl;
  late final List<List<SeedTheme>> _pages;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _theme = widget.theme;
    _useDynamic = widget.useDynamic;
    _pages = aospThemes.map((t) => t.seed.toARGB32()).toSet().map((c) => aospThemes.where((t) => t.seed.toARGB32() == c).toList()).toList();
    final init = _theme == null ? 0 : _pages.indexWhere((ps) => ps.any((t) => t.key == _theme?.key));
    _pageCtrl = PageController(initialPage: init < 0 ? 0 : init);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _set(ThemeMode m, SeedTheme? s, [bool? dynamic]) {
    setState(() { _mode = m; _theme = s; if (dynamic != null) _useDynamic = dynamic; });
    widget.onSetTheme(m, s, dynamic: dynamic);
  }

  int _currentPage = 0;

  bool _page(int i) => _currentPage.round() == i;

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    final theme = _theme;
    final dynamicOn = _useDynamic;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const _PreviewCard(),
          const SizedBox(height: 16),
          const Text('颜色组合', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: _pages.map((ps) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ps.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _ColorSwatch(
                    theme: t,
                    selected: !dynamicOn && theme?.key == t.key,
                    onTap: () => _set(mode, t, false),
                  ),
                )).toList(),
              )).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Center(child: Text(dynamicOn ? '跟随壁纸 · 动态色' : _pages[_currentPage.clamp(0, _pages.length - 1)].first.key.split('·').first, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
          const SizedBox(height: 8),
          Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_pages.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _page(i) ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(color: _page(i) ? cs.primary : cs.outlineVariant, borderRadius: BorderRadius.circular(3)),
          )))),
          const Divider(height: 24),
          SwitchListTile(
            title: const Text('动态色彩'),
            subtitle: const Text('将壁纸颜色应用于应用主题'),
            value: dynamicOn,
            onChanged: (v) => _set(mode, theme ?? aospThemes.first, v),
          ),
          SwitchListTile(
            title: const Text('深色模式'),
            subtitle: Text(mode == ThemeMode.dark ? '开启' : (mode == ThemeMode.light ? '关闭' : '跟随系统')),
            value: mode == ThemeMode.dark,
            onChanged: (v) => _set(v ? ThemeMode.dark : ThemeMode.light, theme),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: {
            ThemeMode.system: '跟随系统',
            ThemeMode.light: '浅色',
            ThemeMode.dark: '深色',
          }.entries.map((e) => ChoiceChip(
            label: Text(e.value),
            selected: mode == e.key,
            onSelected: (_) => _set(e.key, theme),
          )).toList()),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 128,
                height: 76,
                color: scheme.primaryContainer,
                child: Icon(Icons.play_circle_fill, size: 32, color: scheme.primary),
              ),
            ),
            Expanded(child: Padding(padding: const EdgeInsets.only(left: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('视频标题预览', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurface)),
              const SizedBox(height: 4),
              Text('视频作者', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              Text('9月6日 · 05:59 · 10.2万 播放', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ]))),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final SeedTheme theme;
  final bool selected;
  final VoidCallback onTap;
  const _ColorSwatch({required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final trio = theme.trio;
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: theme.key,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: selected ? Border.all(color: cs.primary, width: 3) : null,
          ),
          child: ClipOval(
            child: CustomPaint(
              size: const Size(60, 60),
              painter: _ColorWheelPainter(colors: trio),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final List<Color> colors;
  _ColorWheelPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(rect, -3.14159, 3.14159, true, Paint()..color = colors[0]);
    canvas.drawArc(rect, 0, 1.5708, true, Paint()..color = colors[1]);
    canvas.drawArc(rect, 1.5708, 1.5708, true, Paint()..color = colors[2]);
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) => oldDelegate.colors != colors;
}