import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_search_utils.dart';
import '../../../core/utils/velthuis.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/search_box_decoration.dart';
import '../models/map_data.dart';
import '../providers/map_data_provider.dart';
import '../widgets/map_geometry.dart';
import '../widgets/map_painter.dart';
import '../widgets/name_type_icon.dart';
import '../widgets/place_picker_sheet.dart';

/// The map of the places of the texts.
///
/// Every located name is drawn as a dot. Dots that overlap are merged into one
/// cluster showing how many names are there; tapping the cluster opens a list
/// to pick from, so a single spot with several places never silently opens the
/// wrong one.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.placeSlug});

  /// A place to centre the map on when it opens (used by the dictionary card).
  final String? placeSlug;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapGeometry? _geometry;
  Size _viewport = Size.zero;
  double _scale = 1;
  double _fitScale = 1;
  Offset _offset = Offset.zero;
  bool _cameraReady = false;

  Offset? _gestureStartWorld;
  double _gestureStartScale = 1;
  List<MapCluster> _clusters = const [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// The names whose name or inflected forms match what was typed.
  ///
  /// Velthuis typing is converted by the shared formatter, and both sides are
  /// folded to plain letters, so `savatthi` also finds `sāvatthī`. Located
  /// names come first, but people, deities, animals and groups are found too —
  /// they have a page of their own even though they have no marker.
  List<MapName> _searchResults(MapData data) {
    final query = normalizePaliFuzzy(_searchController.text);
    if (query.isEmpty) return const [];
    final located = <MapName>[];
    final unlocated = <MapName>[];
    for (final name in data.all) {
      final haystack = normalizePaliFuzzy(name.name);
      final hit =
          haystack.contains(query) ||
          name.forms.any((f) => normalizePaliFuzzy(f).contains(query));
      if (!hit) continue;
      (name is MapPlace ? located : unlocated).add(name);
      if (located.length + unlocated.length >= 30) break;
    }
    return [...located, ...unlocated];
  }

  void _focusPlace(MapGeometry geometry, MapPlace place) {
    final size = _viewport;
    if (size == Size.zero) return;
    setState(() {
      _scale = _fitScale * 8;
      final world = geometry.project(place.lon, place.lat);
      _offset = size.center(Offset.zero) - world * _scale;
      _clampOffset(size, geometry);
    });
  }

  void _openSearchResult(MapGeometry geometry, MapName name) {
    _searchFocus.unfocus();
    _searchController.clear();
    if (name is MapPlace) _focusPlace(geometry, name);
    context.push(AppRoutes.mapPlaceAt(name.slug));
  }

  Widget _buildSearchOverlay(
    BuildContext context,
    MapData data,
    MapGeometry geometry,
  ) {
    final loc = AppLocalizations.of(context);
    final results = _searchResults(data);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            textInputAction: TextInputAction.search,
            inputFormatters: const [VelthuisInputFormatter()],
            decoration: searchBoxDecoration(
              context,
              hintText: loc.t('Search places'),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (results.isNotEmpty) {
                _openSearchResult(geometry, results.first);
              }
            },
          ),
        ),
        if (_searchController.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(loc.t('No places found')),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final name = results[index];
                          final subtitle = name.family.isNotEmpty
                              ? name.family
                              : name.meaning;
                          return ListTile(
                            dense: true,
                            leading: Icon(mapNameIcon(name.type)),
                            title: Text(name.name),
                            subtitle: subtitle.isEmpty
                                ? null
                                : Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => _openSearchResult(geometry, name),
                          );
                        },
                      ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeSlug != widget.placeSlug) {
      _cameraReady = false;
    }
  }

  void _fitMap(Size size, MapGeometry geometry, {MapPlace? focus}) {
    final fit = math.min(
      size.width / geometry.worldSize.width,
      size.height / geometry.worldSize.height,
    );
    _fitScale = fit;
    if (focus == null) {
      _scale = fit;
      _offset = Offset(
        (size.width - geometry.worldSize.width * fit) / 2,
        (size.height - geometry.worldSize.height * fit) / 2,
      );
    } else {
      _scale = fit * 6;
      final world = geometry.project(focus.lon, focus.lat);
      _offset = size.center(Offset.zero) - world * _scale;
    }
    _clampOffset(size, geometry);
  }

  void _clampOffset(Size size, MapGeometry geometry) {
    final width = geometry.worldSize.width * _scale;
    final height = geometry.worldSize.height * _scale;
    const margin = 120.0;
    double dx;
    double dy;
    if (width <= size.width) {
      dx = (size.width - width) / 2;
    } else {
      dx = _offset.dx.clamp(size.width - width - margin, margin);
    }
    if (height <= size.height) {
      dy = (size.height - height) / 2;
    } else {
      dy = _offset.dy.clamp(size.height - height - margin, margin);
    }
    _offset = Offset(dx, dy);
  }

  void _zoomAround(Offset focal, double factor) {
    final geometry = _geometry;
    if (geometry == null || _viewport == Size.zero) return;
    final maxScale = _fitScale * 40;
    final newScale = (_scale * factor).clamp(_fitScale * 0.9, maxScale);
    final world = (focal - _offset) / _scale;
    setState(() {
      _scale = newScale;
      _offset = focal - world * newScale;
      _clampOffset(_viewport, geometry);
    });
  }

  void _handleTap(Offset local) {
    final hits = <MapPlace>[];
    for (final cluster in _clusters) {
      if ((cluster.center - local).distance <= 26) {
        for (final place in cluster.places) {
          if (!hits.any((p) => p.slug == place.slug)) hits.add(place);
        }
      }
    }
    if (hits.isEmpty) return;
    if (hits.length == 1) {
      context.push(AppRoutes.mapPlaceAt(hits.first.slug));
      return;
    }
    // A stable, readable order for the list — the marker order is by slug.
    hits.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    showPlacePickerSheet(context, places: hits).then((picked) {
      if (picked != null && mounted) {
        context.push(AppRoutes.mapPlaceAt(picked.slug));
      }
    });
  }

  void _showSources(String sources) {
    final loc = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('Sources of the map')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.t(
                  'The code is ported from the tipitaka.app with some adjustments.',
                ),
              ),
              const SizedBox(height: 12),
              Text(sources),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(loc.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final dataAsync = ref.watch(mapDataProvider);
    // When the map is opened for one name (from the dictionary or a place
    // page), name it in the title instead of the generic "Map".
    final focusedName = widget.placeSlug == null
        ? null
        : dataAsync.valueOrNull?.nameBySlug(widget.placeSlug!);

    return Scaffold(
      appBar: AppBar(
        title: Text(focusedName?.name ?? loc.t('Map')),
        actions: [
          IconButton(
            tooltip: loc.t('Names of the texts'),
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: () => context.push(AppRoutes.mapNames),
          ),
          IconButton(
            tooltip: loc.t('Zoom in'),
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _zoomAround(_viewport.center(Offset.zero), 1.5),
          ),
          IconButton(
            tooltip: loc.t('Zoom out'),
            icon: const Icon(Icons.zoom_out),
            onPressed: () =>
                _zoomAround(_viewport.center(Offset.zero), 1 / 1.5),
          ),
          IconButton(
            tooltip: loc.t('Show the whole map'),
            icon: const Icon(Icons.fit_screen_outlined),
            onPressed: () {
              final geometry = _geometry;
              if (geometry == null) return;
              setState(() {
                _cameraReady = false;
                _fitMap(_viewport, geometry);
                _cameraReady = true;
              });
            },
          ),
          IconButton(
            tooltip: loc.t('Sources of the map'),
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              final geometry = _geometry;
              if (geometry != null) _showSources(geometry.basemap.sources);
            },
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(loc.t('Loading the map…')),
            ],
          ),
        ),
        error: (_, _) =>
            Center(child: Text(loc.t('The map could not be loaded.'))),
        data: (data) => LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final geometry = _geometry ??= MapGeometry.build(data.basemap);
            _viewport = size;
            if (!_cameraReady) {
              final focus = widget.placeSlug == null
                  ? null
                  : data.placeBySlug(widget.placeSlug!);
              _fitMap(size, geometry, focus: focus);
              _cameraReady = true;
            }
            return Stack(
              children: [
                Positioned.fill(
                  child: _buildMap(context, data.places, geometry, size),
                ),
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _buildSearchOverlay(context, data, geometry),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    List<MapPlace> places,
    MapGeometry geometry,
    Size size,
  ) {
    _clusters = buildMapClusters(
      places: places,
      geometry: geometry,
      scale: _scale,
      offset: _offset,
      viewport: size,
    );
    final labels = _scale > _fitScale * 3;
    final palette = MapPalette.of(Theme.of(context).brightness);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTap(details.localPosition),
      onScaleStart: (details) {
        _gestureStartScale = _scale;
        _gestureStartWorld = (details.localFocalPoint - _offset) / _scale;
      },
      onScaleUpdate: (details) {
        final start = _gestureStartWorld;
        if (start == null) return;
        final maxScale = _fitScale * 40;
        final newScale = (_gestureStartScale * details.scale).clamp(
          _fitScale * 0.9,
          maxScale,
        );
        setState(() {
          _scale = newScale;
          _offset = details.localFocalPoint - start * newScale;
          _clampOffset(size, geometry);
        });
      },
      onDoubleTapDown: (details) => _zoomAround(details.localPosition, 1.8),
      onDoubleTap: () {},
      child: CustomPaint(
        size: size,
        painter: MapPainter(
          geometry: geometry,
          scale: _scale,
          offset: _offset,
          palette: palette,
          clusters: _clusters,
          showLabels: labels,
        ),
      ),
    );
  }
}
