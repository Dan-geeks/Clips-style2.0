// lib/screens/business/Accountsetup/Businesscategories.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'BusinessServiceCategory.dart';

class BusinessCategories extends StatefulWidget {
  const BusinessCategories({super.key});
  @override
  State<BusinessCategories> createState() => _BusinessCategoriesState();
}

class _BusinessCategoriesState extends State<BusinessCategories> {
/* ───────────────────────────── 1 · MASTER LIST ───────────────────────────── */
  final List<Map<String, dynamic>> categories = [
    {
      'id': 'barbering',
      'name': 'Barbering',
      'color': const Color(0xFF68624c),
      'icon': 'assets/barber.jpg'
    },
    {
      'id': 'salons',
      'name': 'Salons',
      'color': const Color(0xFF295903),
      'icon': 'assets/salon.jpg'
    },
    {
      'id': 'spa',
      'name': 'Spa',
      'color': const Color(0xFF1e4f4c),
      'icon': 'assets/spa.jpg'
    },
    {
      'id': 'nail_techs',
      'name': 'Nail Techs',
      'color': const Color(0xFFa448a0),
      'icon': 'assets/Nailtech.jpg'
    },
    {
      'id': 'dreadlocks',
      'name': 'Dreadlocks',
      'color': const Color(0xFF141d48),
      'icon': 'assets/Dreadlocks.jpg'
    },
    {
      'id': 'makeups',
      'name': 'MakeUps',
      'color': const Color(0xFF5f131c),
      'icon': 'assets/Makeup.jpg'
    },
    {
      'id': 'tattoo_piercing',
      'name': 'Tattoo & Piercing',
      'color': const Color(0xFF0d5b3a),
      'icon': 'assets/TatooandPiercing.jpg'
    },
    {
      'id': 'eyebrows_eyelashes',
      'name': 'Eyebrows & Eyelashes',
      'color': const Color(0xFF8B4513),
      'icon': 'assets/eyebrows.jpg'
    },
  ];

/* ───────────────────── 2 · EVERY DISPLAY NAME  ➜  CANONICAL ID ───────────── */
  late final Map<String, String> aliasToId = {
    // originals
    for (final c in categories) c['name'] as String: c['id'] as String,
    // variants written by ServiceCategoriesPage
    'Barbershop': 'barbering',
    'Nails': 'nail_techs',
    'Make up': 'makeups',
    'Tattooandpiercing': 'tattoo_piercing',
    'Eyebrows': 'eyebrows_eyelashes',
  };

  late Box appBox;
  Map<String, dynamic>? businessData;

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

/* ─────────────────────────── 3 · LOAD / MIGRATE ─────────────────────────── */
  Future<void> _loadBusinessData() async {
    appBox = Hive.box('appBox');
    businessData = appBox.get('businessData') as Map<String, dynamic>? ?? {};

    // A) first-time setup
    if (!businessData!.containsKey('categories')) {
      businessData!['categories'] = categories
          .map((c) => {
                'id': c['id'],
                'name': c['name'], // Ensure name is saved initially
                'isSelected': false,
                'isPrimary': false,
              })
          .toList();
      await appBox.put('businessData', businessData);
      setState(() {});
      return;
    }

    final List list = List.from(businessData!['categories'] as List);
    bool changed = false;

    // B) MIGRATE: Add 'id' to old rows that are missing it.
    for (int i = 0; i < list.length; i++) {
      final Map item = Map.from(list[i] as Map);
      if (!item.containsKey('id')) {
        final String? rawName = item['name'] as String?;
        final String? canonicalId = rawName != null ? aliasToId[rawName] : null;
        if (canonicalId != null) {
          item['id'] = canonicalId;
          list[i] = item;
          changed = true;
        }
      }
    }

    // C) MIGRATE: Correct any outdated category names stored in Hive.
    // This ensures consistency with the master list.
    final Map<String, String> idToCorrectName = {
      for (final c in categories) c['id'] as String: c['name'] as String,
    };

    for (int i = 0; i < list.length; i++) {
      final Map item = Map.from(list[i] as Map);
      final String? id = item['id'] as String?;
      final String? currentName = item['name'] as String?;
      final String? correctName = id != null ? idToCorrectName[id] : null;

      if (correctName != null && currentName != correctName) {
        item['name'] = correctName;
        list[i] = item;
        changed = true;
      }
    }

    if (changed) {
      businessData!['categories'] = list;
      await appBox.put('businessData', businessData);
      debugPrint("MIGRATED category data in Hive.");
    }

    setState(() {});
  }

/* ─────────────────────────── 4 · STATE HELPERS ──────────────────────────── */
  int _indexOf(String id) => (businessData?['categories'] as List)
      .indexWhere((e) => (e as Map)['id'] == id);

