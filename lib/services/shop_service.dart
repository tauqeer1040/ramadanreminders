import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/shop_item.dart';
import '../utils/image_urls.dart';

class ShopService {
  static const _cacheKey = 'shop_items_cache';
  static const _unlockedKey = 'shop_unlocked';

  /// Fetch shop items from API. Falls back to SharedPrefs cache, then static list.
  static Future<List<ShopItem>> fetchItems() async {
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http
          .get(Uri.parse('${AppConstants.backendUrl}/shop/items'), headers: headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (body['items'] as List).map((e) {
          final item = e as Map<String, dynamic>;
          return ShopItem(
            id: item['id'] as String,
            name: item['name'] as String,
            thumbnailUrl: assetUrl(item['thumbnailUrl'] as String? ?? ''),
            imageUrl: assetUrl(item['imageUrl'] as String? ?? ''),
            cost: item['cost'] as int? ?? 100,
            localAsset: item['localAsset'] as String? ?? '',
          );
        }).toList();
        await _cacheItems(items);
        return items;
      }
    } catch (e) {
      debugPrint('[ShopService] fetchItems error: $e');
    }

    final cached = await _loadCachedItems();
    if (cached.isNotEmpty) return cached;

    final fallback = _fallbackItems();
    await _cacheItems(fallback);
    return fallback;
  }

  static Future<List<ShopItem>> _loadCachedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list.map((e) {
        final item = e as Map<String, dynamic>;
        return ShopItem(
          id: item['id'] as String,
          name: item['name'] as String,
          thumbnailUrl: assetUrl(item['thumbnailUrl'] as String? ?? ''),
          imageUrl: assetUrl(item['imageUrl'] as String? ?? ''),
          cost: item['cost'] as int? ?? 100,
          localAsset: item['localAsset'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _cacheItems(List<ShopItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static List<ShopItem> _fallbackItems() {
    const names = [
      'Delicate Translucent Flower',
      'Orange Bloom',
      'Ethereal Flower in Motion',
      'Ethereal Flower',
      'Ethereal Flower V2',
      'Glowing Flower',
      'Translucent Flower',
      'Ethereal Bloom',
      'Ethereal Bloom V2',
      'Ethreial Bloom',
      'Radiant Flower Glow',
      'Ethereal Bloom V3',
      'Scratch Card 1',
      'Scratch Card 2',
      'Scratch Card 3',
      'Scratch Card 4',
      'Scratch Card 5',
      'Scratch Card 6',
      'Scratch Card 7',
      'Scratch Card 8',
      'Scratch Card 9',
    ];
    return List.generate(21, (i) {
      final id = i + 1;
      return ShopItem(
        id: 'shop_$id',
        name: names[i],
        thumbnailUrl: shopThumbnailUrl(id),
        imageUrl: shopFullUrl(id),
        cost: 100,
        localAsset: '',
      );
    });
  }

  static Future<Set<String>> getUnlockedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_unlockedKey);
    if (raw == null) return {};
    return Set<String>.from(jsonDecode(raw) as List);
  }

  static Future<bool> purchaseItem(String id) async {
    try {
      final headers = await ApiClient.postHeaders();
      final res = await http.post(
        Uri.parse('${AppConstants.backendUrl}/shop/purchase'),
        headers: headers,
        body: jsonEncode({'itemId': id}),
      );
      if (res.statusCode != 200) return false;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) return false;

      final serverStars = body['stars'] as int?;
      final prefs = await SharedPreferences.getInstance();
      if (serverStars != null) {
        await prefs.setInt('total_stars', serverStars);
      }
      final unlocked = await getUnlockedIds();
      unlocked.add(id);
      await prefs.setString(_unlockedKey, jsonEncode(unlocked.toList()));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> unlockItem(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = await getUnlockedIds();
    unlocked.add(id);
    await prefs.setString(_unlockedKey, jsonEncode(unlocked.toList()));
  }

  static Future<int> getStarBalance() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final headers = await ApiClient.authHeaders();
        final res = await http.get(
          Uri.parse('${AppConstants.backendUrl}/user/$uid'),
          headers: headers,
        ).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final serverStars = body['stars'] as int?;
          if (serverStars != null) {
            await prefs.setInt('total_stars', serverStars);
            return serverStars;
          }
        }
      }
    } catch (_) {}
    return prefs.getInt('total_stars') ?? 0;
  }

  static Future<void> syncStars() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.get(
        Uri.parse('${AppConstants.backendUrl}/user/$uid'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final serverStars = body['stars'] as int?;
        if (serverStars != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('total_stars', serverStars);
        }
      }
    } catch (_) {}
  }

  static Future<bool> addStars(int amount) async {
    try {
      final headers = await ApiClient.postHeaders();
      final res = await http.post(
        Uri.parse('${AppConstants.backendUrl}/stars/add'),
        headers: headers,
        body: jsonEncode({'amount': amount}),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final serverStars = body['stars'] as int?;
      if (serverStars != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('total_stars', serverStars);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setStars(int amount) async {
    try {
      final headers = await ApiClient.postHeaders();
      final res = await http.post(
        Uri.parse('${AppConstants.backendUrl}/stars/set'),
        headers: headers,
        body: jsonEncode({'amount': amount}),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final serverStars = body['stars'] as int?;
      if (serverStars != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('total_stars', serverStars);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
