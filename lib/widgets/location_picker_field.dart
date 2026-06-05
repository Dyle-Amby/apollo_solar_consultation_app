// lib/widgets/location_picker_field.dart
//
// Inline, interactive map for Step 1 (no separate screen). The agent taps
// the map to drop/move a pin, or taps "Use my location". The pin's
// coordinates are written straight into ConsultationData, and the address is
// reverse-geocoded from OpenStreetMap's Nominatim (best-effort) and pushed
// back to Step 1 via onPicked so the address field stays in sync.
//
// Requires in pubspec.yaml:
//   flutter_map: ^7.0.2
//   latlong2: ^0.9.1
//   geolocator: ^13.0.1
// And Android location permissions in AndroidManifest.xml.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';

const _navy = Color(0xFF1A2A6C);
const _gold = Color(0xFFC8A200);
const _grey = Color(0xFF888888);

// Default to Lipa City, Batangas when there's no existing pin.
const LatLng _kDefaultCenter = LatLng(13.9411, 121.1622);

class LocationPickerField extends StatefulWidget {
  final ConsultationData data;
  final VoidCallback? onPicked; // called after the address updates

  const LocationPickerField({Key? key, required this.data, this.onPicked})
      : super(key: key);

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  final MapController _map = MapController();
  LatLng? _pin;
  bool _locating = false;
  bool _geocoding = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.latitude != 0 || widget.data.longitude != 0) {
      _pin = LatLng(widget.data.latitude, widget.data.longitude);
    }
  }

  LatLng get _center => _pin ?? _kDefaultCenter;

  void _setPin(LatLng p) {
    setState(() => _pin = p);
    widget.data.latitude = p.latitude;
    widget.data.longitude = p.longitude;
    _reverseGeocode(p);
  }

  Future<void> _reverseGeocode(LatLng p) async {
    setState(() => _geocoding = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&lat=${p.latitude}&lon=${p.longitude}',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'ApolloSolarConsultation/1.0 (apollosolarventures.com)',
      }).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final name = d is Map ? d['display_name'] : null;
        if (name is String && name.isNotEmpty) {
          widget.data.address = name;
          if (mounted) widget.onPicked?.call();
        }
      }
    } catch (_) {
      // best-effort; coordinates are saved regardless of geocode success
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _toast('Turn on location services to use this.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _toast('Location permission denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final p = LatLng(pos.latitude, pos.longitude);
      _map.move(p, 17);
      _setPin(p);
    } catch (_) {
      _toast('Could not get your location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.map_outlined, size: 16, color: _navy),
            const SizedBox(width: 6),
            const Text('Pin Site Location',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
            const Spacer(),
            TextButton.icon(
              onPressed: _locating ? null : _useMyLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _navy))
                  : const Icon(Icons.my_location, size: 16, color: _navy),
              label: const Text('Use my location',
                  style: TextStyle(fontSize: 12, color: _navy)),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: Size.zero),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 240,
            width: double.infinity,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _pin != null ? 17 : 13,
                    onTap: (_, latlng) => _setPin(latlng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.apollosolar.consultation',
                    ),
                    if (_pin != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pin!,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(Icons.location_on, color: _gold, size: 44),
                          ),
                        ],
                      ),
                  ],
                ),
                if (_pin == null)
                  Positioned(
                    top: 8, left: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)],
                      ),
                      child: const Text('Tap the map to drop a pin',
                          style: TextStyle(fontSize: 12, color: _navy)),
                    ),
                  ),
                if (_geocoding)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)],
                      ),
                      child: const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _navy)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _pin == null
              ? 'No location pinned yet'
              : '${_pin!.latitude.toStringAsFixed(5)}, ${_pin!.longitude.toStringAsFixed(5)}  ·  tap to move the pin',
          style: const TextStyle(fontSize: 11.5, color: _grey),
        ),
      ],
    );
  }
}