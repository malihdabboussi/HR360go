import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../config/env.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/session_store.dart';
import '../domain/attendance_control.dart';
import '../domain/shift_watch.dart';

/// Notification ids / payloads.
const _reminderNotificationId = 7001;
const _exitNotificationId = 7002;
const shiftWatchReminderPayload = 'shift_watch.checkout_reminder';

const _ctxKey = 'shift_watch_ctx';
const _disclosureKey = 'shift_watch_disclosure';
const _pendingKey = 'shift_watch_pending';

const _channel = AndroidNotificationDetails(
  'shift_watch',
  'Attendance reminders',
  channelDescription: 'Check-out reminders and automatic check-out alerts',
  importance: Importance.high,
  priority: Priority.high,
);
const _details = NotificationDetails(
  android: _channel,
  iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
);

final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

/// Tapped notification payloads; the attendance screen consumes them.
final ValueNotifier<String?> shiftWatchTapNotifier = ValueNotifier<String?>(null);

/// What the attendance screen shows about shift watch.
enum ShiftWatchStatus {
  /// Feature off, not checked in, or nothing to watch.
  idle,

  /// Watching the locations and/or a reminder is scheduled.
  active,

  /// Company wants auto check-out; the employee has not seen the background
  /// location explanation yet (Google Play: prominent disclosure before asking).
  needsDisclosure,

  /// Company wants auto check-out but location is not allowed "All the time".
  needsAlwaysLocation,
}

/// Prominent disclosure shown before asking for background location (Play policy).
const shiftWatchDisclosureTitle = 'Use your location in the background?';
const shiftWatchDisclosureText =
    'HR360 Go collects location data to check you out automatically when you leave '
    'your work location, even when the app is closed or not in use. This only happens '
    'while you are checked in and your company has turned on automatic check-out. '
    'Location monitoring stops when you check out and is not used for anything else.\n\n'
    'On the next screen, choose "Allow all the time".';

bool _notificationsReady = false;

/// Call once at startup (main). Safe to call again.
Future<void> initShiftWatchNotifications() async {
  if (_notificationsReady || kIsWeb) return;
  try {
    tz_data.initializeTimeZones();
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        shiftWatchTapNotifier.value = response.payload;
      },
    );
    final launch = await _notifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      shiftWatchTapNotifier.value = launch!.notificationResponse?.payload;
    }
    _notificationsReady = true;
  } catch (e) {
    debugPrint('[shift-watch] notifications unavailable: $e');
  }
}

Future<void> _requestNotificationPermission() async {
  try {
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  } catch (_) {}
}

/// Keeps the phone's geofences and reminder in line with the open shift.
class ShiftWatchService {
  ShiftWatchService({SessionStore? sessionStore, FlutterSecureStorage? storage})
      : _sessionStore = sessionStore ?? SessionStore(),
        _storage = storage ?? const FlutterSecureStorage();

  final SessionStore _sessionStore;
  final FlutterSecureStorage _storage;

  String? _lastGeofenceSignature;
  bool _askedNotificationPermission = false;
  bool _askedAlwaysLocation = false;
  bool _disclosureDeclined = false;

  /// Called after each attendance status refresh (startup, punches, pull-to-refresh).
  Future<ShiftWatchStatus> sync({
    required bool isOpen,
    required AttendanceControlConfig config,
    required String timeZone,
  }) async {
    if (kIsWeb) return ShiftWatchStatus.idle;
    final watch = config.shiftWatch;
    await flushPendingEvents();

    if (isOpen && watch.enabled && !_askedNotificationPermission) {
      _askedNotificationPermission = true;
      await _requestNotificationPermission();
    }

    final reminderAt = nextReminderTime(watch, isOpen: isOpen, now: DateTime.now());
    if (reminderAt != null) {
      await _scheduleReminder(reminderAt, watch.shiftEndAt);
    } else {
      await cancelReminder();
    }

    var status = reminderAt != null ? ShiftWatchStatus.active : ShiftWatchStatus.idle;
    if (shouldWatchGeofences(watch, isOpen: isOpen, fenceCount: config.geofences.length)) {
      if (!await _hasAlwaysLocation()) {
        // Never ask for background location before the employee read why (Play policy).
        final accepted = await _storage.read(key: _disclosureKey) == 'accepted';
        if (!accepted) {
          await _stopGeofences();
          return _disclosureDeclined
              ? ShiftWatchStatus.needsAlwaysLocation
              : ShiftWatchStatus.needsDisclosure;
        }
      }
      final allowed = await _ensureAlwaysLocation();
      if (!allowed) {
        await _stopGeofences();
        return ShiftWatchStatus.needsAlwaysLocation;
      }
      await _saveContext(config, timeZone);
      await _watchGeofences(config.geofences);
      status = ShiftWatchStatus.active;
    } else {
      await _stopGeofences();
    }
    return status;
  }

  /// Logout / checked out elsewhere: stop everything on this phone.
  Future<void> stopAll() async {
    await cancelReminder();
    await _stopGeofences();
    await _storage.delete(key: _ctxKey);
    await _storage.delete(key: _pendingKey);
  }

