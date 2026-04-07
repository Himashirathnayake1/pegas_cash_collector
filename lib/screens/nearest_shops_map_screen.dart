import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../utils/app_theme.dart';

class NearestShopsMapScreen extends StatefulWidget {
  final String routeName;
  final List<Map<String, dynamic>> shops;
  final Position? currentPosition;

  const NearestShopsMapScreen({
    super.key,
    required this.routeName,
    required this.shops,
    required this.currentPosition,
  });

  @override
  State<NearestShopsMapScreen> createState() => _NearestShopsMapScreenState();
}

class _NearestShopsMapScreenState extends State<NearestShopsMapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isRefreshingLocation = false;
  late List<Map<String, dynamic>> _nearestUnpaidShops;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.currentPosition;
    _nearestUnpaidShops = _buildNearestList(widget.shops, _currentPosition);

    if (_currentPosition == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshLocationAndSort(showMessageOnFail: true);
      });
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  List<Map<String, dynamic>> _buildNearestList(
    List<Map<String, dynamic>> all,
    Position? position,
  ) {
    final unpaid = all
        .where((shop) => (shop['status'] as String?) == 'Unpaid')
        .toList(growable: false);

    final withCoords = <Map<String, dynamic>>[];
    final withoutCoords = <Map<String, dynamic>>[];

    for (final shop in unpaid) {
      final lat = _toDouble(shop['latitude']);
      final lng = _toDouble(shop['longitude']);
      if (lat == null || lng == null) {
        final copy = Map<String, dynamic>.from(shop);
        copy['distanceMeters'] = null;
        withoutCoords.add(copy);
        continue;
      }

      final copy = Map<String, dynamic>.from(shop);
      if (position != null) {
        copy['distanceMeters'] = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );
      }
      copy['distanceFromPreviousMeters'] = null;
      withCoords.add(copy);
    }

    if (position != null) {
      // Build shop-wise nearest order:
      // current location -> nearest shop -> nearest to previous shop -> ...
      final ordered = <Map<String, dynamic>>[];
      final remaining = List<Map<String, dynamic>>.from(withCoords);

      var fromLat = position.latitude;
      var fromLng = position.longitude;

      while (remaining.isNotEmpty) {
        var bestIndex = 0;
        var bestDistance = double.infinity;

        for (int i = 0; i < remaining.length; i++) {
          final candidate = remaining[i];
          final lat = _toDouble(candidate['latitude']);
          final lng = _toDouble(candidate['longitude']);
          if (lat == null || lng == null) continue;

          final d = Geolocator.distanceBetween(fromLat, fromLng, lat, lng);
          if (d < bestDistance) {
            bestDistance = d;
            bestIndex = i;
          }
        }

        final nextShop = remaining.removeAt(bestIndex);
        nextShop['distanceFromPreviousMeters'] = bestDistance;
        ordered.add(nextShop);

        final nextLat = _toDouble(nextShop['latitude']);
        final nextLng = _toDouble(nextShop['longitude']);
        if (nextLat != null && nextLng != null) {
          fromLat = nextLat;
          fromLng = nextLng;
        }
      }

      withCoords
        ..clear()
        ..addAll(ordered);
    } else {
      withCoords.sort((a, b) {
        final aOrder = (a['orderNumber'] as int?) ?? 999999;
        final bOrder = (b['orderNumber'] as int?) ?? 999999;
        return aOrder.compareTo(bOrder);
      });
    }

    withoutCoords.sort((a, b) {
      final aOrder = (a['orderNumber'] as int?) ?? 999999;
      final bOrder = (b['orderNumber'] as int?) ?? 999999;
      return aOrder.compareTo(bOrder);
    });

    return [...withCoords, ...withoutCoords];
  }

  Future<void> _refreshLocationAndSort({
    required bool showMessageOnFail,
  }) async {
    setState(() {
      _isRefreshingLocation = true;
      _infoMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _infoMessage = 'Location service is off. Showing default order.';
          _isRefreshingLocation = false;
          _nearestUnpaidShops = _buildNearestList(widget.shops, null);
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _infoMessage = 'Location permission denied. Showing default order.';
          _isRefreshingLocation = false;
          _nearestUnpaidShops = _buildNearestList(widget.shops, null);
        });
        return;
      }

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = current;
        _nearestUnpaidShops = _buildNearestList(widget.shops, current);
        _isRefreshingLocation = false;
      });

      if (_nearestUnpaidShops.isNotEmpty) {
        final first = _nearestUnpaidShops.first;
        final lat = _toDouble(first['latitude']);
        final lng = _toDouble(first['longitude']);
        if (lat != null && lng != null) {
          _mapController.move(LatLng(lat, lng), 14);
        }
      }
    } catch (_) {
      setState(() {
        _infoMessage =
            'Unable to get current location now. Showing default order.';
        _isRefreshingLocation = false;
        _nearestUnpaidShops = _buildNearestList(widget.shops, null);
      });

      if (showMessageOnFail && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not fetch location. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _recalculateOrder({bool showMessage = true}) {
    if (_currentPosition == null) {
      _refreshLocationAndSort(showMessageOnFail: showMessage);
      return;
    }

    setState(() {
      _infoMessage = null;
      _nearestUnpaidShops = _buildNearestList(widget.shops, _currentPosition);
    });

    if (_nearestUnpaidShops.isNotEmpty) {
      final first = _nearestUnpaidShops.first;
      final lat = _toDouble(first['latitude']);
      final lng = _toDouble(first['longitude']);
      if (lat != null && lng != null) {
        _mapController.move(LatLng(lat, lng), 14);
      }
    }

    if (showMessage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shop order recalculated from your current position.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
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

  String _hopDistanceLabel(Map<String, dynamic> shop, int index) {
    final hopDistance = (shop['distanceFromPreviousMeters'] as num?)?.toDouble();
    if (hopDistance == null) {
      return _distanceLabel(shop['distanceMeters']);
    }

    final hop = _distanceLabel(hopDistance);
    if (index == 0 && _currentPosition != null) {
      return 'From your location: $hop';
    }

    return 'From shop $index: $hop';
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (_currentPosition != null) {
      markers.add(
        Marker(
          width: 40,
          height: 40,
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
                  color: AppColors.accentBlueDark.withOpacity(0.4),
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

    for (int i = 0; i < _nearestUnpaidShops.length; i++) {
      final shop = _nearestUnpaidShops[i];
      final lat = _toDouble(shop['latitude']);
      final lng = _toDouble(shop['longitude']);
      if (lat == null || lng == null) continue;

      markers.add(
        Marker(
          width: 44,
          height: 44,
          point: LatLng(lat, lng),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.accentTealDark,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentTealDark.withOpacity(0.45),
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

  List<LatLng> _buildPolylinePoints() {
    final points = <LatLng>[];
    if (_currentPosition != null) {
      points.add(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      );
    }

    for (final shop in _nearestUnpaidShops) {
      final lat = _toDouble(shop['latitude']);
      final lng = _toDouble(shop['longitude']);
      if (lat == null || lng == null) continue;
      points.add(LatLng(lat, lng));
    }

    return points;
  }

  LatLng _initialCenter() {
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }

    for (final shop in _nearestUnpaidShops) {
      final lat = _toDouble(shop['latitude']);
      final lng = _toDouble(shop['longitude']);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    return const LatLng(7.8731, 80.7718);
  }

  @override
  Widget build(BuildContext context) {
    final polylinePoints = _buildPolylinePoints();

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
              'Nearest Shops Map',
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
                _isRefreshingLocation ? null : () => _recalculateOrder(),
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
          IconButton(
            tooltip: 'Refresh nearest sorting',
            onPressed:
                _isRefreshingLocation
                    ? null
                    : () => _refreshLocationAndSort(showMessageOnFail: true),
            icon:
                _isRefreshingLocation
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.my_location_rounded),
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
              if (polylinePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polylinePoints,
                      strokeWidth: 4,
                      color: AppColors.accentBlueDark.withOpacity(0.65),
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
          DraggableScrollableSheet(
            initialChildSize: 0.30,
            minChildSize: 0.2,
            maxChildSize: 0.65,
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
                          Text(
                            'Nearest stop order',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_nearestUnpaidShops.length}',
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
                          _nearestUnpaidShops.isEmpty
                              ? Center(
                                child: Text(
                                  'No unpaid shops to show on map.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.lightTextSecondary,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                controller: scrollController,
                                itemCount: _nearestUnpaidShops.length,
                                itemBuilder: (context, index) {
                                  final shop = _nearestUnpaidShops[index];
                                  final lat = _toDouble(shop['latitude']);
                                  final lng = _toDouble(shop['longitude']);
                                  final canFocus = lat != null && lng != null;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.accentTealDark,
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
                                      _hopDistanceLabel(shop, index),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      tooltip:
                                          canFocus
                                              ? 'Show on map'
                                              : 'Location not available',
                                      onPressed:
                                          canFocus
                                              ? () => _mapController.move(
                                                LatLng(lat, lng),
                                                16,
                                              )
                                              : null,
                                      icon: const Icon(
                                        Icons.center_focus_strong_rounded,
                                      ),
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
