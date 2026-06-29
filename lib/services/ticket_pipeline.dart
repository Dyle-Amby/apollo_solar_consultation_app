// lib/services/ticket_pipeline.dart
//
// Single source of truth for the consultation ticket pipeline: the ordered
// steps, who owns each, and helpers to figure out a ticket's current step
// from its events. Both the ticket tracker and the dashboard import this so
// the "awaiting your action" logic can never drift from the tracker.

import 'dart:convert';

class TicketStep {
  final String key;
  final String label;
  final String owner; // sales | hos | eng
  final String? stageTitle; // set on the first step of a stage
  final String input; // '' | date | text | choice | deliverable | photo | photos
  final bool optional;
  const TicketStep(this.key, this.label, this.owner,
      {this.stageTitle, this.input = '', this.optional = false});
}

const List<TicketStep> kTicketSteps = [
  TicketStep('ocular_booked', 'Ocular Visit Booked', 'sales',
      stageTitle: '1 · Ocular Visit', input: 'date'),

  TicketStep('ocular_ack', 'Ocular Acknowledged', 'eng',
      stageTitle: '2 · Ocular (Engineering)', input: 'date'),
  TicketStep('ocular_underway', 'Ocular Underway', 'eng'),
  TicketStep('ocular_ongoing', 'Ocular Visit Ongoing', 'eng'),
  TicketStep('ocular_finished', 'Ocular Visit Finished', 'eng'),
  TicketStep('ocular_quote', 'Final Quotation — Price & Specification', 'eng', input: 'deliverable'),
  TicketStep('hos_quote_ok', 'Quotation Approved by Head of Sales', 'hos'),

  TicketStep('quote_sent', 'Final Quotation Sent to Client', 'sales',
      stageTitle: '3 · Quotation to Client'),
  TicketStep('second_opinion', 'Second-Opinion Outcome (if requested)', 'sales',
      input: 'choice', optional: true),

  TicketStep('client_ok', 'Client Decision on Final Quotation', 'sales',
      stageTitle: '4 · Client Approval & Scheduling', input: 'outcome'),
  TicketStep('delivery_date', 'Delivery Date Booked', 'sales', input: 'date'),
  TicketStep('install_date', 'Installation Date Booked', 'sales', input: 'date'),

  TicketStep('eng_assign', 'Assign Engineering Team', 'eng',
      stageTitle: '5 · Engineering Approval', input: 'team'),
  TicketStep('eng_dates', 'Engineering Confirms / Adjusts Dates', 'eng', input: 'date'),
  TicketStep('hos_final', 'Head of Sales Final Approval', 'hos'),

  TicketStep('materials_underway', 'Materials Underway', 'eng', stageTitle: '6 · Delivery'),
  TicketStep('delivery_way', 'Delivery on the Way', 'eng'),
  TicketStep('pod', 'Proof of Delivery', 'eng', input: 'photo'),

  TicketStep('install_underway', 'Installation Underway', 'eng', stageTitle: '7 · Installation'),
  TicketStep('install_photos', 'Photos: Before / During / After', 'eng', input: 'photos'),
  TicketStep('completed', 'Installation Complete', 'eng'),
];

