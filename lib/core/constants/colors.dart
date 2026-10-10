import 'package:flutter/material.dart';

enum ColorSeed {
  baseColor('M3 Baseline', Color(0xff6750a4)),
  indigo('Indigo', Colors.indigo),
  blue('Blue', Colors.blue),
  teal('Teal', Colors.teal),
  green('Green', Colors.green),
  yellow('Yellow', Colors.yellow),
  orange('Orange', Colors.orange),
  deepOrange('Deep Orange', Colors.deepOrange),
  pink('Pink', Colors.pink),
  // Appended (not first) so indices already saved in prefs keep their meaning.
  cadence('Cadence', Color(0xFFA5CE53));

  const ColorSeed(this.label, this.color);
  final String label;
  final Color color;
}