import 'package:flutter/material.dart';
import '../data/models.dart';

class AppearanceSettingsPage extends StatefulWidget {
  final ThemeMode mode;
  final Color? seed;
  final Future<void> Function(ThemeMode, Color?) onSetTheme;
  const AppearanceSettingsPage({super.key, required this.mode, required this.seed, required this.onSetTheme});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  late ThemeMode _mode;
  late Color? _seed;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _seed = widget.seed;
  }

  void _set(ThemeMode m, Color? s) {
    setState(() { _mode = m; _seed = s; });
    widget.onSetTheme(m, s);
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    final seed = _seed;
    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const Text('深浅模式', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: {
            ThemeMode.system: '跟随系统',
            ThemeMode.light: '浅色',
            ThemeMode.dark: '深色',
          }.entries.map((e) => ChoiceChip(
            label: Text(e.value),
            selected: mode == e.key,
            onSelected: (_) => _set(e.key, seed),
          )).toList()),
          const Divider(height: 24),
          const Text('动态色彩', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('跟随系统配色'),
            subtitle: const Text('使用系统 Material You 动态颜色'),
            value: seed == null,
            onChanged: (_) => _set(mode, null),
          ),
          const Divider(height: 24),
          const Text('色调', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: aospSeeds.entries.map((e) => _ColorSwatch(
            color: e.value,
            selected: seed == e.value,
            label: e.value == Colors.blueGrey ? '灰' : e.key,
            onTap: () => _set(mode, e.value),
          )).toList()),
          const Divider(height: 24),
          const Text('预览', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FilledButton(onPressed: () {}, child: const Text('主要按钮')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () {}, child: const Text('次要按钮')),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('开关'),
                  value: true,
                  onChanged: (_) {},
                ),
                const SizedBox(height: 8),
                Text('示例文本', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  const _ColorSwatch({required this.color, required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3) : null,
        ),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white))),
      ),
    );
  }
}