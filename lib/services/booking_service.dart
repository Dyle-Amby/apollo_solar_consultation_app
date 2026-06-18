// lib/services/booking_service.dart
//
// Talks to the n8n "Apollo Booking" API backed by the Google Sheets
// consultation log:
//   POST apollo-booking-update   → upsert a consultation row (matched on Ref)
//   GET  apollo-booking-list      → read all (or one, with ?ref=)
//
// The app WRITES a consultation row when the agent finalizes, then reads and
// updates it from History / the ticket tracker. One flat row per Ref in the
// Consultations tab, so everything stays in sync on a single record.

import 'dart:convert';
import 'package:http/http.dart' as http;

const String kBookingUpdateUrl =
    'https://bernard100.app.n8n.cloud/webhook/apollo-booking-update';
const String kBookingListUrl =
    'https://bernard100.app.n8n.cloud/webhook/apollo-booking-list';
// The read workflow is a SINGLE webhook: with no query it returns all bookings;
// with ?ref= it returns one. getByRef appends ?ref to this URL, so it points at
// the same apollo-booking-list webhook (the "Check Query Parameter" IF routes it).
const String kBookingStatusUrl = kBookingListUrl;
// Fires the confirmation email + Google Sheets log (your "Consultation Booked"
// workflow). Confirm the exact path on that workflow's webhook node and adjust
// if it differs.
const String kConsultationBookedUrl =
    'https://bernard100.app.n8n.cloud/webhook/consultation-booked';

// NOTE: the old 6-stage kStages / stageLabel / stageIndex helpers were removed.
// The pipeline now lives in lib/services/ticket_pipeline.dart (21 steps, role
// ownership, canActOn). Use that as the single source of truth for stages.

class BookingService {
  /// Holds the reason the last save() failed, for on-screen diagnostics.
  static String lastError = '';

  static String _short(String s) =>
      s.length > 240 ? '${s.substring(0, 240)}…' : s;

  /// Upsert a booking. Returns true only when n8n confirms {ok:true}.
  static Future<bool> save(Map<String, dynamic> payload) async {
    lastError = '';
    try {
      final res = await http
          .post(
            Uri.parse(kBookingUpdateUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        lastError = 'HTTP ${res.statusCode} from $kBookingUpdateUrl\n${_short(res.body)}';
        return false;
      }
      final d = jsonDecode(res.body);
      if (d is Map && d['ok'] == true) return true;
      lastError = 'Reached n8n (200) but response was not {ok:true}:\n${_short(res.body)}';
      return false;
    } catch (e) {
      lastError = '$e';
      return false;
    }
  }

  /// Read one booking back by Ref (used by History later). null if not found.
  static Future<Map<String, dynamic>?> getByRef(String ref) async {
    try {
      final res = await http
          .get(Uri.parse('$kBookingStatusUrl?ref=${Uri.encodeQueryComponent(ref)}'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      final d = jsonDecode(res.body);
      if (d is Map && d['found'] == true) {
        return Map<String, dynamic>.from(d);
      }
      return null;
    } catch (_) {
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
      if (res.statusCode != 200) return [];
      var d = jsonDecode(res.body);

      // n8n's "Respond With" can return the payload a few different ways:
      //   {ok:true, bookings:[...]}            ← First Incoming Item (ideal)
      //   [{ok:true, bookings:[...]}]          ← All Incoming Items (wrapped)
      //   [ {booking}, {booking} ]             ← bare array of rows
      // Unwrap any single-object array first, then pull out `bookings`.
      if (d is List && d.length == 1 && d.first is Map && (d.first as Map).containsKey('bookings')) {
        d = d.first;
      }
      final list = (d is Map && d['bookings'] is List) ? d['bookings'] : d;
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fire-and-forget: triggers the "Consultation Booked" workflow
  /// (confirmation email). Failure here never blocks the main save — the record
  /// already lives in the Google Sheet via [save].
  static Future<bool> fireConsultationBooked(Map<String, dynamic> payload) async {
    try {
      final res = await http
          .post(
            Uri.parse(kConsultationBookedUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}