  bool _isSelected(String id) =>
      businessData != null && _indexOf(id) != -1
          ? ((businessData!['categories'][_indexOf(id)] as Map)['isSelected'] ??
              false) as bool
          : false;

  bool _isPrimary(String id) =>
      businessData != null && _indexOf(id) != -1
          ? ((businessData!['categories'][_indexOf(id)] as Map)['isPrimary'] ??
              false) as bool
          : false;

  bool get _anySelected =>
      businessData != null &&
      (businessData!['categories'] as List)
          .any((e) => (e as Map)['isSelected'] == true);

/* ─────────────────────────── 5 · TOGGLE HANDLER ─────────────────────────── */
  Future<void> handleCategorySelection(String id) async {
    if (businessData == null) return;

    final List list = List.from(businessData!['categories'] as List);
    final int idx = _indexOf(id);
    if (idx == -1) return;

    final Map<String, dynamic> item =
        Map<String, dynamic>.from(list[idx] as Map);

    final bool selected = item['isSelected'] == true;

    // deselecting a primary
    if (selected && item['isPrimary'] == true) item['isPrimary'] = false;

    // toggle
    item['isSelected'] = !selected;

    // if turning ON and no primary exists
    if (!selected && !list.any((e) => (e as Map)['isPrimary'] == true)) {
      item['isPrimary'] = true;
    }

    list[idx] = item;
    businessData!['categories'] = list;
    businessData!['accountSetupStep'] = 3;
    await appBox.put('businessData', businessData);
    setState(() {});
  }

/* ─────────────────────────── 6 · UI ─────────────────────────────────────── */
  List<Color> get _borderGradient => const [
        Color.fromARGB(255, 61, 238, 3),
        Color.fromARGB(255, 78, 255, 2),
        Color.fromARGB(255, 83, 246, 2),
        Color.fromARGB(255, 85, 242, 7),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(
                8,
                (i) => Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color:
                            i < 2 ? const Color(0xFF23461a) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            const Text('Account setup',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300)),
            const SizedBox(height: 30),
            const Text('Choose the categories your services\nfall under',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final id = cat['id'] as String;
                  final name = cat['name'] as String;
                  final bool selected = _isSelected(id);
                  final bool primary = _isPrimary(id);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (primary)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.grey[600],
                                borderRadius: BorderRadius.circular(12)),
                            child: const Text('Primary',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          decoration: primary
                              ? BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: _borderGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(12))
                              : null,
                          padding: primary ? const EdgeInsets.all(2) : null,
                          child: ElevatedButton(
                            onPressed: () => handleCategorySelection(id),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: selected
                                    ? Colors.grey[600]
                                    : cat['color'],
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: EdgeInsets.zero),
                            child: Container(
                              height: 60,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                      child: ClipOval(
                                          child: Image.asset(cat['icon'],
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.error,
                                                      color: Colors.white)))),
                                  const SizedBox(width: 16),
                                  Expanded(
                                      child: Text(name,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white))),
                                  if (selected)
                                    Icon(Icons.check_circle,
                                        color:
                                            primary ? Colors.green : Colors.white)
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            if (_anySelected)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ServiceCategoriesPage())),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF23461a),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  child: const Text('Continue',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              )
          ],
        ),
      ),
    );
  }
}