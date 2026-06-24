// lib/utils/consultation_pdf.dart
//
// Builds and exports a branded one-page ASV consultation summary PDF.
// Called from the Consultation Details screen's "Export to PDF" button.
//
// Deps (add to pubspec.yaml):
//   pdf: ^3.11.1
//   printing: ^5.13.3
//
// Note on the peso sign: the built-in PDF Helvetica font has no ₱ glyph, so
// amounts are rendered with a "PHP" prefix to stay reliable offline (no
// runtime font download needed).

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const PdfColor _navy = PdfColor.fromInt(0xFF1A2A6C);
const PdfColor _gold = PdfColor.fromInt(0xFFC8A200);
const PdfColor _grey = PdfColor.fromInt(0xFF6B6B6B);
const PdfColor _ink = PdfColor.fromInt(0xFF1A1A1A);
const PdfColor _rowAlt = PdfColor.fromInt(0xFFF4F6FB);

/// Plain data bag so the builder doesn't depend on any screen/state.
class ConsultationPdfData {
  final String ref;
  final String clientName;
  final String contact;
  final String email;
  final String propertyType;
  final String address;
  final String systemTypeLabel;
  final String priorityLabel;
  final num avgBill;
  final String duLabel;
  final num monthlyKwh;
  final String timelineLabel;
  final String roofType;
  final String roofDims; // pre-formatted e.g. "8.0 × 6.0 m" or "—"
  final String roofDirLabel;
  final String obstructions;
  final String notes;
  final String agent;
  final List<Map<String, dynamic>> recommendations;

  ConsultationPdfData({
    required this.ref,
    required this.clientName,
    required this.contact,
    required this.email,
    required this.propertyType,
    required this.address,
    required this.systemTypeLabel,
    required this.priorityLabel,
    required this.avgBill,
    required this.duLabel,
    required this.monthlyKwh,
    required this.timelineLabel,
    required this.roofType,
    required this.roofDims,
    required this.roofDirLabel,
    required this.obstructions,
    required this.notes,
    required this.agent,
    required this.recommendations,
  });
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _today() {
  final n = DateTime.now();
  return '${_months[n.month - 1]} ${n.day}, ${n.year}';
}

String _thousands(num v) {
  final neg = v < 0;
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b';
}

String _peso(num v) => 'PHP ${_thousands(v)}';

String _orDash(String s) => s.trim().isEmpty ? '—' : s.trim();

Future<Uint8List> buildConsultationPdf(ConsultationPdfData d) async {
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) {
        return pw.Column(
          mainAxisSize: pw.MainAxisSize.max,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(d),
            pw.Container(height: 3, color: _gold),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(26, 18, 26, 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _refLine(d),
                    pw.SizedBox(height: 14),
                    _section('Client Information', [
                      _kv('Name', _orDash(d.clientName)),
                      _kv('Contact', _orDash(d.contact)),
                      _kv('Email', _orDash(d.email)),
                      _kv('Property type', _orDash(d.propertyType)),
                      _kv('Address', _orDash(d.address)),
                    ]),
                    pw.SizedBox(height: 12),
                    _section('System & Usage', [
                      _kv('System type', _orDash(d.systemTypeLabel)),
                      _kv('Priority', _orDash(d.priorityLabel)),
                      _kv('Avg. monthly bill',
                          d.avgBill > 0 ? _peso(d.avgBill) : '—'),
                      _kv('Distribution utility', _orDash(d.duLabel)),
                      _kv('Est. monthly usage',
                          d.monthlyKwh > 0 ? '${_thousands(d.monthlyKwh)} kWh' : '—'),
                      _kv('Timeline', _orDash(d.timelineLabel)),
                    ]),
                    pw.SizedBox(height: 12),
                    _section('Roof', [
                      _kv('Roof type', _orDash(d.roofType)),
                      _kv('Dimensions', _orDash(d.roofDims)),
                      _kv('Facing', _orDash(d.roofDirLabel)),
                      _kv('Obstructions', _orDash(d.obstructions)),
                    ]),
                    pw.SizedBox(height: 14),
                    _recsBlock(d.recommendations),
                    if (d.notes.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 14),
                      _notesBlock(d.notes.trim()),
                    ],
                  ],
                ),
              ),
            ),
            _footer(d),
          ],
        );
      },
    ),
  );

  return doc.save();
}

/// Build the PDF and open the system print / save-as-PDF / share sheet.
Future<void> exportConsultationPdf(ConsultationPdfData d) async {
  final bytes = await buildConsultationPdf(d);
  final safeRef = d.ref.isEmpty ? 'consultation' : d.ref;
  await Printing.layoutPdf(
    name: 'ASV-$safeRef.pdf',
    onLayout: (_) async => bytes,
  );
}

// ── building blocks ──

