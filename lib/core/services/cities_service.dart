import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/allowed_city_model.dart';
import '../exceptions/app_exceptions.dart';

class CitiesService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<AllowedCityModel>> getAllowedCities() async {
    try {
      final data = await _client
          .from('allowed_cities')
          .select()
          .eq('attiva', true)
          .order('ordine');

      return data.map((json) => _parseCityFromJson(json)).toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore recupero città: ${e.message}');
    }
  }

  Future<List<AllowedCityModel>> getAllCities() async {
    try {
      final data = await _client
          .from('allowed_cities')
          .select()
          .order('ordine');

      return data.map((json) => _parseCityFromJson(json)).toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore recupero città: ${e.message}');
    }
  }

  Future<AllowedCityModel> createCity({
    required String nome,
    required String cap,
    bool attiva = true,
    int ordine = 0,
  }) async {
    try {
      final data = await _client
          .from('allowed_cities')
          .insert({
            'nome': nome,
            'cap': cap,
            'attiva': attiva,
            'ordine': ordine,
          })
          .select()
          .single();

      return _parseCityFromJson(data);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore creazione città: ${e.message}');
    }
  }

  Future<void> updateCity({
    required String cityId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(updates);
      payload['updated_at'] = DateTime.now().toUtc().toIso8601String();

      await _client
          .from('allowed_cities')
          .update(payload)
          .eq('id', cityId);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore aggiornamento città: ${e.message}');
    }
  }

  Future<void> deleteCity({
    required String cityId,
  }) async {
    try {
      await _client
          .from('allowed_cities')
          .delete()
          .eq('id', cityId);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore eliminazione città: ${e.message}');
    }
  }

  AllowedCityModel _parseCityFromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      return null;
    }

    return AllowedCityModel(
      id: json['id'] as String,
      nome: json['nome'] as String,
      cap: json['cap'] as String,
      attiva: json['attiva'] as bool? ?? true,
      ordine: json['ordine'] as int? ?? 0,
      createdAt: parseDateTime(json['created_at'])!,
      updatedAt: parseDateTime(json['updated_at']),
    );
  }
}
