import 'package:flutter/material.dart';
import '../../core/models/ui_models.dart';
import '../../core/ui/states/state_view.dart';
import '../../theme/app_tokens.dart';

class IndoorNavigationScreen extends StatefulWidget {
  const IndoorNavigationScreen({super.key});

  @override
  State<IndoorNavigationScreen> createState() => _IndoorNavigationScreenState();
}

class _IndoorNavigationScreenState extends State<IndoorNavigationScreen> {
  NavigationViewState _state = NavigationViewState.setup;
  bool _accessibleRoute = false;
  String _start = 'Hall of Ancestors';
  String _destination = 'Textiles Gallery';

  UiRoutePreview get _preview => UiRoutePreview(
        start: _start,
        destination: _destination,
        etaLabel: '2 min walk',
        distanceLabel: '120m',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      appBar: AppBar(
        title: const Text('Museum Map'),
        actions: [
          PopupMenuButton<NavigationViewState>(
            onSelected: (v) => setState(() => _state = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: NavigationViewState.setup, child: Text('Setup')),
              PopupMenuItem(value: NavigationViewState.preview, child: Text('Preview')),
              PopupMenuItem(value: NavigationViewState.active, child: Text('Active')),
              PopupMenuItem(value: NavigationViewState.rerouting, child: Text('Rerouting')),
              PopupMenuItem(value: NavigationViewState.unavailable, child: Text('Unavailable')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(label: 'Map can continue with last known route in offline mode'),
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(child: _MapPattern()),
                if (_state == NavigationViewState.setup)
                  _SetupPanel(
                    start: _start,
                    destination: _destination,
                    accessibleRoute: _accessibleRoute,
                    onStartChanged: (v) => setState(() => _start = v),
                    onDestinationChanged: (v) => setState(() => _destination = v),
                    onAccessibleChanged: (v) => setState(() => _accessibleRoute = v),
                    onPreview: () => setState(() => _state = NavigationViewState.preview),
                  ),
                if (_state == NavigationViewState.preview)
                  _RoutePreviewCard(
                    preview: _preview,
                    accessibleRoute: _accessibleRoute,
                    onStart: () => setState(() => _state = NavigationViewState.active),
                  ),
                if (_state == NavigationViewState.active)
                  _ActiveNavCard(
                    preview: _preview,
                    onReRoute: () => setState(() => _state = NavigationViewState.rerouting),
                  ),
                if (_state == NavigationViewState.rerouting)
                  const Align(
                    alignment: Alignment.center,
                    child: StateView(
                      icon: Icons.sync,
                      title: 'Rerouting...',
                      message: 'Finding the best path based on your current location.',
                    ),
                  ),
                if (_state == NavigationViewState.unavailable)
                  Align(
                    alignment: Alignment.center,
                    child: AppErrorState(
                      title: 'Route Unavailable',
                      message: 'Please choose a different destination.',
                      onAction: () => setState(() => _state = NavigationViewState.setup),
                    ),
                  ),
                if (_state == NavigationViewState.active || _state == NavigationViewState.preview)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _DestinationSheet(preview: _preview),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({
    required this.start,
    required this.destination,
    required this.accessibleRoute,
    required this.onStartChanged,
    required this.onDestinationChanged,
    required this.onAccessibleChanged,
    required this.onPreview,
  });

  final String start;
  final String destination;
  final bool accessibleRoute;
  final ValueChanged<String> onStartChanged;
  final ValueChanged<String> onDestinationChanged;
  final ValueChanged<bool> onAccessibleChanged;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FieldDropdown(
              label: 'Start',
              value: start,
              values: const ['Hall of Ancestors', 'Museum Entrance', 'Workshop Hall'],
              onChanged: onStartChanged,
            ),
            const SizedBox(height: 10),
            _FieldDropdown(
              label: 'Destination',
              value: destination,
              values: const ['Textiles Gallery', 'Pottery Room', 'Cafe'],
              onChanged: onDestinationChanged,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: accessibleRoute,
              onChanged: onAccessibleChanged,
              title: const Text('Accessible route preference'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPreview,
                child: const Text('Preview Route'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldDropdown extends StatelessWidget {
  const _FieldDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: values.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _RoutePreviewCard extends StatelessWidget {
  const _RoutePreviewCard({
    required this.preview,
    required this.accessibleRoute,
    required this.onStart,
  });

  final UiRoutePreview preview;
  final bool accessibleRoute;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${preview.start} → ${preview.destination}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('${preview.etaLabel} • ${preview.distanceLabel}'),
            const SizedBox(height: 4),
            Text(accessibleRoute ? 'Accessible path selected' : 'Standard path selected'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStart,
                child: const Text('Start Navigation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveNavCard extends StatelessWidget {
  const _ActiveNavCard({required this.preview, required this.onReRoute});
  final UiRoutePreview preview;
  final VoidCallback onReRoute;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF5D4037),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(Icons.near_me, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Head to ${preview.destination} • ${preview.etaLabel}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: onReRoute,
              child: const Text('Reroute', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationSheet extends StatelessWidget {
  const _DestinationSheet({required this.preview});
  final UiRoutePreview preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.destination,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text('Traditional textile exhibit with interactive AR overlays.'),
          const SizedBox(height: 6),
          Text('${preview.etaLabel} • Nearby: Restroom, Exit'),
        ],
      ),
    );
  }
}

class _MapPattern extends StatelessWidget {
  const _MapPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE6DCCA)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
