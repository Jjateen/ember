import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

abstract class DestinationRepository {
  Future<List<Destination>> all();
}

class AssetDestinationRepository implements DestinationRepository {
  List<Destination>? _cache;

  @override
  Future<List<Destination>> all() async {
    final raw = await rootBundle.loadString('assets/destinations.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return _cache ??= list.map(Destination.fromJson).toList(growable: false);
  }
}

abstract class ProgressRepository {
  Future<Set<String>> unlockedIds();
  Future<void> markUnlocked(String id);
  Future<void> reset();
}

class LocalProgressRepository implements ProgressRepository {
  static const _key = 'ember.unlocked';
  final _prefs = SharedPreferencesAsync();

  @override
  Future<Set<String>> unlockedIds() async =>
      (await _prefs.getStringList(_key) ?? const <String>[]).toSet();

  @override
  Future<void> markUnlocked(String id) async {
    final current = await unlockedIds();
    if (!current.add(id)) return;
    await _prefs.setStringList(_key, current.toList());
  }

  @override
  Future<void> reset() => _prefs.remove(_key);
}

/// Keeps progress in memory only. Used by tests.
class InMemoryProgressRepository implements ProgressRepository {
  final _ids = <String>{};

  @override
  Future<Set<String>> unlockedIds() async => Set.of(_ids);

  @override
  Future<void> markUnlocked(String id) async => _ids.add(id);

  @override
  Future<void> reset() async => _ids.clear();
}
