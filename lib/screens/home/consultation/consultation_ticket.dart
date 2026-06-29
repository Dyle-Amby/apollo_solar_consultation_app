// lib/screens/home/consultation/consultation_ticket.dart
//
// The role-gated consultation ticket tracker (Flutter port of the HTML
// preview). Opened from the history list. Renders the 7-stage pipeline as a
// vertical timeline; each step is owned by a role and only that role can
// advance it. Advancing appends an event and upserts the booking via n8n.
//
// TEMPORARY: roles aren't in auth yet, so the active role is chosen with the
// selector at the top. Replace `_activeRole` with the logged-in user's role
// once accounts carry a role.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:apollo_solar_consultation_app/services/booking_service.dart';
import 'package:apollo_solar_consultation_app/services/session.dart';
import 'package:apollo_solar_consultation_app/services/auth_service.dart';
import 'package:apollo_solar_consultation_app/services/ticket_pipeline.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_details.dart';

const _navy = Color(0xFF1A2A6C);
const _gold = Color(0xFFC8A200);
const _green = Color(0xFF1F9D6B);
const _grey = Color(0xFF888888);
const _line = Color(0xFFE3E7F0);

String _roleLabel(String r) =>
    {
      'sales': 'Sales Agent',
      'hos': 'Head of Sales',
      'eng': 'Engineering',
      'hoe': 'Head of Engineering',
      'admin': 'Admin',
    }[r] ??
    r;
Color _roleColor(String r) =>
    {
      'sales': _navy,
      'hos': _gold,
      'eng': _green,
      'hoe': const Color(0xFF128C7E),
      'admin': const Color(0xFF6B4FA0),
    }[r] ??
    _navy;

// Step model + pipeline now live in services/ticket_pipeline.dart.
typedef _Step = TicketStep;
const List<_Step> _steps = kTicketSteps;

class ConsultationTicketScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const ConsultationTicketScreen({Key? key, required this.booking}) : super(key: key);

  @override
  State<ConsultationTicketScreen> createState() => _ConsultationTicketScreenState();
}

class _ConsultationTicketScreenState extends State<ConsultationTicketScreen> {
  String _activeRole = 'sales';
  bool _saving = false;
  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic> _deliverables = {};

  @override
  void initState() {
    super.initState();
    // Use the signed-in user's role when available; otherwise fall back to the
    // selector (handy while testing before everyone has a role set).
    if (Session.role.isNotEmpty) _activeRole = Session.role;
    _events = _parseEvents(widget.booking['events']);
    _deliverables = parseDeliverables(widget.booking['deliverables']);
  }