  Future<void> cancelReminder() async {
    if (!_notificationsReady) return;
    try {
      await _notifications.cancel(id: _reminderNotificationId);
    } catch (_) {}
  }

  /// "Still working": ask again later.
  Future<void> snoozeReminder(DateTime? shiftEndAt) =>
      _scheduleReminder(snoozeReminderTime(DateTime.now()), shiftEndAt);

  Future<void> _scheduleReminder(DateTime at, DateTime? shiftEndAt) async {
    if (!_notificationsReady) return;
    final ended = shiftEndAt == null ? '' : ' Your shift ended at ${_hhmm(shiftEndAt)}.';
    try {
      await _notifications.zonedSchedule(
        id: _reminderNotificationId,
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Did you forget to check out?',
        body: 'You are still checked in.$ended Tap to check out.',
        payload: shiftWatchReminderPayload,
      );
    } catch (e) {
      debugPrint('[shift-watch] reminder not scheduled: $e');
    }
  }

  Future<bool> _hasAlwaysLocation() async {
    try {
      return await Geolocator.checkPermission() == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Employee accepted the disclosure: the next [sync] asks for "All the time".
  Future<void> acceptDisclosure() async {
    _disclosureDeclined = false;
    _askedAlwaysLocation = false;
    await _storage.write(key: _disclosureKey, value: 'accepted');
  }

  /// Employee declined: do not ask again in this app run (a banner explains).
  void declineDisclosure() => _disclosureDeclined = true;

  /// Asks for "Allow all the time" once per app run; true when granted.
  Future<bool> _ensureAlwaysLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always) return true;
      if (_askedAlwaysLocation) return false;
      _askedAlwaysLocation = true;
      // Denied → this asks for "while in use" first; while in use → asks for background.
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system settings so the employee can pick "All the time".
  Future<void> openLocationSettings() async {
    _askedAlwaysLocation = false;
    await Geolocator.openAppSettings();
  }

  Future<void> _saveContext(AttendanceControlConfig config, String timeZone) async {
    await _storage.write(
      key: _ctxKey,
      value: jsonEncode({
        'api_base': Env.apiBaseUrl,
        'time_zone': timeZone,
        'grace_minutes': config.shiftWatch.exitGraceMinutes,
        'names': {for (final g in config.geofences) g.id: g.name},
      }),
    );
  }

  Future<void> _watchGeofences(List<AttendanceGeofence> fences) async {
    final signature = fences
        .map((f) => '${f.id}:${f.latitude}:${f.longitude}:${f.radiusM}')
        .join('|');
    if (signature == _lastGeofenceSignature) return;
    try {
      await NativeGeofenceManager.instance.initialize();
      await _removeOurGeofences();
      // iOS monitors at most 20 regions per app.
      for (final fence in fences.take(20)) {
        await NativeGeofenceManager.instance.createGeofence(
          Geofence(
            id: shiftWatchGeofenceId(fence.id),
            location: Location(latitude: fence.latitude, longitude: fence.longitude),
            radiusMeters: fence.radiusM,
            triggers: const {GeofenceEvent.enter, GeofenceEvent.exit},
            // No event for where the phone already is: only real exits/entries count.
            iosSettings: const IosGeofenceSettings(initialTrigger: false),
            androidSettings: const AndroidGeofenceSettings(
              initialTriggers: {},
              notificationResponsiveness: Duration(minutes: 1),
            ),
          ),
          shiftWatchGeofenceCallback,
        );
      }
      _lastGeofenceSignature = signature;
    } catch (e) {
      debugPrint('[shift-watch] geofences not registered: $e');
      _lastGeofenceSignature = null;
    }
  }

  Future<void> _stopGeofences() async {
    if (_lastGeofenceSignature == null && !await _hasOurGeofences()) return;
    await _removeOurGeofences();
    _lastGeofenceSignature = null;
  }

  Future<bool> _hasOurGeofences() async {
    try {
      await NativeGeofenceManager.instance.initialize();
      final ids = await NativeGeofenceManager.instance.getRegisteredGeofenceIds();
      return ids.any((id) => fenceIdFromShiftWatchId(id) != null);
    } catch (_) {
      return false;
    }
  }

  Future<void> _removeOurGeofences() async {
    try {
      await NativeGeofenceManager.instance.initialize();
      final ids = await NativeGeofenceManager.instance.getRegisteredGeofenceIds();
      for (final id in ids) {
        if (fenceIdFromShiftWatchId(id) != null) {
          await NativeGeofenceManager.instance.removeGeofenceById(id);
        }
      }
    } catch (_) {}
  }

  /// Sends exit/enter events the background handler could not deliver (offline).
  Future<void> flushPendingEvents() async {
    final raw = await _storage.read(key: _pendingKey);
    if (raw == null || raw.isEmpty) return;
    List<dynamic> events;
    try {
      events = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      await _storage.delete(key: _pendingKey);
      return;
    }
    final left = <dynamic>[];
    for (final e in events) {
      if (e is! Map) continue;
      final ok = await _postEvent(
        _sessionStore,
        apiBase: Env.apiBaseUrl,
        path: '${e['path']}',
        body: Map<String, dynamic>.from(e['body'] as Map),
      );
      if (ok == null) left.add(e);
    }
    if (left.isEmpty) {
      await _storage.delete(key: _pendingKey);
    } else {
      await _storage.write(key: _pendingKey, value: jsonEncode(left));
    }
  }

  /// "Check me out at my scheduled end" from the reminder sheet.
  Future<Map<String, dynamic>> closeAtScheduleEnd({
    required Dio dio,
    required String timeZone,
    String? attendanceId,
  }) async {
    final res = await dio.post<dynamic>(
      ApiEndpoints.closeOpenShift,
      data: {
        'timeZone': timeZone,
        if (attendanceId != null) 'attendance_id': attendanceId,
      },
    );
    await cancelReminder();
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  }
}

String _hhmm(DateTime utc) {
  final l = utc.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// POST with the saved token. Returns the response map, or null when it should
/// be retried later (offline / server error). 4xx answers are final.
Future<Map<String, dynamic>?> _postEvent(
  SessionStore sessionStore, {
  required String apiBase,
  required String path,
  required Map<String, dynamic> body,
}) async {
  final token = await sessionStore.getAccessToken();
  if (token == null || token.isEmpty || apiBase.isEmpty) return const {};
  try {
    final res = await Dio(
      BaseOptions(
        baseUrl: apiBase,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      ),
    ).post<dynamic>(path, data: body);
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : const {};
  } on DioException catch (e) {
    final code = e.response?.statusCode ?? 0;
    if (code >= 400 && code < 500) return {'error': code};
    return null;
  }
}

Future<void> _queueEvent(FlutterSecureStorage storage, String path, Map<String, dynamic> body) async {
  List<dynamic> events = [];
  try {
    final raw = await storage.read(key: _pendingKey);
    if (raw != null && raw.isNotEmpty) events = jsonDecode(raw) as List<dynamic>;
  } catch (_) {}
  events.add({'path': path, 'body': body});
  // Only the latest few matter (an exit then a re-entry).
  if (events.length > 10) events = events.sublist(events.length - 10);
  await storage.write(key: _pendingKey, value: jsonEncode(events));
}

/// Runs in a background isolate when the OS reports leaving / entering one of the
/// employee's locations, also when the app is closed. Notifies the employee and
/// tells the Server; the Server decides (grace period, still inside another location).
@pragma('vm:entry-point')
Future<void> shiftWatchGeofenceCallback(GeofenceCallbackParams params) async {
  const storage = FlutterSecureStorage();
  final sessionStore = SessionStore();
  try {
    await initShiftWatchNotifications();
    final rawCtx = await storage.read(key: _ctxKey);
    if (rawCtx == null) return; // Not watching any more (checked out / logged out).
    final ctx = jsonDecode(rawCtx) as Map<String, dynamic>;
    final apiBase = '${ctx['api_base'] ?? ''}';
    final timeZone = '${ctx['time_zone'] ?? ''}';
    final grace = (ctx['grace_minutes'] as num?)?.round() ?? 10;
    final names = Map<String, dynamic>.from((ctx['names'] as Map?) ?? const {});

    final fenceIds = params.geofences
        .map((g) => fenceIdFromShiftWatchId(g.id))
        .whereType<String>()
        .toList();
    if (fenceIds.isEmpty) return;
    final fenceId = fenceIds.first;
    final place = '${names[fenceId] ?? ''}';
    final location = params.location;
    final now = DateTime.now().toUtc().toIso8601String();

    if (params.event == GeofenceEvent.exit) {
      final body = <String, dynamic>{
        'exit_time': now,
        'geofence_id': fenceId,
        'timeZone': timeZone,
        if (location != null) 'latitude': location.latitude,
        if (location != null) 'longitude': location.longitude,
      };
      final res = await _postEvent(sessionStore, apiBase: apiBase, path: ApiEndpoints.geofenceExit, body: body);
      if (res == null) await _queueEvent(storage, ApiEndpoints.geofenceExit, body);
      // Server ignores the exit when still inside another location or nothing is open.
      final accepted = res == null || res['accepted'] == true;
      if (accepted) {
        await _notifications.show(
          id: _exitNotificationId,
          title: 'You left your work location',
          body: exitNotificationBody(place, grace),
          notificationDetails: _details,
        );
      }
    } else if (params.event == GeofenceEvent.enter) {
      final body = <String, dynamic>{'timeZone': timeZone, 'geofence_id': fenceId};
      final res = await _postEvent(sessionStore, apiBase: apiBase, path: ApiEndpoints.geofenceEnter, body: body);
      if (res == null) await _queueEvent(storage, ApiEndpoints.geofenceEnter, body);
      if (res?['cleared'] == true) {
        await _notifications.show(
          id: _exitNotificationId,
          title: 'Welcome back',
          body: 'Automatic check-out cancelled. You are still checked in.',
          notificationDetails: _details,
        );
      }
    }
  } catch (e) {
    debugPrint('[shift-watch] background event failed: $e');
  }
}
