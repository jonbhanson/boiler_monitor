import 'dart:io';

import 'package:boiler_monitor/controller.dart';
import 'package:boiler_monitor/current_temp.dart';
import 'package:change_notifier_builder/change_notifier_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart';

import 'chart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS) {
    await windowManager.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    double? x = prefs.getDouble("x");
    double? y = prefs.getDouble("y");
    double? width = prefs.getDouble("width");
    double? height = prefs.getDouble("height");
    if (x != null && y != null && width != null && height != null) {
      setWindowFrame(Rect.fromCenter(center: Offset(x, y), width: width, height: height));
    }
  }
  runApp(const BoilerMonitor());
}

late Controller controller;

class BoilerMonitor extends StatefulWidget {
  const BoilerMonitor({Key? key}) : super(key: key);

  @override
  State<BoilerMonitor> createState() => _BoilerMonitorState();
}

class _BoilerMonitorState extends State<BoilerMonitor> with WindowListener {
  late Controller controller;
  @override
  void initState() {
    super.initState();
    controller = Controller();
    if (Platform.isMacOS) windowManager.addListener(this);
    // Rebuild on resume:
    WidgetsBinding.instance.addObserver(
      LifecycleEventHandler(
        resumeCallBack: () => controller.reSubscribeListeners(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boiler Monitor',
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode: Platform.isMacOS ? ThemeMode.dark : ThemeMode.system,
      home: Scaffold(
        body: SafeArea(
          child: ChangeNotifierBuilder(
            notifier: controller,
            builder: (context, controller, _) => buildScreen(context),
          ),
        ),
      ),
    );
  }

  Widget buildScreen(BuildContext context) {
    List<Widget> children = [
      CurrentTemp(controller: controller),
      Expanded(child: Chart(controller: controller)),
    ];
    if (MediaQuery.of(context).orientation == Orientation.landscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      );
    }
    return Column(children: children);
  }

  @override
  void onWindowFocus() => controller.reSubscribeListeners();

  @override
  Future<void> dispose() async {
    controller.dispose();
    if (Platform.isMacOS) {
      windowManager.removeListener(this);
      Rect frame = (await getWindowInfo()).frame;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble("x", frame.center.dx);
      prefs.setDouble("y", frame.center.dx);
      prefs.setDouble("width", frame.width);
      prefs.setDouble("height", frame.height);
    }
    super.dispose();
  }
}

class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback? resumeCallBack;
  final AsyncCallback? suspendingCallBack;

  LifecycleEventHandler({this.resumeCallBack, this.suspendingCallBack});

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        resumeCallBack?.call();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        suspendingCallBack?.call();
        break;
    }
  }
}
