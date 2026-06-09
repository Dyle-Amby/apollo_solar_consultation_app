// lib/services/booking_service.dart
//
// Talks to the same n8n "Apollo Booking Tracker" API your web tracker uses:
//   POST apollo-booking-update   → upsert a booking (matched on Ref)
//   GET  apollo-booking-status   → read one booking back by Ref
//
// The consultation app WRITES a booking when the agent finalizes, and (later,
// in History) reads/updates it. Same Airtable "Bookings" table, so the web
// tracker and the app stay in sync on one record per Ref.

import 'dart:convert';
import 'package:http/http.dart' as http;

const String kBookingUpdateUrl =
    'https://bernard100.app.n8n.cloud/webhook/apollo-booking-update';
const String kBookingStatusUrl =
    'https://bernard100.app.n8n.cloud/webhook/apollo-booking-status';
const String kBookingListUrl =
    'https://bernard100.app.n8n.cloud/webhook/apollo-booking-list';
// Fires the confirmation email + Google Sheets log (your "Consultation Booked"
// workflow). Confirm the exact path on that workflow's webhook node and adjust
// if it differs.
const String kConsultationBookedUrl =
    'https://bernard100.app.n8n.cloud/webhook/consultation-booked';

// Booking lifecycle — identical keys/labels to the web tracker's STAGES.
const List<Map<String, String>> kStages = [
  {'key': 'submitted', 'label': 'Booking request received'},
  {'key': 'confirmed', 'label': 'Booking confirmed'},
  {'key': 'assigned', 'label': 'Solar consultant assigned'},
  {'key': 'scheduled', 'label': 'Consultation scheduled'},
  {'key': 'completed', 'label': 'Consultation completed'},
  {'key': 'proposal', 'label': 'Proposal & ROI sent'},
];

int stageIndex(String key) {
  final i = kStages.indexWhere((s) => s['key'] == key);
  return i < 0 ? 0 : i;
}

String stageLabel(String key) => kStages[stageIndex(key)]['label']!;

class BookingService {
  /// Last error message from the most recent service call (empty when none).
  static String lastError = '';
  
  static get _ => null;
  /// Upsert a booking. Returns true only when n8n confirms {ok:true}.
  static Future<bool> save(Map<String, dynamic> payload) async {
    try {
      final res = await http
          .post(
            Uri.parse(kBookingUpdateUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        lastError = 'HTTP ${res.statusCode}: ${res.body}';
        return false;
      }
      final d = jsonDecode(res.body);
      if (d is Map && d['ok'] == true) {
        lastError = '';
        return true;
      }
      lastError = d is Map && d['error'] != null ? '${d['error']}' : 'n8n returned unexpected response';
      return false;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  /// Read one booking back by Ref (used by History later). null if not found.
  static Future<Map<String, dynamic>?> getByRef(String ref) async {
    try {
      final res = await http
          .get(Uri.parse('$kBookingStatusUrl?ref=${Uri.encodeQueryComponent(ref)}'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        lastError = 'HTTP ${res.statusCode}: ${res.body}';
        return null;
      }
      final d = jsonDecode(res.body);
      if (d is Map && d['found'] == true) {
        lastError = '';
        return Map<String, dynamic>.from(d);
      }
      lastError = 'Booking not found';
      return null;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  /// List all bookings for the History screen. Returns [] on any error.
  /// Expects {ok:true, bookings:[{ref, client, classification, schedule, ...}]}.
  static Future<List<Map<String, dynamic>>> listBookings() async {
    try {
      final res = await http
          .get(Uri.parse(kBookingListUrl))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        lastError = 'HTTP ${res.statusCode}: ${res.body}';
        return [];
      }
      final d = jsonDecode(res.body);
      final list = d is Map ? d['bookings'] : d;
      if (list is List) {
        lastError = '';
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      lastError = 'Unexpected response format from booking list';
      return [];
    } catch (_) {
      lastError = _.toString();
      return [];
    }
  }

  /// Fire-and-forget: triggers the "Consultation Booked" workflow
  /// (Google Sheets log + confirmation email). Failure here never blocks the
  /// main save — the record already lives in Airtable via [save].
  static Future<bool> fireConsultationBooked(Map<String, dynamic> payload) async {
    try {
      final res = await http
          .post(
            Uri.parse(kConsultationBookedUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        lastError = '';
        return true;
      }
      lastError = 'HTTP ${res.statusCode}: ${res.body}';
      return false;
    } catch (_) {
      lastError = _.toString();
      return false;
    }
  }
}