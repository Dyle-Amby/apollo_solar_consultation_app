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
// Fires once at finalize: creates the Drive folder AND appends the row in one
// atomic call (folder guaranteed before the row is written). Returns
// {ok, folderId, folderUrl}; ok:false means the folder failed and NO row was
// written (hard-fail) — the booking should be retried.
const String kBookingCreateUrl =
    'https://bernard100.app.n8n.cloud/webhook/apollo-booking-create';
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

// Creates (or finds) the ticket's Google Drive folder named "ClientName-RefNo".
// Called once when a ticket is first booked; returns {folderId, folderUrl}.
const String kFolderCreateUrl =
    'https://bernard100.app.n8n.cloud/webhook/apollo-folder-create';
// Uploads one file (PDF or photo) into the ticket's Drive folder and returns
// its view + download links. Does NOT touch the Consultations row — the app
// folds the returned link into the booking and persists it via save().
const String kDeliverableUploadUrl =
    'https://bernard100.app.n8n.cloud/webhook/apollo-deliverable-upload';

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
          .timeout(const Duration(seconds: 60));
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

  /// Fires ONCE at finalize: the create chain makes the Drive folder, then
  /// appends the row with that folder baked in — one atomic call. Returns the
  /// parsed {ok, folderId, folderUrl} on success, or null on failure (with
  /// [lastError] set). null = hard-fail: the folder couldn't be made, so no row
  /// was written and the user should retry. Every save AFTER booking uses
  /// [save] (the update chain), which never touches the folder.
  static Future<Map<String, dynamic>?> createBooking(Map<String, dynamic> payload) async {
    lastError = '';
    try {
      final res = await http
          .post(
            Uri.parse(kBookingCreateUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60)); // folder + sheet write
      if (res.statusCode != 200) {
        lastError = 'HTTP ${res.statusCode} from $kBookingCreateUrl\n${_short(res.body)}';
        return null;
      }
      final body = res.body.trim();
      if (body.isEmpty) {
        lastError = 'Booking reached n8n (HTTP 200) but the response was empty. '
            'A node likely errored before the Respond node — check the n8n log.';
        return null;
      }
      dynamic d;
      try {
        d = jsonDecode(body);
      } catch (_) {
        lastError = 'Booking returned a non-JSON response:\n${_short(body)}';
        return null;
      }
      if (d is Map && d['ok'] == true) return Map<String, dynamic>.from(d);
      lastError = (d is Map && d['error'] != null)
          ? '${d['error']}'
          : 'Booking could not be completed:\n${_short(body)}';
      return null;
    } catch (e) {
      lastError = '$e';
      return null;
    }
  }

  /// Read one booking back by Ref (used by History later). null if not found.
  static Future<Map<String, dynamic>?> getByRef(String ref) async {
    try {
      final res = await http
          .get(Uri.parse('$kBookingStatusUrl?ref=${Uri.encodeQueryComponent(ref)}'))
          .timeout(const Duration(seconds: 60));
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
          .timeout(const Duration(seconds: 60));
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
          .timeout(const Duration(seconds: 60));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Create (or find) the ticket's Google Drive folder "ClientName-RefNo".
  /// Best-effort: returns {folderId, folderUrl} on success, null otherwise.
  /// A null result never blocks booking — the upload webhook re-creates the
  /// folder if it's still missing when the first file is attached.
  static Future<Map<String, dynamic>?> createFolder(String ref, String client) async {
    try {
      final res = await http
          .post(
            Uri.parse(kFolderCreateUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'ref': ref, 'client': client}),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return null;
      final d = jsonDecode(res.body);
      if (d is Map && d['ok'] == true) return Map<String, dynamic>.from(d);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Upload one deliverable (PDF or photo, base64-encoded) into the ticket's
  /// Drive folder. Returns {url, downloadUrl, name, folderId} on success, else
  /// null with [lastError] set. The caller folds the link into the booking and
  /// persists it with [save] (single writer for the row).
  static Future<Map<String, dynamic>?> uploadDeliverable({
    required String ref,
    required String type,
    required String filename,
    required String mimeType,
    required String dataBase64,
    String folderId = '',
    String client = '',
  }) async {
    lastError = '';
    try {
      final res = await http
          .post(
            Uri.parse(kDeliverableUploadUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'ref': ref,
              'type': type,
              'filename': filename,
              'mimeType': mimeType,
              'dataBase64': dataBase64,
              // Lets the webhook drop the file straight into the known folder;
              // if blank it finds/creates "client-ref" as a fallback.
              'folderId': folderId,
              'client': client,
            }),
          )
          .timeout(const Duration(seconds: 90)); // uploads can be slow on mobile
      if (res.statusCode != 200) {
        lastError = 'HTTP ${res.statusCode} from $kDeliverableUploadUrl\n${_short(res.body)}';
        return null;
      }
      final body = res.body.trim();
      if (body.isEmpty) {
        lastError = 'Upload reached n8n (HTTP 200) but the response was empty. '
            'This usually means a Drive node errored before the Respond node '
            '(e.g. folder not found or wrong credential). Check the n8n execution log.';
        return null;
      }
      dynamic d;
      try {
        d = jsonDecode(body);
      } catch (_) {
        lastError = 'Upload returned a non-JSON response:\n${_short(body)}';
        return null;
      }
      if (d is Map && d['ok'] == true) return Map<String, dynamic>.from(d);
      lastError = (d is Map && d['error'] != null)
          ? '${d['error']}'
          : 'Upload reached n8n (200) but response was not {ok:true}:\n${_short(body)}';
      return null;
    } catch (e) {
      lastError = '$e';
      return null;
    }
  }
}