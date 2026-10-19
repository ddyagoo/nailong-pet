import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pet/pet_brain.dart';
import 'screens/android_home.dart';
import 'screens/home_scene.dart';
import 'services/audio_service.dart';
import 'services/holiday_sync.dart';
import 'services/settings_service.dart';
import 'services/todo_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsService();
  await settings.load();
  final todos = TodoStore();
  await todos.load();
  final audio = AudioService();
  await audio.init();
  await audio.setVolume(settings.volume);
  // 读本地缓存的节假日覆盖表；过期的会在后台自己刷（不阻塞启动）
  await HolidaySync.init();

  runApp(NailongApp(settings: settings, todos: todos, audio: audio));
}

class NailongApp extends StatefulWidget {
  const NailongApp({
    super.key,
    required this.settings,
    required this.todos,
    required this.audio,
  });

  final SettingsService settings;
  final TodoStore todos;
  final AudioService audio;

  @override
  State<NailongApp> createState() => _NailongAppState();
}

class _NailongAppState extends State<NailongApp> {
  late final PetBrain _brain;

  @override
  void initState() {
    super.initState();
    _brain = PetBrain(
      settings: widget.settings,
      // ?fast=1 用来快速验收「三次之后笑到躺下」
      fastIdle: kIsWeb && Uri.base.queryParameters['fast'] == '1',
    );
    widget.settings.addListener(_syncSettings);
  }

  void _syncSettings() {
    widget.audio.setVolume(widget.settings.volume);
    _brain.onSettingsChanged();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_syncSettings);
    _brain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return MaterialApp(
      title: '奶龙桌宠',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: isAndroid
          ? AndroidHome(settings: widget.settings, todos: widget.todos)
          : HomeScene(
              brain: _brain,
              settings: widget.settings,
              audio: widget.audio,
              todos: widget.todos,
            ),
    );
  }
}