List<Map<String, dynamic>> parseTicketEvents(dynamic raw) {
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

Set<String> ticketDoneKeys(dynamic eventsRaw) => parseTicketEvents(eventsRaw)
    .map((e) => '${e['stepKey'] ?? ''}')
    .where((k) => k.isNotEmpty)
    .toSet();

int ticketCurrentIndex(dynamic eventsRaw) {
  final done = ticketDoneKeys(eventsRaw);
  for (int i = 0; i < kTicketSteps.length; i++) {
    if (!done.contains(kTicketSteps[i].key)) return i;
  }
  return kTicketSteps.length;
}

/// The step currently awaiting action, or null if the ticket is complete.
TicketStep? ticketCurrentStep(dynamic eventsRaw) {
  final i = ticketCurrentIndex(eventsRaw);
  return i < kTicketSteps.length ? kTicketSteps[i] : null;
}

String roleLabel(String r) => const {
      'sales': 'Sales',
      'eng': 'Engineering',
      'hos': 'Head of Sales',
      'hoe': 'Head of Engineering',
      'admin': 'Admin',
    }[r] ?? r;

// Which step-owners a given account role is allowed to act on. Supervisors
// cover their team's steps; Admin covers everything. (Adjust to taste.)
const Map<String, List<String>> kRolePermissions = {
  'sales': ['sales'],
  'hos': ['sales', 'hos'],
  'eng': ['eng'],
  'hoe': ['eng', 'hoe'],
  'admin': ['sales', 'hos', 'eng', 'hoe'],
};

bool canActOn(String userRole, String stepOwner) =>
    (kRolePermissions[userRole] ?? const []).contains(stepOwner);

// ── Client decision outcome (recorded at the client_ok step) ──────────────────
// 'closing'  → client approved; ticket PROCEEDS to delivery / installation.
// 'workable' → still negotiating; ticket PARKS on client_ok (stays with Sales,
//              re-decidable later). Stored under a non-step key so it never
//              marks client_ok done.
// 'lost'     → "Did Not Push Through"; ticket CLOSES, carrying a reason note.
const Map<String, String> kOutcomeLabels = {
  'closing': 'For Closing',
  'workable': 'Workable',
  'lost': 'Did Not Push Through',
};

String outcomeStatus(String outcome) {
  switch (outcome) {
    case 'closing':
      return 'Client Approved — For Closing';
    case 'workable':
      return 'Workable — Awaiting Client Decision';
    case 'lost':
      return 'Closed — Did Not Push Through';
    default:
      return '';
  }
}

/// The most recent client-decision outcome on the ticket, or '' if none yet.
String ticketOutcome(dynamic eventsRaw) {
  var out = '';
  for (final e in parseTicketEvents(eventsRaw)) {
    final o = '${e['outcome'] ?? ''}';
    if (o.isNotEmpty) out = o; // last one wins (re-decisions override)
  }
  return out;
}

/// True once the client declined — the ticket is closed (lost) and needs no
/// further action from anyone.
bool ticketIsClosed(dynamic eventsRaw) => ticketOutcome(eventsRaw) == 'lost';

/// The reason captured when the deal did not push through ('' if none).
String ticketLostReason(dynamic eventsRaw) {
  var reason = '';
  for (final e in parseTicketEvents(eventsRaw)) {
    if ('${e['outcome'] ?? ''}' == 'lost') reason = '${e['note'] ?? ''}';
  }
  return reason;
}

// ── Deliverables (files attached to specific steps) ───────────────────────────
// Some steps can't be completed until a file is attached:
//   ocular_quote   → the Final Quotation PDF (engineering submits; HoS reviews)
//   pod            → a Proof-of-Delivery photo
//   install_photos → Before / During / After photos
// Files live in the ticket's Google Drive folder (ClientName-RefNo). The row's
// Deliverables JSON column stores the links, keyed by the type-keys below.
const Map<String, List<String>> kStepDeliverables = {
  'ocular_quote': ['quotation'],
  'pod': ['proof_delivery'],
  'install_photos': ['install_before', 'install_during', 'install_after'],
};

const Map<String, String> kDeliverableLabels = {
  'quotation': 'Final Quotation (PDF)',
  'proof_delivery': 'Proof of Delivery',
  'install_before': 'Before',
  'install_during': 'During',
  'install_after': 'After',
};

/// The deliverable type-keys a step requires (empty if it needs no file).
List<String> stepDeliverableKeys(TicketStep s) => kStepDeliverables[s.key] ?? const [];

bool stepNeedsDeliverable(TicketStep s) => stepDeliverableKeys(s).isNotEmpty;

/// Parse the Deliverables column (a JSON object keyed by type) into a map.
Map<String, dynamic> parseDeliverables(dynamic raw) {
  try {
    if (raw is String && raw.isNotEmpty) {
      final d = jsonDecode(raw);
      if (d is Map) return Map<String, dynamic>.from(d);
    } else if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
  } catch (_) {}
  return {};
}

/// True once every file a step requires has a non-empty url in [deliverables].
bool stepDeliverablesSatisfied(TicketStep s, Map<String, dynamic> deliverables) {
  for (final k in stepDeliverableKeys(s)) {
    final v = deliverables[k];
    if (v is! Map || '${v['url'] ?? ''}'.trim().isEmpty) return false;
  }
  return true;
}