  List<Map<String, dynamic>> _parseEvents(dynamic raw) {
    try {
      if (raw is String && raw.isNotEmpty) {
        final d = jsonDecode(raw);
        if (d is List) return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (raw is List) {
        return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Set<String> get _doneKeys =>
      _events.map((e) => '${e['stepKey'] ?? ''}').where((k) => k.isNotEmpty).toSet();

  int get _currentIndex {
    for (int i = 0; i < _steps.length; i++) {
      if (!_doneKeys.contains(_steps[i].key)) return i;
    }
    return _steps.length;
  }

  Map<String, dynamic>? _eventFor(String key) {
    for (final e in _events) {
      if ('${e['stepKey'] ?? ''}' == key) return e;
    }
    return null;
  }

  // ── Date / format helpers ──
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _fmtDateTime(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '${_months[d.month - 1]} ${d.day}, ${d.year} · $h:${d.minute.toString().padLeft(2, '0')} $ap';
  }
  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }
  bool _looksIso(String s) => RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s);

  // ── View / edit the original consultation ──
  Future<void> _openDetails() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConsultationDetailsScreen(booking: widget.booking),
      ),
    );
    // The details screen edits widget.booking in place on save, so refresh
    // this ticket to reflect any name / detail changes.
    if (mounted) setState(() {});
  }

  // ── Advancing a step ──
  Future<void> _advance(_Step s) async {
    if (s.input == 'outcome') {
      await _handleOutcome(s);
      return;
    }
    String value = '';
    switch (s.input) {
      case 'date':
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: now.subtract(const Duration(days: 365)),
          lastDate: now.add(const Duration(days: 365)),
        );
        if (d == null) return;
        if (!mounted) return;
        final tod = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(now),
        );
        if (tod == null) return;
        value = DateTime(d.year, d.month, d.day, tod.hour, tod.minute).toIso8601String();
        break;
      case 'text':
        final t = await _textDialog();
        if (t == null) return;
        value = t.isEmpty ? 'Team assigned' : t;
        break;
      case 'team':
        final picked = await _assignTeamDialog();
        if (picked == null) return;
        value = picked;
        break;
      case 'choice':
        final c = await _choiceSheet();
        if (c == null) return;
        value = c;
        break;
      case 'deliverable':
        await _attachQuotation(s);
        return;
      case 'photo':
        await _handlePod(s);
        return;
      case 'photos':
        // The install_photos step uses its own inline Before/During/After UI
        // (see _installPhotosAction); the generic advance path isn't used.
        return;
      default:
        value = '';
    }
    await _persist(s, value);
  }

  // Pick a PDF, upload it to the ticket's Drive folder, record the link under
  // the step's deliverable key, then advance the step. The Final Quotation step
  // can't complete without this file, so attaching IS the action.
  Future<void> _attachQuotation(_Step s) async {
    final keys = stepDeliverableKeys(s);
    final type = keys.isNotEmpty ? keys.first : 'quotation';

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true, // we need the bytes to base64-encode for the webhook
      );
    } catch (e) {
      _toast('Could not open file picker: $e', error: true);
      return;
    }
    if (picked == null || picked.files.isEmpty) return; // cancelled

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _toast('Could not read the selected file.', error: true);
      return;
    }
    final name = file.name.isEmpty ? 'Quotation.pdf' : file.name;

    setState(() => _saving = true);
    final result = await BookingService.uploadDeliverable(
      ref: '${widget.booking['ref'] ?? ''}',
      type: type,
      filename: name,
      mimeType: 'application/pdf',
      dataBase64: base64Encode(bytes),
      folderId: '${widget.booking['driveFolderId'] ?? ''}',
      client: '${widget.booking['client'] ?? ''}',
    );
    if (!mounted) return;

    if (result == null) {
      setState(() => _saving = false);
      _uploadErrorDialog();
      return;
    }

    // Record the link locally; _commit re-sends the whole Deliverables map so
    // it survives the upsert. If n8n had to (re)create the folder, capture it.
    _deliverables[type] = {
      'url': '${result['url'] ?? ''}',
      'downloadUrl': '${result['downloadUrl'] ?? result['url'] ?? ''}',
      'name': '${result['name'] ?? name}',
      'by': Session.name.isNotEmpty ? Session.name : _roleLabel(_activeRole),
      'at': DateTime.now().toIso8601String(),
    };
    final fid = '${result['folderId'] ?? ''}';
    final furl = '${result['folderUrl'] ?? ''}';
    if (fid.isNotEmpty) widget.booking['driveFolderId'] = fid;
    if (furl.isNotEmpty) widget.booking['driveFolderUrl'] = furl;

    // _saving is reset inside _commit; advance the step now.
    await _persist(s, 'Quotation submitted: $name');
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _toast('Invalid link.', error: true);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _toast('Could not open the link.', error: true);
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  void _uploadErrorDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Upload failed'),
        content: SingleChildScrollView(
          child: SelectableText(
            BookingService.lastError.isEmpty ? 'Unknown error.' : BookingService.lastError,
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  // ── Photo deliverables (Proof of Delivery, Install Before/During/After) ──
  Future<ImageSource?> _pickImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add a photo',
                  style: TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: _navy),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _navy),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Capture (or pick) one image, compress to ~1 MB, upload it under [type].
  /// Records the link in _deliverables on success and returns true. Leaves
  /// _saving = true on success so the caller's save resets it.
  Future<bool> _captureAndUpload(String type, String namePrefix) async {
    final source = await _pickImageSource();
    if (source == null) return false;

    XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2400,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      _toast('Could not open camera/gallery: $e', error: true);
      return false;
    }
    if (shot == null) return false; // cancelled

    Uint8List bytes;
    try {
      final raw = await shot.readAsBytes();
      bytes = await FlutterImageCompress.compressWithList(
        raw,
        minWidth: 1280,
        minHeight: 1280,
        quality: 68, // ~1 MB for a typical phone photo
      );
    } catch (e) {
      _toast('Could not process the photo: $e', error: true);
      return false;
    }

    final ref = '${widget.booking['ref'] ?? ''}';
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final fname = '${namePrefix}_${ref}_$stamp.jpg';

    setState(() => _saving = true);
    final result = await BookingService.uploadDeliverable(
      ref: ref,
      type: type,
      filename: fname,
      mimeType: 'image/jpeg',
      dataBase64: base64Encode(bytes),
      folderId: '${widget.booking['driveFolderId'] ?? ''}',
      client: '${widget.booking['client'] ?? ''}',
    );
    if (!mounted) return false;
    if (result == null) {
      setState(() => _saving = false);
      _uploadErrorDialog();
      return false;
    }

    _deliverables[type] = {
      'url': '${result['url'] ?? ''}',
      'downloadUrl': '${result['downloadUrl'] ?? result['url'] ?? ''}',
      'name': '${result['name'] ?? fname}',
      'by': Session.name.isNotEmpty ? Session.name : _roleLabel(_activeRole),
      'at': DateTime.now().toIso8601String(),
    };
    final fid = '${result['folderId'] ?? ''}';
    if (fid.isNotEmpty) widget.booking['driveFolderId'] = fid;
    return true;
  }

  // Proof of Delivery: one photo completes the step.
  Future<void> _handlePod(_Step s) async {
    final ok = await _captureAndUpload('proof_delivery', 'ProofOfDelivery');
    if (!ok) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    await _persist(s, 'Proof of delivery photo uploaded');
  }

  // Install photos: each capture saves WITHOUT advancing; the step only
  // completes once all three (before/during/after) are attached.
  Future<void> _captureInstallPhoto(String type) async {
    final label = (kDeliverableLabels[type] ?? 'Photo').replaceAll(' ', '');
    final ok = await _captureAndUpload(type, 'Install$label');
    if (!mounted) return;
    if (!ok) {
      setState(() => _saving = false);
      return;
    }
    await _saveDeliverablesOnly();
  }

  Future<void> _completeInstallPhotos(_Step s) async {
    if (!stepDeliverablesSatisfied(s, _deliverables)) {
      _toast('Add the Before, During and After photos first.', error: true);
      return;
    }
    await _persist(s, 'Before / During / After photos uploaded');
  }

  // Re-save the row with the current events (no new step) so an updated
  // _deliverables map is persisted without advancing the pipeline.
  Future<void> _saveDeliverablesOnly() async {
    final doneNow = _events.map((e) => '${e['stepKey']}').toSet();
    String statusLabel = 'Completed';
    int stageIdx = _steps.length;
    for (int i = 0; i < _steps.length; i++) {
      if (!doneNow.contains(_steps[i].key)) {
        statusLabel = _steps[i].label;
        stageIdx = i;
        break;
      }
    }
    final ownerNow = stageIdx < _steps.length ? _steps[stageIdx].owner : '';
    await _commit(_events, statusLabel, stageIdx, ownerNow);
  }

  // Multi-select of registered Engineering users (role eng or hoe). Returns the
  // chosen names comma-joined, or null if cancelled. Falls back to free text if
  // no users can be loaded.
  Future<String?> _assignTeamDialog() async {
    setState(() => _saving = true);
    final all = await AuthService.listUsers();
    if (!mounted) return null;
    setState(() => _saving = false);

    final team = all.where((u) {
      final r = '${u['role'] ?? ''}';
      return r == 'eng' || r == 'hoe';
    }).toList();

    if (team.isEmpty) {
      _toast('No Engineering users found — type the names instead.');
      return _textDialog();
    }

    final selected = <String>{};
    return showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Assign Engineering Team'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Select all who will handle this installation:',
                      style: TextStyle(fontSize: 12.5, color: _grey)),
                ),
                for (final u in team)
                  CheckboxListTile(
                    value: selected.contains('${u['name']}'),
                    dense: true,
                    activeColor: _navy,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('${u['name'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${u['role'] == 'hoe' ? 'Head of Engineering' : 'Engineering'} · ${u['email'] ?? ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onChanged: (v) => setLocal(() {
                      final n = '${u['name']}';
                      if (v == true) {
                        selected.add(n);
                      } else {
                        selected.remove(n);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, selected.join(', ')),
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
              child: Text('Assign (${selected.length})'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _textDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Engineering Team'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Engr. Diaz, Engr. Lingao'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Assign')),
        ],
      ),
    );
  }

  Future<String?> _choiceSheet() async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Client second-opinion outcome',
                  style: TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: _green),
              title: const Text('Approved — proceed'),
              onTap: () => Navigator.pop(context, 'Approved — proceed'),
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: _gold),
              title: const Text('Needs another quote / ocular'),
              onTap: () => Navigator.pop(context, 'Needs another quote / ocular'),
            ),
            ListTile(
              leading: const Icon(Icons.skip_next, color: _grey),
              title: const Text('No second opinion'),
              onTap: () => Navigator.pop(context, 'No second opinion'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Client-decision outcome (client_ok step) ──
  Future<void> _handleOutcome(_Step s) async {
    final choice = await _outcomeSheet();
    if (choice == null) return;
    if (choice == 'closing') {
      await _persist(s, kOutcomeLabels['closing']!, outcome: 'closing');
    } else if (choice == 'workable') {
      await _persistWorkable(s);
    } else if (choice == 'lost') {
      final reason = await _reasonDialog();
      if (reason == null) return; // agent cancelled — leave the ticket open
      await _persistLost(s, reason);
    }
  }

  Future<String?> _outcomeSheet() async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Client decision on the final quotation',
                  style: TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: _green),
              title: const Text('For Closing'),
              subtitle: const Text('Approved — proceed to delivery & installation'),
              onTap: () => Navigator.pop(context, 'closing'),
            ),
            ListTile(
              leading: const Icon(Icons.timelapse, color: _gold),
              title: const Text('Workable'),
              subtitle: const Text('Still negotiating — keep working the client'),
              onTap: () => Navigator.pop(context, 'workable'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Color(0xFFC0392B)),
              title: const Text('Did Not Push Through'),
              subtitle: const Text('Transaction fell through — closes the ticket'),
              onTap: () => Navigator.pop(context, 'lost'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _reasonDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Why did it not push through?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. Chose another supplier, budget on hold, lost contact…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFC0392B)),
            child: const Text('Close ticket'),
          ),
        ],
      ),
    );
  }

  // ── Persisting ──
  // Standard step advance: marks the step done and moves to the next pending one.
  Future<void> _persist(_Step s, String value, {String outcome = ''}) async {
    final by = Session.name.isNotEmpty ? Session.name : _roleLabel(_activeRole);
    final ev = <String, dynamic>{
      'stepKey': s.key,
      'label': s.label,
      'time': DateTime.now().toIso8601String(),
      'by': by,
      'role': _activeRole,
      'value': value,
    };
    if (outcome.isNotEmpty) ev['outcome'] = outcome;
    final newEvents = [..._events, ev];

    // current status = next pending step's label, or "Completed"
    final doneNow = newEvents.map((e) => '${e['stepKey']}').toSet();
    String statusLabel = 'Completed';
    int stageIdx = _steps.length;
    for (int i = 0; i < _steps.length; i++) {
      if (!doneNow.contains(_steps[i].key)) {
        statusLabel = _steps[i].label;
        stageIdx = i;
        break;
      }
    }
    final ownerNow = stageIdx < _steps.length ? _steps[stageIdx].owner : '';
    await _commit(newEvents, statusLabel, stageIdx, ownerNow);
  }

  // Workable: record it WITHOUT marking client_ok done, so the ticket stays
  // parked on that step with Sales and can be re-decided later.
  Future<void> _persistWorkable(_Step s) async {
    final by = Session.name.isNotEmpty ? Session.name : _roleLabel(_activeRole);
    final newEvents = [
      ..._events,
      {
        'stepKey': 'client_workable', // not a real pipeline step
        'label': 'Marked Workable',
        'time': DateTime.now().toIso8601String(),
        'by': by,
        'role': _activeRole,
        'value': kOutcomeLabels['workable'],
        'outcome': 'workable',
      }
    ];
    final idx = _steps.indexWhere((x) => x.key == s.key); // client_ok stays current
    await _commit(newEvents, outcomeStatus('workable'), idx, 'sales');
  }

  // Did Not Push Through: marks client_ok done (so it leaves the queue) but
  // closes the ticket — no further steps — and saves the reason.
  Future<void> _persistLost(_Step s, String reason) async {
    final by = Session.name.isNotEmpty ? Session.name : _roleLabel(_activeRole);
    final newEvents = [
      ..._events,
      {
        'stepKey': s.key,
        'label': 'Did Not Push Through',
        'time': DateTime.now().toIso8601String(),
        'by': by,
        'role': _activeRole,
        'value': kOutcomeLabels['lost'],
        'outcome': 'lost',
        'note': reason.isEmpty ? 'No reason provided' : reason,
      }
    ];
    await _commit(newEvents, outcomeStatus('lost'), _steps.length, '');
  }

  // Shared save: upserts the booking via n8n with the new events + status.
  Future<void> _commit(List<Map<String, dynamic>> newEvents, String statusLabel,
      int stageIdx, String ownerNow) async {
    setState(() => _saving = true);
    final by = Session.name.isNotEmpty ? Session.name : _roleLabel(_activeRole);
    final b = widget.booking;
    final outcome = ticketOutcome(newEvents);
    final payload = {
      'ref': b['ref'],
      'client': b['client'] ?? '',
      'agent': b['agent'] ?? '',
      'schedule': b['schedule'] ?? '',
      'stage': stageIdx,
      'status': statusLabel,
      'currentOwner': ownerNow,
      'events': jsonEncode(newEvents),
      'consultation': b['consultation'] ?? '', // preserve snapshot
      // Files attached to steps (quotation PDF, delivery / install photos) and
      // the ticket's Drive folder — re-sent every upsert so they're never wiped.
      'deliverables': jsonEncode(_deliverables),
      'driveFolderId': b['driveFolderId'] ?? '',
      'driveFolderUrl': b['driveFolderUrl'] ?? '',
      // Re-send the ORIGINAL creation time + flat display fields so the upsert
      // doesn't reset the Sheet's Created/readable columns on each step.
      'createdAt': b['createdAt'] ?? '',
      'clientType': b['clientType'] ?? '',
      'contact': b['contact'] ?? '',
      'email': b['email'] ?? '',
      'location': b['location'] ?? '',
      'systemType': b['systemType'] ?? '',
      // Deal outcome (for the optional "Deal Outcome" / reason columns in Sheets).
      'outcome': outcome,
      'lostReason': outcome == 'lost' ? ticketLostReason(newEvents) : '',
      'updatedBy': by,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final ok = await BookingService.save(payload);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _events = newEvents;
        widget.booking['events'] = jsonEncode(newEvents);
        widget.booking['status'] = statusLabel;
      }
    });

    if (!ok) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Update failed'),
          content: SingleChildScrollView(
            child: SelectableText(
              BookingService.lastError.isEmpty ? 'Unknown error.' : BookingService.lastError,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final cur = _currentIndex;
    final done = cur >= _steps.length;
    final closed = ticketIsClosed(_events);
    final outcome = ticketOutcome(_events);

    String statusText;
    Color statusColor;
    if (closed) {
      statusText = outcomeStatus('lost');
      statusColor = const Color(0xFFC0392B);
    } else if (done) {
      statusText = 'Completed';
      statusColor = _green;
    } else if (outcome == 'workable' && _steps[cur].key == 'client_ok') {
      statusText = outcomeStatus('workable');
      statusColor = _gold;
    } else {
      statusText = _steps[cur].label;
      statusColor = _roleColor(_steps[cur].owner);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Consultation Ticket'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Ticket summary — tap to view / edit the original consultation
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openDetails,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${b['client'] ?? 'Walk-in lead'}'.isEmpty ? 'Walk-in lead' : '${b['client']}',
                                    style: const TextStyle(color: _navy, fontSize: 20, fontWeight: FontWeight.bold)),
                                Text('${b['ref'] ?? ''}',
                                    style: const TextStyle(color: _grey, fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(statusText,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Sales Agent: ${('${b['agent'] ?? ''}'.isEmpty) ? 'Unassigned' : b['agent']}',
                          style: const TextStyle(color: Color(0xFF555555), fontSize: 12.5)),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Icon(Icons.touch_app_outlined, size: 15, color: _gold),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text('Tap to view / edit consultation details',
                                style: TextStyle(color: _navy, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: _gold),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Signed-in account — this is who you are and what you can act on.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 18, color: _roleColor(_activeRole)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Session.name.isEmpty ? 'Signed in' : Session.name,
                              style: const TextStyle(
                                  color: _navy, fontSize: 13, fontWeight: FontWeight.w700)),
                          Text('Acting as ${_roleLabel(_activeRole)}',
                              style: const TextStyle(color: _grey, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _roleColor(_activeRole).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_roleLabel(_activeRole),
                          style: TextStyle(
                              color: _roleColor(_activeRole),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (closed) ...[
                _closedBanner(),
                const SizedBox(height: 14),
              ],

              // Timeline
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < _steps.length; i++) _stepRow(i, cur),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
          if (_saving)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator(color: _navy)),
            ),
        ],
      ),
    );
  }

  Widget _stepRow(int i, int cur) {
    final s = _steps[i];
    final closed = ticketIsClosed(_events);
    final outcome = ticketOutcome(_events);
    final isDone = _doneKeys.contains(s.key);
    final isCur = i == cur && !closed;
    final last = i == _steps.length - 1;
    final ev = _eventFor(s.key);

    Color dotColor;
    Widget dotChild;
    if (isDone) {
      dotColor = _green;
      dotChild = const Icon(Icons.check, color: Colors.white, size: 15);
    } else if (isCur) {
      dotColor = _navy;
      dotChild = const Text('●', style: TextStyle(color: Colors.white, fontSize: 12));
    } else {
      dotColor = const Color(0xFFB8BECC);
      dotChild = Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.stageTitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6, left: 2),
            child: Text(s.stageTitle!.toUpperCase(),
                style: const TextStyle(
                    color: _navy, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
          ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: dotChild,
                  ),
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isDone ? _green : _line,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              s.label + (s.optional ? '  (optional)' : ''),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDone || isCur ? const Color(0xFF222222) : const Color(0xFFAAAAAA)),
                            ),
                          ),
                          _ownerBadge(s.owner),
                        ],
                      ),
                      if (isDone && ev != null) ...[
                        const SizedBox(height: 3),
                        Text(_doneSubtitle(ev),
                            style: const TextStyle(color: _grey, fontSize: 11.5)),
                      ],
                      if (stepNeedsDeliverable(s) && _hasAnyDeliverable(s) && !isCur)
                        _deliverableView(s),
                      if (isCur && s.key == 'client_ok' && outcome == 'workable')
                        _workableNote(),
                      if (isCur) _actionFor(s),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _doneSubtitle(Map<String, dynamic> ev) {
    final t = '${ev['time'] ?? ''}';
    final by = '${ev['by'] ?? ''}';
    final v = '${ev['value'] ?? ''}';
    final vs = v.isEmpty ? '' : (_looksIso(v) ? ' · ${_fmtDateTime(v)}' : ' · $v');
    final note = '${ev['note'] ?? ''}';
    final ns = note.isEmpty ? '' : ' · “$note”';
    return '${_fmtDateTime(t)} · by $by$vs$ns';
  }

  Widget _ownerBadge(String owner) {
    final c = _roleColor(owner);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(_roleLabel(owner),
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _actionFor(_Step s) {
    final mine = canActOn(_activeRole, s.owner);
    if (!mine) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF0DCA0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 15, color: Color(0xFF8A6200)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Waiting on ${_roleLabel(s.owner)}',
                  style: const TextStyle(color: Color(0xFF8A6200), fontSize: 12.5)),
            ),
          ],
        ),
      );
    }

    String label;
    switch (s.input) {
      case 'date':
        label = 'Set date';
        break;
      case 'text':
        label = 'Assign team';
        break;
      case 'team':
        label = 'Assign Engineering team';
        break;
      case 'choice':
        label = 'Record outcome';
        break;
      case 'outcome':
        label = 'Record client decision';
        break;
      case 'deliverable':
        label = 'Attach quotation (PDF)';
        break;
      case 'photo':
        label = 'Take delivery photo';
        break;
      case 'photos':
        // Handled by its own multi-photo UI above.
        return _installPhotosAction(s);
      default:
        label = 'Mark “${s.label}” done';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 42,
        child: ElevatedButton(
          onPressed: _saving ? null : () => _advance(s),
          style: ElevatedButton.styleFrom(
            backgroundColor: _roleColor(s.owner),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // Before / During / After capture tiles + a gated "complete" button.
  Widget _installPhotosAction(_Step s) {
    final types = stepDeliverableKeys(s);
    final ready = stepDeliverablesSatisfied(s, _deliverables);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in types) _installTile(t),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: (_saving || !ready) ? null : () => _completeInstallPhotos(s),
              style: ElevatedButton.styleFrom(
                backgroundColor: ready ? _roleColor(s.owner) : const Color(0xFFB8BECC),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFB8BECC),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: Text(ready ? 'Submit installation photos' : 'Add all three photos first',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _installTile(String type) {
    final v = _deliverables[type];
    final has = v is Map && '${v['url'] ?? ''}'.trim().isNotEmpty;
    final label = kDeliverableLabels[type] ?? type;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: has ? const Color(0xFFEAF7F0) : const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: has ? const Color(0xFF9FD9BE) : const Color(0xFFDDE3F0)),
      ),
      child: Row(
        children: [
          Icon(has ? Icons.check_circle : Icons.photo_camera_outlined,
              size: 18, color: has ? _green : _navy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: has ? _green : _navy, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          if (has) ...[
            TextButton(
              onPressed: () => _openUrl('${v['url']}'),
              child: const Text('View'),
            ),
            TextButton(
              onPressed: _saving ? null : () => _captureInstallPhoto(type),
              child: const Text('Retake'),
            ),
          ] else
            ElevatedButton(
              onPressed: _saving ? null : () => _captureInstallPhoto(type),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add'),
            ),
        ],
      ),
    );
  }

  bool _hasAnyDeliverable(_Step s) {
    for (final k in stepDeliverableKeys(s)) {
      final v = _deliverables[k];
      if (v is Map && '${v['url'] ?? ''}'.trim().isNotEmpty) return true;
    }
    return false;
  }

  Widget _deliverableView(_Step s) {
    final tiles = <Widget>[];
    for (final k in stepDeliverableKeys(s)) {
      final v = _deliverables[k];
      if (v is! Map) continue;
      final url = '${v['url'] ?? ''}';
      if (url.trim().isEmpty) continue;
      final dl = '${v['downloadUrl'] ?? url}';
      final name = '${v['name'] ?? kDeliverableLabels[k] ?? 'File'}';
      final by = '${v['by'] ?? ''}';
      tiles.add(Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDDE3F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 18, color: _navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kDeliverableLabels[k] ?? k,
                          style: const TextStyle(
                              color: _navy, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _grey, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openUrl(url),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: _navy),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openUrl(dl),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Download'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
            if (by.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Submitted by $by',
                    style: const TextStyle(color: _grey, fontSize: 10.5)),
              ),
          ],
        ),
      ));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: tiles);
  }

  Widget _workableNote() {
    Map<String, dynamic>? w;
    for (final e in _events) {
      if ('${e['outcome'] ?? ''}' == 'workable') w = e;
    }
    final t = w == null ? '' : _fmtDateTime('${w['time'] ?? ''}');
    final by = w == null ? '' : '${w['by'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF0DCA0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timelapse, size: 15, color: Color(0xFF8A6200)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              w == null
                  ? 'Currently workable — record the decision again once the client commits.'
                  : 'Marked workable · $t · by $by — record again once the client decides.',
              style: const TextStyle(color: Color(0xFF8A6200), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closedBanner() {
    final reason = ticketLostReason(_events);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEBEA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6B7B2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.cancel, color: Color(0xFFC0392B), size: 18),
              SizedBox(width: 8),
              Text('Did Not Push Through',
                  style: TextStyle(
                      color: Color(0xFFC0392B), fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Reason: $reason',
                style: const TextStyle(color: Color(0xFF7A2820), fontSize: 12.5)),
          ],
          const SizedBox(height: 6),
          const Text('This ticket is closed.',
              style: TextStyle(color: Color(0xFF7A2820), fontSize: 11.5)),
        ],
      ),
    );
  }
}