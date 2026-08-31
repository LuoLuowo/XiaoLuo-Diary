import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;
  String lightPalette = 'warm';
  String darkPalette = 'night';
  String wallpaperPath = '';
  double wallpaperStrength = .18;
  String decoration = 'paper';
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    mode = ThemeMode.values.firstWhere(
      (e) => e.name == (p.getString('themeMode') ?? 'system'),
      orElse: () => ThemeMode.system,
    );
    lightPalette = p.getString('lightPalette') ?? 'warm';
    darkPalette = p.getString('darkPalette') ?? 'night';
    wallpaperPath = p.getString('appearanceWallpaper') ?? '';
    wallpaperStrength = (p.getDouble('appearanceWallpaperStrength') ?? .18)
        .clamp(.08, .28);
    decoration = p.getString('appearanceDecoration') ?? 'paper';
  }

  Future<void> setWallpaper(String path) async {
    await (await SharedPreferences.getInstance()).setString(
      'appearanceWallpaper',
      path,
    );
    wallpaperPath = path;
    notifyListeners();
  }

  Future<void> setWallpaperStrength(double value) async {
    wallpaperStrength = value.clamp(.08, .28);
    notifyListeners();
    await (await SharedPreferences.getInstance()).setDouble(
      'appearanceWallpaperStrength',
      wallpaperStrength,
    );
  }

  Future<void> setDecoration(String value) async {
    decoration = value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(
      'appearanceDecoration',
      value,
    );
  }

  Future<void> setMode(ThemeMode value) async {
    mode = value;
    (await SharedPreferences.getInstance()).setString('themeMode', value.name);
    notifyListeners();
  }

  Future<void> setLight(String value) async {
    lightPalette = value;
    (await SharedPreferences.getInstance()).setString('lightPalette', value);
    notifyListeners();
  }

  Future<void> setDark(String value) async {
    darkPalette = value;
    (await SharedPreferences.getInstance()).setString('darkPalette', value);
    notifyListeners();
  }
}
