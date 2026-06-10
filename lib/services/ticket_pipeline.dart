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

  TicketStep('client_ok', 'Final Quotation Approved by Client', 'sales',
      stageTitle: '4 · Client Approval & Scheduling'),
  TicketStep('delivery_date', 'Delivery Date Booked', 'sales', input: 'date'),
  TicketStep('install_date', 'Installation Date Booked', 'sales', input: 'date'),

  TicketStep('eng_assign', 'Assign Engineering Team', 'eng',
      stageTitle: '5 · Engineering Approval', input: 'text'),
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

String roleLabel(String r) =>
    {'sales': 'Sales Agent', 'hos': 'Head of Sales', 'eng': 'Engineering'}[r] ?? r;