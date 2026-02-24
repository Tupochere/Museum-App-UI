import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper service for accessing the Supabase client
/// Makes it easier to inject and test
class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;
}
