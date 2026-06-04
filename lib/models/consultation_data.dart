// lib/models/consultation_data.dart
//
// Single shared data object for the whole consultation flow.
// Step-1 field names (fullName, contactNumber, email, propertyType,
// address, latitude, longitude) are kept EXACTLY as your built page
// expects, so step1_client_info.dart keeps compiling unchanged.
//
// The remaining fields follow the website (apollosolarventures.com)
// flow. Sales-classification fields are intentionally left out — those
// come in Phase 2.

class ConsultationData {
  // ── Step 1 · Client Info (already built) ──────────────────
  String fullName = '';
  String contactNumber = '';
  String email = '';
  String propertyType = 'Residential';
  String address = '';
  double latitude = 0;
  double longitude = 0;

  // ── Step 2 · Priority ─────────────────────────────────────
  // savings | zeroBill | backup | offgrid
  String priority = '';

  // ── Step 3 · System Type ──────────────────────────────────
  // gridtied | hybrid
  String systemType = 'gridtied';

  // ── Step 4 · Electricity ──────────────────────────────────
  double bill1 = 0;
  double bill2 = 0;
  double bill3 = 0;
  // meralco | batelec1 | batelec2 | lima | other
  String distributionUtility = '';

  /// Average of whichever monthly bills were entered (ignores blanks/zeros).
  double get avgMonthlyBill {
    final bills = [bill1, bill2, bill3].where((b) => b > 0).toList();
    if (bills.isEmpty) return 0;
    return bills.reduce((a, b) => a + b) / bills.length;
  }

  // ── Step 5 · Roof Info ────────────────────────────────────
  // metal | concrete | tile | ground
  String roofType = '';
  double roofLength = 0;
  double roofWidth = 0;
  // unknown | south | flat  (matches the website's options)
  String roofDirection = 'unknown';
  String obstructions = '';

  // ── Step 6 · Battery Backup (Hybrid only) ─────────────────
  int acuCount = 0;
  double acuTotalHp = 0;
  int batteryQty = 1;

  // ── Step 7 · Timeline ─────────────────────────────────────
  // asap | 1-3mo | 3-6mo | justlooking
  String timeline = '';

  // ── Generated ─────────────────────────────────────────────
  String leadId = '';

  bool get isHybrid => systemType == 'hybrid';
}