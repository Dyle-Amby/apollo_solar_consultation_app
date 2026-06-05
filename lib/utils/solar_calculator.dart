// lib/utils/solar_calculator.dart
//
// Ported faithfully from the website's calcTier(). The ONLY intentional
// change is PSH = 4.25 (matching your Technical Study basis) instead of
// the website's 4.5. Loss stays at 0.20 (the ÷0.8 sizing factor == ×1.25).
//
// The tier database below is the offline fallback (an exact copy of the
// website's hardcoded TIERS). fetchLivePricing() overrides it from your
// Google Sheet via the same n8n webhook, so the app and site never drift.
//
// Requires the http package — add to pubspec.yaml:  http: ^1.2.2

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

// ── Constants ───────────────────────────────────────────────
const double kPsh = 4.25;
const double kLoss = 0.20;
const double kDegrad = 0.005;

const String kPricingUrl =
    'https://bernard100.app.n8n.cloud/webhook/apollo-solar-pricing';

// ── Mutable pricing data (live fetch may override) ──────────
Map<String, double> duRates = {
  'meralco': 11.50,
  'batelec1': 10.80,
  'batelec2': 10.50,
  'lima': 9.00,
  'other': 10.00,
};

Map<String, double> dirF = {
  'south': 1.0,
  'southeast': .95,
  'southwest': .95,
  'east': .88,
  'west': .88,
  'north': .75,
  'flat': .97,
  'unknown': .95,
};

// Tier database (fallback). Shape mirrors the website JSON so live data
// can drop straight in.
Map<String, dynamic> tiers = {
  'gridtied': {
    'entry': {
      'label': 'Entry Level', 'tag': 'OPTION 1', 'color': 'entry',
      'panel': {'w': 510, 'price': 4000, 'area': 2.58},
      'inv': {'kw': 6, 'price': 24000},
      'mount': {'rail': 600, 'lfoot': 80, 'rcon': 100, 'mid': 50, 'end': 50},
      'prot': {'dcmcb': 450, 'dcspd': 950, 'acmcb': 350, 'acspd': 450},
      'wire': {'pv': 100, 'gnd': 5600, 'ac': 8600, 'hdpe': 150, 'clamp': 5, 'elbow': 10, 'tray': 400},
      'cons': {'mc4': 60, 'lug': 4, 'comb': 1500, 'grod': 1000, 'ctie': 140, 'cement': 100, 'seal': 150},
      'labor': 49600, 'markup': 0.25,
    },
    'mid': {
      'label': 'Mid Range', 'tag': 'OPTION 2', 'color': 'mid',
      'panel': {'w': 620, 'price': 5000, 'area': 2.80},
      'inv': {'kw': 6, 'price': 23000},
      'mount': {'rail': 530, 'lfoot': 58, 'rcon': 55, 'mid': 35, 'end': 35},
      'prot': {'dcmcb': 550, 'dcspd': 780, 'acmcb': 180, 'acspd': 590},
      'wire': {'pv': 110, 'gnd': 5600, 'ac': 8600, 'hdpe': 150, 'clamp': 5, 'elbow': 10, 'tray': 400},
      'cons': {'mc4': 65, 'lug': 4, 'comb': 1500, 'grod': 1000, 'ctie': 140, 'cement': 100, 'seal': 150},
      'labor': 49600, 'markup': 0.25,
    },
    'high': {
      'label': 'High End', 'tag': 'OPTION 3', 'color': 'high',
      'panel': {'w': 715, 'price': 5600, 'area': 3.11},
      'inv': {'kw': 8, 'price': 34500},
      'mount': {'rail': 530, 'lfoot': 58, 'rcon': 55, 'mid': 35, 'end': 35},
      'prot': {'dcmcb': 550, 'dcspd': 780, 'acmcb': 180, 'acspd': 590, 'rsd': 7500},
      'wire': {'pv': 110, 'gnd': 5600, 'ac': 8600, 'hdpe': 150, 'clamp': 5, 'elbow': 10, 'tray': 400},
      'cons': {'mc4': 65, 'lug': 4, 'comb': 1500, 'grod': 1000, 'ctie': 140, 'cement': 100, 'seal': 150},
      'labor': 49600, 'markup': 0.25,
    },
  },
  'hybrid': {
    'entry': {
      'label': 'Entry Level', 'tag': 'OPTION 1', 'color': 'entry',
      'panel': {'w': 510, 'price': 4000, 'area': 2.58},
      'inv': {'kw': 8, 'price': 57700},
      'batt': {'kwh': 10.24, 'price': 62000},
      'mount': {'rail': 600, 'lfoot': 80, 'rcon': 100, 'mid': 50, 'end': 50},
      'prot': {'dcmcb': 450, 'dcspd': 950, 'acmcb': 350, 'acspd': 450, 'ats': 2000, 'battmccb': 3900},
      'wire': {'pv': 100, 'gnd': 5600, 'ac': 8600, 'hdpe': 150, 'clamp': 5, 'elbow': 10, 'tray': 400, 'battcable': 950, 'battcableQty': 4},
      'cons': {'mc4': 60, 'lug': 4, 'comb': 1500, 'grod': 1000, 'ctie': 140, 'cement': 100, 'seal': 150},
      'labor': 49600, 'markup': 0.25,
    },
    'mid': {
      'label': 'Mid Range', 'tag': 'OPTION 2', 'color': 'mid',
      'panel': {'w': 620, 'price': 5000, 'area': 2.80},
      'inv': {'kw': 8, 'price': 64000},
      'batt': {'kwh': 14.34, 'price': 77000},
      'mount': {'rail': 530, 'lfoot': 58, 'rcon': 55, 'mid': 35, 'end': 35},
      'prot': {'dcmcb': 550, 'dcspd': 780, 'acmcb': 180, 'acspd': 590, 'ats': 2000, 'battmccb': 3900},
      'wire': {'pv': 110, 'gnd': 5600, 'ac': 8600, 'hdpe': 150, 'clamp': 5, 'elbow': 10, 'tray': 400, 'battcable': 950, 'battcableQty': 4},
      'cons': {'mc4': 65, 'lug': 4, 'comb': 1500, 'grod': 1000, 'ctie': 140, 'cement': 100, 'seal': 150},
      'labor': 49600, 'markup': 0.25,
    },
    'high': {
      'label': 'High End', 'tag': 'OPTION 3', 'color': 'high',
      'panel': {'w': 715, 'price': 5600, 'area': 3.11},
      'inv': {'kw': 10, 'price': 68000},
      'batt': {'kwh': 16.07, 'price': 94000},
      'mount': {'rail': 530, 'lfoot': 58, 'rcon': 55, 'mid': 35, 'end': 35},
      'prot': {'dcmcb': 550, 'dcspd': 780, 'acmcb': 180, 'acspd': 590, 'ats': 6000, 'battmccb': 3900, 'rsd': 7500},
      'wire': {'pv': 110, 'gnd': 5600, 'ac': 8600, 'hdpe': 150, 'clamp': 5, 'elbow': 10, 'tray': 400, 'battcable': 950, 'battcableQty': 4},
      'cons': {'mc4': 65, 'lug': 4, 'comb': 1500, 'grod': 1000, 'ctie': 140, 'cement': 100, 'seal': 150},
      'labor': 49600, 'markup': 0.25,
    },
  },
};

