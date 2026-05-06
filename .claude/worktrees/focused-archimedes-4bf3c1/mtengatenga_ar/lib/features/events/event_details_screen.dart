import 'package:flutter/material.dart';
import '../../core/models/ui_models.dart';
import '../../theme/app_tokens.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.item});
  final UiEventItem item;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _reminder = true;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Event Details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (item.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: 220,
                child: Image.network(item.imageUrl, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '${item.dateLabel} • ${item.location}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Text(item.description, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 14),
          SwitchListTile(
            value: _reminder,
            onChanged: (v) => setState(() => _reminder = v),
            title: const Text('Add reminder'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.event_available),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
