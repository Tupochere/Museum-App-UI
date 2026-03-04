import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  Future<void> initialize() async {
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty) {
      throw StateError('SUPABASE_URL is missing in .env');
    }

    if (anonKey == null || anonKey.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY is missing in .env');
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}
