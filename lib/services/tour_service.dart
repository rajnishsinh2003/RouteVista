import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tour_plan.dart';
import 'tour_data.dart';

class TourService {
  static const _bookmarkKey = 'tour_bookmarks';
  static const _customKey   = 'custom_tours';

  // ─────────────────────────────────────────────
  //  STATIC CURATED TOURS — 300+ destinations
  // ─────────────────────────────────────────────
  static List<TourPlan> getCurated() => StaticTourData.getTours();

  // ─────────────────────────────────────────────
  //  BOOKMARKS
  // ─────────────────────────────────────────────
  Future<Set<String>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_bookmarkKey) ?? []).toSet();
  }

  Future<void> toggleBookmark(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final set = await getBookmarks();
    set.contains(id) ? set.remove(id) : set.add(id);
    await prefs.setStringList(_bookmarkKey, set.toList());
  }

  // ─────────────────────────────────────────────
  //  CUSTOM TOURS
  // ─────────────────────────────────────────────
  Future<List<TourPlan>> getCustomTours() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_customKey) ?? [];
    try {
      return raw.map((e) => TourPlan.fromJson(jsonDecode(e))).toList();
    } catch (_) { return []; }
  }

  Future<void> saveCustomTour(TourPlan t) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getCustomTours();
    list.removeWhere((x) => x.id == t.id);
    list.insert(0, t);
    await prefs.setStringList(_customKey, list.map((x) => jsonEncode(x.toJson())).toList());
  }

  Future<void> deleteCustomTour(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getCustomTours();
    list.removeWhere((x) => x.id == id);
    await prefs.setStringList(_customKey, list.map((x) => jsonEncode(x.toJson())).toList());
  }
}
