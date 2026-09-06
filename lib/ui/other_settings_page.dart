import 'package:flutter/material.dart';
import '../data/video_repository.dart';

class OtherSettingsPage extends StatefulWidget {
  final VideoRepository repo;
  const OtherSettingsPage({super.key, required this.repo});

  @override
  State<OtherSettingsPage> createState() => _OtherSettingsPageState();
}

class _OtherSettingsPageState extends State<OtherSettingsPage> {
  late bool _cardOutline;
  late String _cardTone;

  static const _tones = {
    'low': ('surfaceContainerLow', '低'),
    'medium': ('surfaceContainer', '中'),
    'high': ('surfaceContainerHigh', '高'),
    'highest': ('surfaceContainerHighest', '最高'),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final s = widget.repo.settings;
    _cardOutline = s.cardOutline;
    _cardTone = s.cardTone;
  }

  Future<void> _save() async {
    final s = widget.repo.settings;
    await s.setCardOutline(_cardOutline);
    await s.setCardTone(_cardTone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('其他')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const Text('外观细节', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('视频卡片描边'),
            subtitle: const Text('给视频卡片加细边框，提升低对比度主题下的辨识度'),
            value: _cardOutline,
            onChanged: (v) => setState(() => _cardOutline = v),
          ),
          const Divider(height: 24),
          const Text('视频卡片底色', style: TextStyle(fontWeight: FontWeight.bold)),
          RadioGroup<String>(
            groupValue: _cardTone,
            onChanged: (v) => setState(() => _cardTone = v ?? 'high'),
            child: Column(children: _tones.entries.map((e) => RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: Text('${e.value.$1} (${e.value.$2})'),
              value: e.key,
            )).toList()),
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: () async {
              await _save();
              if (mounted) Navigator.pop(context, false);
            },
            child: const Text('保存'),
          ),
        ),
      ),
    );
  }
}