pw.Widget _header(ConsultationPdfData d) {
  return pw.Container(
    color: _navy,
    padding: const pw.EdgeInsets.fromLTRB(26, 22, 26, 20),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('APOLLO SOLAR VENTURES INC.',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.3)),
              pw.SizedBox(height: 4),
              pw.Text("Harness the Power of the Sun",
                  style: pw.TextStyle(
                      color: _gold,
                      fontSize: 9.5,
                      fontStyle: pw.FontStyle.italic)),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('CONSULTATION',
                style: pw.TextStyle(
                    color: _gold,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2)),
            pw.Text('SUMMARY',
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2)),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _refLine(ConsultationPdfData d) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_orDash(d.clientName),
              style: pw.TextStyle(
                  color: _navy, fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Ref: ${_orDash(d.ref)}',
              style: pw.TextStyle(color: _grey, fontSize: 10)),
        ],
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('Date: ${_today()}',
              style: pw.TextStyle(color: _grey, fontSize: 10)),
          if (d.agent.trim().isNotEmpty)
            pw.Text('Prepared by: ${d.agent.trim()}',
                style: pw.TextStyle(color: _grey, fontSize: 10)),
        ],
      ),
    ],
  );
}

pw.Widget _section(String title, List<pw.Widget> rows) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title.toUpperCase(),
          style: pw.TextStyle(
              color: _navy,
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.8)),
      pw.SizedBox(height: 3),
      pw.Container(height: 1, color: _gold),
      pw.SizedBox(height: 7),
      ...rows,
    ],
  );
}

pw.Widget _kv(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(label,
              style: pw.TextStyle(color: _grey, fontSize: 10)),
        ),
        pw.Expanded(
          child: pw.Text(value,
              style: pw.TextStyle(
                  color: _ink, fontSize: 10.5, fontWeight: pw.FontWeight.normal)),
        ),
      ],
    ),
  );
}

pw.Widget _recsBlock(List<Map<String, dynamic>> recs) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('RECOMMENDED OPTIONS',
          style: pw.TextStyle(
              color: _navy,
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.8)),
      pw.SizedBox(height: 3),
      pw.Container(height: 1, color: _gold),
      pw.SizedBox(height: 7),
      if (recs.isEmpty)
        pw.Text('No recommendations on file.',
            style: pw.TextStyle(color: _grey, fontSize: 10))
      else
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(2.4),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(2.0),
            3: pw.FlexColumnWidth(1.4),
            4: pw.FlexColumnWidth(2.0),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _navy),
              children: [
                _cell('Option', header: true),
                _cell('Size', header: true, align: pw.Alignment.centerRight),
                _cell('Investment', header: true, align: pw.Alignment.centerRight),
                _cell('Payback', header: true, align: pw.Alignment.centerRight),
                _cell('Monthly Savings', header: true, align: pw.Alignment.centerRight),
              ],
            ),
            for (int i = 0; i < recs.length; i++)
              pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isEven ? _rowAlt : PdfColors.white),
                children: [
                  _cell('${recs[i]['label'] ?? '—'}'),
                  _cell(_kwp(recs[i]['kwp']), align: pw.Alignment.centerRight),
                  _cell(_money(recs[i]['price']), align: pw.Alignment.centerRight),
                  _cell('${recs[i]['paybackYears'] ?? '—'} yrs',
                      align: pw.Alignment.centerRight),
                  _cell(_money(recs[i]['monthlySavings']),
                      align: pw.Alignment.centerRight),
                ],
              ),
          ],
        ),
      pw.SizedBox(height: 6),
      pw.Text(
          'Indicative figures based on the inputs above. Final pricing and system '
          'sizing are confirmed after an ocular site assessment.',
          style: pw.TextStyle(
              color: _grey, fontSize: 8, fontStyle: pw.FontStyle.italic)),
    ],
  );
}

String _kwp(dynamic v) {
  if (v is num) return '${v.toStringAsFixed(2)} kWp';
  return '$v kWp';
}

String _money(dynamic v) {
  if (v is num) return _peso(v);
  final n = num.tryParse('$v');
  return n != null ? _peso(n) : '—';
}

pw.Widget _cell(String text,
    {bool header = false, pw.Alignment align = pw.Alignment.centerLeft}) {
  return pw.Container(
    alignment: align,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        color: header ? PdfColors.white : _ink,
        fontSize: header ? 9 : 9.5,
        fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget _notesBlock(String notes) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('NOTES',
          style: pw.TextStyle(
              color: _navy,
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.8)),
      pw.SizedBox(height: 3),
      pw.Container(height: 1, color: _gold),
      pw.SizedBox(height: 7),
      pw.Text(notes, style: pw.TextStyle(color: _ink, fontSize: 10.5)),
    ],
  );
}

pw.Widget _footer(ConsultationPdfData d) {
  return pw.Container(
    color: _navy,
    padding: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
            '1864 District 4A, Brgy. Marauoy, Lipa City, Batangas 4217',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5)),
        pw.SizedBox(height: 2),
        pw.Text(
            'This consultation summary is preliminary and non-binding.',
            style: pw.TextStyle(color: _gold, fontSize: 8)),
      ],
    ),
  );
}