// ── Pricing source tracking ─────────────────────────────────
String pricingSource = 'fallback'; // 'live' | 'fallback'
DateTime? pricingUpdatedAt;
bool _pricingTried = false;

num _n(dynamic v) => v is num ? v : 0;

/// Fetch once per app session; safe to call repeatedly (no-op after first).
/// Call this when the consultation flow opens for instant results later.
Future<void> ensurePricing() async {
  if (_pricingTried) return;
  _pricingTried = true;
  await fetchLivePricing();
}

Future<void> fetchLivePricing() async {
  try {
    final url = Uri.parse('$kPricingUrl?t=${DateTime.now().millisecondsSinceEpoch}');
    final res = await http.get(url).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true || data['pricing'] == null) {
      throw Exception('invalid pricing payload');
    }
    final p = data['pricing'] as Map<String, dynamic>;

    if (p['du_rates'] is Map) {
      (p['du_rates'] as Map).forEach((k, v) {
        if (v is num) duRates['$k'] = v.toDouble();
      });
    }
    if (p['dir_f'] is Map) {
      (p['dir_f'] as Map).forEach((k, v) {
        if (v is num) dirF['$k'] = v.toDouble();
      });
    }
    final pt = p['tiers'];
    if (pt is Map) {
      if (pt['gridtied'] != null) tiers['gridtied'] = Map<String, dynamic>.from(pt['gridtied']);
      if (pt['hybrid'] != null) tiers['hybrid'] = Map<String, dynamic>.from(pt['hybrid']);
    }

    pricingSource = 'live';
    pricingUpdatedAt =
        data['updated_at'] != null ? DateTime.tryParse('${data['updated_at']}') : null;
  } catch (_) {
    pricingSource = 'fallback';
  }
}

// ── Result of one tier calculation ──────────────────────────
class TierResult {
  final String label;
  final String tag;
  final String color; // 'entry' | 'mid' | 'high'
  final int panels;
  final int panelWp;
  final double actualKwp;
  final double invKw;
  final double battKwh;
  final int spaceM2;
  final int totalSRP;
  final double dailyYield;
  final int monthlySavings;
  final int annualSavings;
  final String roiYears;
  final int roiMonths;

  TierResult({
    required this.label,
    required this.tag,
    required this.color,
    required this.panels,
    required this.panelWp,
    required this.actualKwp,
    required this.invKw,
    required this.battKwh,
    required this.spaceM2,
    required this.totalSRP,
    required this.dailyYield,
    required this.monthlySavings,
    required this.annualSavings,
    required this.roiYears,
    required this.roiMonths,
  });

