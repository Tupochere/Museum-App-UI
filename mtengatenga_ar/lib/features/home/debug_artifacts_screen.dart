import 'package:flutter/material.dart';

import '../../core/domain/entities/artifact.model.dart';
import '../../core/domain/repositories/artifact_repository.dart';
import '../../core/services/service_locator.dart';

class DebugArtifactsScreen extends StatefulWidget {
  const DebugArtifactsScreen({super.key});

  @override
  State<DebugArtifactsScreen> createState() => _DebugArtifactsScreenState();
}

class _DebugArtifactsScreenState extends State<DebugArtifactsScreen> {
  List<Artifact> _artifacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArtifacts();
  }

  Future<void> _loadArtifacts() async {
    try {
      final repo = ServiceLocator.instance<IArtifactRepository>();
      final artifacts = await repo.getAllArtifacts();
      if (!mounted) return;
      setState(() {
        _artifacts = artifacts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug: Artifacts from Supabase')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : ListView.builder(
                  itemCount: _artifacts.length,
                  itemBuilder: (context, index) {
                    final artifact = _artifacts[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(artifact.name),
                        subtitle: Text(
                          artifact.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          artifact.updatedAt.toString().substring(0, 10),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
