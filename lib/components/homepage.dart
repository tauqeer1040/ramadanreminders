// import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import './dailyreminders.dart';
import './heading.dart';
import './journal.dart';
import '../services/settings_service.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _hijriAdjustment = 0;
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadAdjustment();
  }

  Future<void> _loadAdjustment() async {
    final adj = await _settingsService.loadHijriAdjustment();
    if (mounted) {
      setState(() {
        _hijriAdjustment = adj;
      });
    }
  }

  Future<void> _updateAdjustment(int change) async {
    final newAdj = _hijriAdjustment + change;
    await _settingsService.saveHijriAdjustment(newAdj);
    if (mounted) {
      setState(() {
        _hijriAdjustment = newAdj;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine locale safely
    final String locale = Localizations.localeOf(context).languageCode;
    HijriCalendar.setLocal(locale);

    // Apply adjustment to current date
    // var today = HijriCalendar.now();
    // HijriCalendar doesn't seem to have a direct addDays method that returns a new object easily in all versions,
    // so we can just adjust the day number for display, or better, use the internal adjustment feature if available.
    // Ideally, we'd use: today.hDay += _hijriAdjustment; but that might overflow month.
    // Let's use the built-in property if possible, but simplest is to just re-calculate or manipulate the object.

    // A safer way to handle day adjustment with month overflow:
    // Create a new HijriCalendar from the adjusted day.
    // However, for simplicity given the visual requirement:
    // We will just display the adjusted day.
    // Wait, if day becomes 31 or 0, that's bad.

    // Let's try to find a proper add days method.
    // Assuming we can just manipulate internal fields or use standard dart date manipulation on the gregorian side before converting?
    // Start with DateTime.now().add(Duration(days: _hijriAdjustment)) then convert to Hijri.
    var adjustedGregorian = DateTime.now().add(
      Duration(days: _hijriAdjustment),
    );
    var adjustedHijri = HijriCalendar.fromDate(adjustedGregorian);

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            GestureDetector(
              onLongPress: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Adjust Hijri Date'),
                    content: Text('Current Adjustment: $_hijriAdjustment days'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          _updateAdjustment(-1);
                          Navigator.pop(context);
                        },
                        child: const Text('-1 Day'),
                      ),
                      TextButton(
                        onPressed: () {
                          _updateAdjustment(1);
                          Navigator.pop(context);
                        },
                        child: const Text('+1 Day'),
                      ),
                    ],
                  ),
                );
              },
              child: RamadanHeader(
                ramadanDay: adjustedHijri.hDay,
                monthName: adjustedHijri.longMonthName,
              ),
            ),
            const SizedBox(height: 24),
            const JournalEntry(),
            const SizedBox(height: 24),
            DailyReminder(),
          ],
        ),
      ),
    );
  }
}
