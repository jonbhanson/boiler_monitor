import 'dart:async';
import 'dart:io';

import 'package:boiler_monitor/data_point.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Controller extends ChangeNotifier {
  DateTime? _lastTended;
  DateTime? get lastTended => _lastTended;
  List<DataPoint> temps = [];
  List<StatePoint> states = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _realtimeStateSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _stateStreamSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _temperatureStreamSubscription;
  Timer? _timer;
  bool? _isEngaged;
  bool? _isInError;
  bool? _isFuelOut;
  bool? get isEngaged => _isEngaged;
  bool? get isInError => _isInError;
  bool? get isFuelOut => _isFuelOut;
  late FirebaseFirestore _db;
  late FirebaseMessaging _messaging;
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  Controller() {
    _initialize();
  }

  int? get currentTemp => (temps.isNotEmpty) ? temps.last.temperature : null;

  String get displayText {
    if (_isInError ?? false) return "Error";
    if (_isFuelOut ?? false) return "Fuel";
    if (currentTemp == null) return "";
    return "$currentTemp°F";
  }

  Color get engagedIndicatorColor {
    if (_isEngaged == null) return Colors.transparent;
    if ((_isFuelOut ?? false) || (_isInError ?? false)) return Colors.red;
    return _isEngaged! ? Colors.green : Colors.red;
  }

  Future<void> _initialize() async {
    await Firebase.initializeApp();
    _db = FirebaseFirestore.instance;
    _db.settings = const Settings(persistenceEnabled: false);
    _messaging = FirebaseMessaging.instance;

    _messaging.onTokenRefresh.listen((token) {
      _db.doc("/settings/tokens").set({DateTime.now().toIso8601String(): token}, SetOptions(merge: true));
    });

    if (Platform.isAndroid) {
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestPermission();
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings("@mipmap/ic_launcher");
      const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {},
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
    }
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(title: message.notification?.title, body: message.notification?.body);
    });
    FirebaseMessaging.onBackgroundMessage(notificationTapBackground);
    _subscribeListeners();
    _timer = Timer.periodic(const Duration(minutes: 1), (Timer t) => _mockCurrentData());
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelListeners();
    super.dispose();
  }

  Future<void> reSubscribeListeners() async {
    await _cancelListeners();
    _subscribeListeners();
    notifyListeners();
  }

  Future<void> _cancelListeners() async {
    await _temperatureStreamSubscription?.cancel();
    await _realtimeStateSubscription?.cancel();
    await _stateStreamSubscription?.cancel();
  }

  void _subscribeListeners() {
    DateTime yesterdayDateTime = DateTime.now().subtract(const Duration(hours: 12)).copyWith(hour: 0, minute: 0, second: 0, microsecond: 0, millisecond: 0);
    Timestamp yesterday = Timestamp.fromDate(yesterdayDateTime);
    _temperatureStreamSubscription = _db.collection('days').where("date", isGreaterThanOrEqualTo: yesterday).snapshots().listen(_processTemperatureData);
    _realtimeStateSubscription = _db.doc('settings/state').snapshots().listen(_processRealtimeState);
    _stateStreamSubscription = _db.collection('state').where("date", isGreaterThanOrEqualTo: yesterday).snapshots().listen(_processStateData);
  }

  void _processRealtimeState(event) {
    var state = event.data();
    if (state is Map) {
      _isEngaged = state["engaged"];
      _isInError = state["error"];
      _isFuelOut = state["fuel"];
      var lastTended = state["lastTendedAt"];
      if (lastTended is Timestamp) _lastTended = lastTended.toDate();
    }
    notifyListeners();
  }

  void _processTemperatureData(event) {
    DateTime startTime = DateTime.now().subtract(const Duration(hours: 14));
    for (var doc in event.docs) {
      doc.data().forEach((key, value) {
        DateTime? dateTime = DateTime.tryParse("${doc.id}T$key");
        if (dateTime != null) {
          DateTime localDateTime = dateTime.toLocal();
          if ((value is int || value == null) && localDateTime.isAfter(startTime)) temps.add(DataPoint(dateTime: localDateTime, temperature: value));
        }
      });
    }
    temps.sort();
    _mockCurrentData();
  }

  void _processStateData(event) {
    DateTime twelveHoursAgo = DateTime.now().subtract(const Duration(hours: 12));
    for (var doc in event.docs) {
      doc.data().forEach((key, value) {
        DateTime? dateTime = DateTime.tryParse("${doc.id}T$key");
        if (dateTime != null) {
          DateTime localDateTime = dateTime.toLocal();
          if (value is String && localDateTime.isAfter(twelveHoursAgo)) states.add(StatePoint(dateTime: localDateTime, type: value));
        }
      });
    }
    states.sort();
    notifyListeners();
  }

  // Since the last data point from the controller may be some time ago if the temperature is not changing,
  // mock a datapoint for the current time.
  _mockCurrentData() {
    DateTime now = DateTime.now();
    temps.removeWhere((dataPoint) => dataPoint.isTemporary ?? false);
    if (now.difference(temps.last.dateTime) < const Duration(minutes: 1)) return;
    temps.add(temps.last.copyWith(dateTime: now, isTemporary: true));
    notifyListeners();
  }

  Future<void> _showNotification({required String? title, required String? body}) async {
    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails('your channel id', 'your channel name',
        channelDescription: 'your channel description', importance: Importance.max, priority: Priority.high, ticker: 'ticker');
    const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);
    await _flutterLocalNotificationsPlugin.show(0, title, body, notificationDetails);
  }
}

@pragma('vm:entry-point')
Future<void> notificationTapBackground(var message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();

  //print("Handling a background message: ${message.messageId}");
}

extension MyDateUtils on DateTime {
  DateTime copyWith({
    int? year,
    int? month,
    int? day,
    int? hour,
    int? minute,
    int? second,
    int? millisecond,
    int? microsecond,
  }) {
    return DateTime(
      year ?? this.year,
      month ?? this.month,
      day ?? this.day,
      hour ?? this.hour,
      minute ?? this.minute,
      second ?? this.second,
      millisecond ?? this.millisecond,
      microsecond ?? this.microsecond,
    );
  }
}
