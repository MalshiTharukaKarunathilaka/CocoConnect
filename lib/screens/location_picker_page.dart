import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';

const Color _green = Color(0xFF256B45);
const Color _red = Color(0xFFC62828);

/// Opens the map and returns the place the user confirmed, or null.
Future<PickedLocation?> pickLocation(
  BuildContext context, {
  PickedLocation? initial,
}) {
  return Navigator.push<PickedLocation>(
    context,
    MaterialPageRoute(
      builder: (context) => LocationPickerPage(initial: initial),
    ),
  );
}

/// Full-screen OpenStreetMap with a pin in the middle: drag the map, search
/// a town, or jump to the phone's current location.
class LocationPickerPage extends StatefulWidget {
  final PickedLocation? initial;

  const LocationPickerPage({super.key, this.initial});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _map = MapController();
  final _searchController = TextEditingController();

  late LatLng _center = widget.initial == null
      ? const LatLng(
          LocationService.defaultLatitude,
          LocationService.defaultLongitude,
        )
      : LatLng(widget.initial!.latitude, widget.initial!.longitude);
  late String? _name = widget.initial?.name;

  Timer? _lookup;
  bool _naming = false;
  bool _locating = false;
  bool _searching = false;
  List<PickedLocation> _results = const [];

  @override
  void initState() {
    super.initState();
    // Nothing picked yet: start where the phone is, if it will say.
    if (widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _useCurrentLocation(quiet: true);
      });
    }
  }

  @override
  void dispose() {
    _lookup?.cancel();
    _searchController.dispose();
    _map.dispose();
    super.dispose();
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: _red));
  }

  void _moveTo(LatLng point, {double zoom = 14, String? name}) {
    _map.move(point, zoom);
    setState(() {
      _center = point;
      _results = const [];
    });
    if (name != null) {
      _lookup?.cancel();
      setState(() => _name = name);
    } else {
      _nameSoon();
    }
  }

  /// Looks up the place name once the map stops moving.
  void _nameSoon() {
    _lookup?.cancel();
    setState(() => _naming = true);
    _lookup = Timer(const Duration(milliseconds: 800), () async {
      final LatLng point = _center;
      final String? name = await LocationService.placeName(
        point.latitude,
        point.longitude,
      );
      if (!mounted || point != _center) return;
      setState(() {
        _name = name;
        _naming = false;
      });
    });
  }

  Future<void> _useCurrentLocation({bool quiet = false}) async {
    setState(() => _locating = true);
    try {
      final position = await LocationService.currentPosition();
      if (!mounted) return;
      _moveTo(LatLng(position.latitude, position.longitude), zoom: 15);
    } on LocationProblem catch (problem) {
      if (mounted && !quiet) _showError(problem.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final List<PickedLocation> found = await LocationService.search(
      _searchController.text,
    );
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = found;
    });
    if (found.isEmpty) _showError('No places found for that search');
  }

  void _confirm() {
    Navigator.pop(
      context,
      PickedLocation(
        name:
            _name ??
            '${_center.latitude.toStringAsFixed(4)}, '
                '${_center.longitude.toStringAsFixed(4)}',
        latitude: _center.latitude,
        longitude: _center.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial == null ? 7.5 : 14,
              onPositionChanged: (camera, hasGesture) {
                _center = camera.center;
                if (hasGesture) _nameSoon();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.kapconnect_mobile',
              ),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),

          // The pin's tip marks the centre of the map.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on, size: 48, color: _red),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                children: [
                  Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(14),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _search(),
                            decoration: const InputDecoration(
                              hintText: 'Search a town, e.g. Kurunegala',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        _searching
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _green,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search, color: _green),
                                onPressed: _search,
                              ),
                      ],
                    ),
                  ),
                  if (_results.isNotEmpty)
                    Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(14),
                      child: Column(
                        children: [
                          for (final place in _results)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined),
                              title: Text(place.name),
                              onTap: () => _moveTo(
                                LatLng(place.latitude, place.longitude),
                                name: place.name,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Drag the map to put the pin on your place',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.place, color: _green, size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _naming
                                  ? 'Finding place name...'
                                  : _name ?? 'Unnamed place',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _locating ? null : _useCurrentLocation,
                        icon: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location, size: 18),
                        label: const Text('Use my current location'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _green,
                          side: const BorderSide(color: _green),
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _naming ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Confirm Location'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
