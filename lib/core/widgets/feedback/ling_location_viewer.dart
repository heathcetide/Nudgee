import 'package:flutter/material.dart';

import 'package:nudgee/core/widgets/feedback/ling_web_view_page.dart';

/// A full-screen map viewer for a location message.
///
/// Shows a static map thumbnail using AMap static map API,
/// with a button to open the full interactive map in a WebView.
class LingLocationViewer extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String locationName;

  const LingLocationViewer({
    super.key,
    required this.latitude,
    required this.longitude,
    this.locationName = '位置',
  });

  String get _staticMapUrl {
    // OSM static map (free, no API key needed)
    return 'https://staticmap.openstreetmap.de/staticmap.php'
        '?center=$latitude,$longitude'
        '&zoom=16'
        '&size=600*400'
        '&markers=$latitude,$longitude,red-pushpin';
  }

  String get _amapWebUrl {
    // AMap web map URL — opens interactive map
    return 'https://uri.amap.com/marker'
        '?position=$longitude,$latitude'
        '&name=${Uri.encodeComponent(locationName)}'
        '&coordinate=wgs84'
        '&callnative=0';
  }

  String get _googleMapsUrl {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(locationName),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openInMapApp(context),
            tooltip: '在地图中打开',
          ),
        ],
      ),
      body: Column(
        children: [
          // Static map preview
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () => _openWebView(context),
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Try loading static map, fallback to icon
                    Image.network(
                      _staticMapUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_outlined,
                                size: 80,
                                color: theme.colorScheme.outline),
                            const SizedBox(height: 8),
                            Text(
                              '点击查看地图',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.cumulativeBytesLoaded /
                                (progress.expectedTotalBytes ?? 1),
                          ),
                        );
                      },
                    ),
                    // Pin overlay
                    Positioned(
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Location info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locationName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '纬度: ${latitude.toStringAsFixed(6)}\n'
                    '经度: ${longitude.toStringAsFixed(6)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openWebView(context),
                          icon: const Icon(Icons.map),
                          label: const Text('查看地图'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openInMapApp(context),
                          icon: const Icon(Icons.navigation),
                          label: const Text('导航'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openWebView(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LingWebViewPage(
          url: _amapWebUrl,
          title: locationName,
        ),
      ),
    );
  }

  void _openInMapApp(BuildContext context) {
    // Try AMap URI scheme first, fallback to web URL
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LingWebViewPage(
          url: _amapWebUrl,
          title: '地图',
        ),
      ),
    );
  }
}
