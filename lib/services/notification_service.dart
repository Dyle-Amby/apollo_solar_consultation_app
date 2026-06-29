// lib/services/notification_service.dart
//
// TIER 1 in-app notifications: computes "what's waiting for me" straight from
// the bookings list — no push, no backend, no new tables. Tracks which tickets
// the user has already seen (shared_preferences) so the bell can show a NEW
// count, not just a total.
//
// This is the single seam for later tiers:
//   • Tier 2 — swap the source in queueFrom(...) for a server "Notifications"
//     table written by the update workflow (accurate unread + history).
//   • Tier 3 — add FCM (Android) / APNs (iOS) push that wakes the app; the
//     inbox UI and this service's API stay the same.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:apollo_solar_consultation_app/services/session.dart';
import 'package:apollo_solar_consultation_app/services/ticket_pipeline.dart';

/// One actionable ticket sitting in the current user's queue.
class QueueItem {
  final Map<String, dynamic> booking;
  final TicketStep step;
  QueueItem(this.booking, this.step);

  String get ref => '${booking['ref'] ?? ''}';
  String get client => '${booking['client'] ?? ''}';
  String get agent => '${booking['agent'] ?? ''}';
}

class NotificationService {
  /// Tickets whose current (not-done, not-closed) step is owned by my role.
  /// Same rule the dashboard's "Awaiting You" uses, so the two always agree.
  static List<QueueItem> queueFrom(List<Map<String, dynamic>> items) {
    final myRole = Session.role;
    final out = <QueueItem>[];
    if (myRole.isEmpty) return out;
    for (final b in items) {
      if (ticketIsClosed(b['events'])) continue;
      final step = ticketCurrentStep(b['events']);
      if (step != null && step.owner == myRole) {
        out.add(QueueItem(b, step));
      }
    }
    return out;
  }

  // Seen-state is per signed-in user.
  static String _seenKey() => 'notif_seen_${Session.email}';

  static Future<Set<String>> _seen() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(_seenKey()) ?? const <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Refs in [queue] the user hasn't seen yet (call BEFORE [markAllSeen]).
  static Future<Set<String>> newRefs(List<QueueItem> queue) async {
    if (queue.isEmpty) return <String>{};
    final seen = await _seen();
    return queue.where((q) => !seen.contains(q.ref)).map((q) => q.ref).toSet();
  }

  /// How many queue items are NEW since the user last opened the inbox.
  static Future<int> newCount(List<QueueItem> queue) async =>
      (await newRefs(queue)).length;

  /// Call when the inbox is opened — everything currently queued is now "seen".
  static Future<void> markAllSeen(List<QueueItem> queue) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_seenKey(), queue.map((q) => q.ref).toSet().toList());
    } catch (_) {}
  }
}