  double get perWp => actualKwp > 0 ? totalSRP / (actualKwp * 1000) : 0;
}

/// Faithful port of calcTier(t, monthlyKwh, kwhRate) with PSH 4.25.
TierResult calcTier(
  Map<String, dynamic> t,
  double monthlyKwh,
  double kwhRate, {
  String roofDir = 'unknown',
}) {
  final p = t['panel'] as Map<String, dynamic>;
  final inv = (t['inv'] ?? const {}) as Map<String, dynamic>;
  final mount = t['mount'] as Map<String, dynamic>;
  final prot = t['prot'] as Map<String, dynamic>;
  final wire = t['wire'] as Map<String, dynamic>;
  final cons = t['cons'] as Map<String, dynamic>;
  final batt = t['batt'] as Map<String, dynamic>?;
  final mk = _n(t['markup']);
  final pw = _n(p['w']);

  final dailyKwh = monthlyKwh / 30;
  final neededKwp = dailyKwh / (kPsh * (1 - kLoss));
  final nP = max((neededKwp * 1000 / pw).ceil(), 2);
  final actualKwp = nP * pw / 1000;
  final sC = max(1, (nP / 10).ceil());

  final rQ = (nP * 1.8).round();
  final lfQ = rQ * 4;
  final rcQ = rQ;
  final mcQ = nP * 3 + 6;
  final ecQ = sC * 10;
  final pvQ = sC * 30;
  final hdQ = (pvQ / 2).round();
  final pcQ = hdQ * 3;
  final peQ = (hdQ / 2).round();

  num mat = 0;
  mat += nP * _n(p['price']);
  mat += _n(inv['price']);
  if (batt != null) mat += _n(batt['price']);
  mat += rQ * _n(mount['rail']) +
      lfQ * _n(mount['lfoot']) +
      rcQ * _n(mount['rcon']) +
      mcQ * _n(mount['mid']) +
      ecQ * _n(mount['end']);
  mat += sC * _n(prot['dcmcb']) + sC * _n(prot['dcspd']) + _n(prot['acmcb']) + _n(prot['acspd']);
  mat += _n(prot['ats']) + _n(prot['battmccb']) + _n(prot['rsd']);
  mat += pvQ * _n(wire['pv']) +
      _n(wire['gnd']) +
      _n(wire['ac']) +
      hdQ * _n(wire['hdpe']) +
      pcQ * _n(wire['clamp']) +
      peQ * _n(wire['elbow']) +
      2 * _n(wire['tray']);
  if (wire['battcable'] != null) {
    mat += _n(wire['battcableQty'] ?? 4) * _n(wire['battcable']);
  }
  mat += sC * _n(cons['mc4']) +
      (nP + rQ) * _n(cons['lug']) +
      _n(cons['comb']) +
      _n(cons['grod']) +
      2 * _n(cons['ctie']) +
      _n(cons['cement']) +
      2 * _n(cons['seal']);

  final matSRP = (mat * (1 + mk)).round();
  final laborCost = t['labor_rate'] != null
      ? (_n(t['labor_rate']) * actualKwp * 1000).round()
      : (t['labor'] != null ? _n(t['labor']).round() : 49600);
  final totalSRP = matSRP + laborCost;

  final spaceM2 = (nP * _n(p['area']) * 1.4).round();
  final df = dirF[roofDir] ?? dirF['unknown']!;
  final dailyYield = actualKwp * kPsh * (1 - kLoss) * df;
  final monthlySavings = (dailyYield * 30 * kwhRate).round();
  final annualSavings = monthlySavings * 12;
  final roiMonths = monthlySavings > 0 ? totalSRP / monthlySavings : 0.0;

  return TierResult(
    label: '${t['label']}',
    tag: '${t['tag']}',
    color: '${t['color']}',
    panels: nP,
    panelWp: pw.round(),
    actualKwp: actualKwp.toDouble(),
    invKw: _n(inv['kw']).toDouble(),
    battKwh: batt != null ? _n(batt['kwh']).toDouble() : 0,
    spaceM2: spaceM2,
    totalSRP: totalSRP,
    dailyYield: dailyYield.toDouble(),
    monthlySavings: monthlySavings,
    annualSavings: annualSavings,
    roiYears: (roiMonths / 12).toStringAsFixed(1),
    roiMonths: roiMonths.round(),
  );
}

/// Convenience: compute all three tiers for a system type.
List<TierResult> calcAllTiers({
  required String systemType,
  required double monthlyKwh,
  required double kwhRate,
  String roofDir = 'unknown',
}) {
  final set = tiers[systemType] as Map<String, dynamic>;
  return [
    calcTier(set['entry'], monthlyKwh, kwhRate, roofDir: roofDir),
    calcTier(set['mid'], monthlyKwh, kwhRate, roofDir: roofDir),
    calcTier(set['high'], monthlyKwh, kwhRate, roofDir: roofDir),
  ];
}