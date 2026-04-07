import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/branch_context.dart';
import '../utils/app_theme.dart';

class OsrmOptimizedRouteMapScreen extends StatefulWidget {
  final String routeId;
  final String routeName;
  final List<Map<String, dynamic>> shops;
  final Position? currentPosition;

  const OsrmOptimizedRouteMapScreen({
    super.key,
    required this.routeId,
    required this.routeName,
    required this.shops,
    required this.currentPosition,
  });

  @override
  State<OsrmOptimizedRouteMapScreen> createState() =>
      _OsrmOptimizedRouteMapScreenState();
}

class _OsrmOptimizedRouteMapScreenState
    extends State<OsrmOptimizedRouteMapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isBusy = false;
  String? _infoMessage;

  List<Map<String, dynamic>> _optimizedUnpaidShops = [];
  List<LatLng> _roadPolylinePoints = [];

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.currentPosition;
    _optimizedUnpaidShops = _extractUnpaidWithCoords(widget.shops);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _optimizeRouteWithOsrm(showMessageOnFail: true);
    });
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  List<Map<String, dynamic>> _extractUnpaidWithCoords(
    List<Map<String, dynamic>> all,
  ) {
    final unpaid =
        all
            .where((shop) => (shop['status'] as String?) == 'Unpaid')
            .map((shop) => Map<String, dynamic>.from(shop))
            .toList();

    unpaid.sort((a, b) {
      final aOrder = (a['orderNumber'] as int?) ?? 999999;
      final bOrder = (b['orderNumber'] as int?) ?? 999999;
      return aOrder.compareTo(bOrder);
    });

    return unpaid;
  }

  Future<Position?> _ensureCurrentLocation() async {
    if (_currentPosition != null) {
      return _currentPosition;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _infoMessage =
            'Location service is off. Showing default unpaid shop order.';
      });
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _infoMessage =
            'Location permission denied. Showing default unpaid shop order.';
      });
      return null;
    }

    final current = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = current;
    });

    return current;
  }

  Future<void> _optimizeRouteWithOsrm({required bool showMessageOnFail}) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      _infoMessage = null;
    });

    try {
      final current = await _ensureCurrentLocation();
      final unpaid =
          _extractUnpaidWithCoords(widget.shops)
              .where(
                (shop) =>
                    _toDouble(shop['latitude']) != null &&
                    _toDouble(shop['longitude']) != null,
              )
              .toList();

      if (current == null || unpaid.isEmpty) {
        setState(() {
          _optimizedUnpaidShops = _extractUnpaidWithCoords(widget.shops);
          _roadPolylinePoints = _buildStraightPolyline(_optimizedUnpaidShops);
          _isBusy = false;
        });
        return;
      }

      if (unpaid.length == 1) {
        final only = unpaid.first;
        only['distanceFromPreviousMeters'] = Geolocator.distanceBetween(
          current.latitude,
          current.longitude,
          _toDouble(only['latitude'])!,
          _toDouble(only['longitude'])!,
        );

        setState(() {
          _optimizedUnpaidShops = [only];
          _roadPolylinePoints = [
            LatLng(current.latitude, current.longitude),
            LatLng(_toDouble(only['latitude'])!, _toDouble(only['longitude'])!),
          ];
          _isBusy = false;
        });
        return;
      }

      final optimized = await _requestOsrmTrip(
        currentPosition: current,
        shopsWithCoords: unpaid,
      );

      setState(() {
        _optimizedUnpaidShops = optimized.shops;
        _roadPolylinePoints = optimized.polyline;
        _isBusy = false;
      });

      if (_optimizedUnpaidShops.isNotEmpty) {
        final first = _optimizedUnpaidShops.first;
        final lat = _toDouble(first['latitude']);
        final lng = _toDouble(first['longitude']);
        if (lat != null && lng != null) {
          _mapController.move(LatLng(lat, lng), 14);
        }
      }
    } catch (_) {
      setState(() {
        _optimizedUnpaidShops = _extractUnpaidWithCoords(widget.shops);
        _roadPolylinePoints = _buildStraightPolyline(_optimizedUnpaidShops);
        _infoMessage =
            'Could not optimize route now. Showing default unpaid order.';
        _isBusy = false;
      });

      if (showMessageOnFail && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route optimization failed. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<_OsrmResult> _requestOsrmTrip({
    required Position currentPosition,
    required List<Map<String, dynamic>> shopsWithCoords,
  }) async {
    final points = <LatLng>[
      LatLng(currentPosition.latitude, currentPosition.longitude),
      ...shopsWithCoords.map(
        (shop) =>
            LatLng(_toDouble(shop['latitude'])!, _toDouble(shop['longitude'])!),
      ),
    ];

    final coordinates = points
        .map(
          (p) =>
              '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
        )
        .join(';');

    final uri = Uri.parse(
      'https://router.project-osrm.org/trip/v1/driving/$coordinates'
      '?source=first&roundtrip=false&steps=false&overview=full&geometries=geojson',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('OSRM request failed with ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final code = data['code']?.toString();
    if (code != 'Ok') {
      throw Exception('OSRM code: $code');
    }

    final trips = (data['trips'] as List?) ?? const [];
    if (trips.isEmpty) {
      throw Exception('No optimized trip found');
    }

    final waypoints = (data['waypoints'] as List?) ?? const [];
    if (waypoints.isEmpty) {
      throw Exception('No waypoint ordering found');
    }

    final indexToWaypoint = <int, int>{};
    for (int i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i] as Map<String, dynamic>;
      final waypointIndex = (wp['waypoint_index'] as num?)?.toInt();
      if (waypointIndex != null) {
        indexToWaypoint[i] = waypointIndex;
      }
    }

    final orderedShops = <Map<String, dynamic>>[];
    for (int i = 0; i < shopsWithCoords.length; i++) {
      final inputIndex = i + 1;
      final waypointOrder = indexToWaypoint[inputIndex] ?? 999999;
      final copy = Map<String, dynamic>.from(shopsWithCoords[i]);
      copy['_waypointOrder'] = waypointOrder;
      orderedShops.add(copy);
    }

    orderedShops.sort((a, b) {
      final aOrder = (a['_waypointOrder'] as int?) ?? 999999;
      final bOrder = (b['_waypointOrder'] as int?) ?? 999999;
      return aOrder.compareTo(bOrder);
    });

    final trip = trips.first as Map<String, dynamic>;
    final legs = (trip['legs'] as List?) ?? const [];

    for (int i = 0; i < orderedShops.length; i++) {
      if (i < legs.length) {
        final leg = legs[i] as Map<String, dynamic>;
        orderedShops[i]['distanceFromPreviousMeters'] =
            (leg['distance'] as num?)?.toDouble();
      }
    }

    final geometry = trip['geometry'] as Map<String, dynamic>?;
    final coordinatesList = (geometry?['coordinates'] as List?) ?? const [];
    final polyline =
        coordinatesList
            .map((item) {
              if (item is List && item.length >= 2) {
                final lng = (item[0] as num).toDouble();
                final lat = (item[1] as num).toDouble();
                return LatLng(lat, lng);
              }
              return null;
            })
            .whereType<LatLng>()
            .toList();

    return _OsrmResult(shops: orderedShops, polyline: polyline);
  }

  List<LatLng> _buildStraightPolyline(List<Map<String, dynamic>> shops) {
    final points = <LatLng>[];
    if (_currentPosition != null) {
      points.add(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      );
    }

    for (final shop in shops) {
      final lat = _toDouble(shop['latitude']);
      final lng = _toDouble(shop['longitude']);
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }

    return points;
  }

  Future<void> _markShopPaidAndRecalculate(Map<String, dynamic> shop) async {
    final shopId = (shop['id'] ?? '').toString();
    if (shopId.isEmpty) return;

    final branchId = BranchContext().branchId;
    if (branchId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Branch not available. Please re-login and try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isBusy = true);

    try {
      await FirebaseFirestore.instance
          .collection('branches')
          .doc(branchId)
          .collection('routes')
          .doc(widget.routeId)
          .collection('shops')
          .doc(shopId)
          .update({'status': 'Paid', 'paidAt': FieldValue.serverTimestamp()});

      final currentShops =
          widget.shops.map((s) => Map<String, dynamic>.from(s)).toList();
      for (int i = 0; i < currentShops.length; i++) {
        if ((currentShops[i]['id'] ?? '').toString() == shopId) {
          currentShops[i]['status'] = 'Paid';
          break;
        }
      }

      setState(() {
        widget.shops
          ..clear()
          ..addAll(currentShops);
      });

      await _optimizeRouteWithOsrm(showMessageOnFail: false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${shop['name'] ?? 'Shop'} marked as Paid. Route recalculated.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      setState(() => _isBusy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not mark shop as Paid. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _distanceLabel(dynamic distanceMeters) {
    final value = (distanceMeters as num?)?.toDouble();
    if (value == null) return 'Distance N/A';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)} km';
    return '${value.toStringAsFixed(0)} m';
  }

  LatLng _initialCenter() {
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }

    for (final shop in _optimizedUnpaidShops) {
      final lat = _toDouble(shop['latitude']);
      final lng = _toDouble(shop['longitude']);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    return const LatLng(7.8731, 80.7718);
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (_currentPosition != null) {
      markers.add(
        Marker(
          width: 42,
          height: 42,
          point: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.accentBlueDark,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentBlueDark.withOpacity(0.35),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      );
    }

    for (int i = 0; i < _optimizedUnpaidShops.length; i++) {
      final shop = _optimizedUnpaidShops[i];
      final lat = _toDouble(shop['latitude']);
      final lng = _toDouble(shop['longitude']);
      if (lat == null || lng == null) continue;

      markers.add(
        Marker(
          width: 46,
          height: 46,
          point: LatLng(lat, lng),
          child: Container(
            decoration: BoxDecoration(
              color: i == 0 ? AppColors.success : AppColors.accentTealDark,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: (i == 0 ? AppColors.success : AppColors.accentTealDark)
                      .withOpacity(0.4),
                  blurRadius: 10,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${i + 1}',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Optimized Route Map',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.lightTextPrimary,
              ),
            ),
            Text(
              widget.routeName,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed:
                _isBusy
                    ? null
                    : () => _optimizeRouteWithOsrm(showMessageOnFail: true),
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: Text(
              'Recalculate',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentBlueDark,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter(),
              initialZoom: 13,
              minZoom: 4,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.pegas_cashcollector',
              ),
              if (_roadPolylinePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _roadPolylinePoints,
                      strokeWidth: 4,
                      color: AppColors.accentBlueDark.withOpacity(0.68),
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          if (_infoMessage != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEFD6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4C07A)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF925D00),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _infoMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF925D00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isBusy)
            Positioned(
              top: _infoMessage == null ? 12 : 72,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Optimizing route...',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: 0.34,
            minChildSize: 0.22,
            maxChildSize: 0.72,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.lightTextMuted.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'OSRM optimized unpaid order',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${_optimizedUnpaidShops.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentTealDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          _optimizedUnpaidShops.isEmpty
                              ? Center(
                                child: Text(
                                  'No unpaid shops available for optimization.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.lightTextSecondary,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                controller: scrollController,
                                itemCount: _optimizedUnpaidShops.length,
                                itemBuilder: (context, index) {
                                  final shop = _optimizedUnpaidShops[index];
                                  final lat = _toDouble(shop['latitude']);
                                  final lng = _toDouble(shop['longitude']);

                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor:
                                          index == 0
                                              ? AppColors.success
                                              : AppColors.accentTealDark,
                                      child: Text(
                                        '${index + 1}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      (shop['name'] ?? 'Unknown shop')
                                          .toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      index == 0
                                          ? 'From your location: ${_distanceLabel(shop['distanceFromPreviousMeters'])}'
                                          : 'From previous shop: ${_distanceLabel(shop['distanceFromPreviousMeters'])}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Show on map',
                                          onPressed:
                                              (lat != null && lng != null)
                                                  ? () => _mapController.move(
                                                    LatLng(lat, lng),
                                                    16,
                                                  )
                                                  : null,
                                          icon: const Icon(
                                            Icons.center_focus_strong_rounded,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Mark Paid',
                                          onPressed:
                                              _isBusy
                                                  ? null
                                                  : () =>
                                                      _markShopPaidAndRecalculate(
                                                        shop,
                                                      ),
                                          icon: const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OsrmResult {
  final List<Map<String, dynamic>> shops;
  final List<LatLng> polyline;

  const _OsrmResult({required this.shops, required this.polyline});
}
