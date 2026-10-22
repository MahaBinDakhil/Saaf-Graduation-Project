import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chatbot.dart';
import 'home_page.dart';
import 'settings/settings_page.dart';
import 'settings/settings_widgets.dart';
import 'scan_page.dart';
import 'theme/app_colors.dart';
import 'widgets/app_bottom_nav.dart';



// ============================================================
// MODEL: one scan record
// ============================================================

class ScanRecord {
  ScanRecord({
    required this.id,
    required this.title,
    required this.isHealthy,
    required this.date,
    required this.confidence,
    this.diseaseId = '',
    this.description = '',
    this.imageUrl,
    this.heatmapUrl,
    this.regionUrl,
    double? healthConfidence,
    double? typeConfidence,
  })  : healthConfidence = healthConfidence ?? confidence,
        typeConfidence = typeConfidence ?? confidence;

  final String id;
  final String title; // Disease name, or "Healthy".
  final bool isHealthy;
  final DateTime date;
  final double confidence; // 0 to 100.
  final String diseaseId; // Passed to the chatbot.
  final String description;
  final String? imageUrl;
  final String? heatmapUrl;
  final String? regionUrl;
  final double healthConfidence; // XAI step 1: health check.
  final double typeConfidence; // XAI step 2: disease type.
}

// ============================================================
// FIRESTORE: users/{uid}/scans
// ============================================================

class HistoryRepository {
  final Map<String, String> _descCache = {};

  CollectionReference<Map<String, dynamic>> get _scans {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please log in first');
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('scans');
  }

  /// Live list of scans, newest first.
  /// Note: Firestore skips any document that has no `createdAt` field.
  Stream<List<ScanRecord>> watchScans() {
    try {
      return _scans
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((snap) async {
        final list = <ScanRecord>[];
        for (final d in snap.docs) {
          list.add(await _fromDoc(d));
        }
        return list;
      });
    } catch (e) {
      return Stream.error(e);
    }
  }

    Future<void> deleteScan(String id) async {
    final doc = await _scans.doc(id).get();
    final isHealthy =
        (doc.data()?['status'] ?? '').toString().toLowerCase() == 'healthy';
    await _scans.doc(id).delete();

    // Keep the counters on the user document up to date.
    await _scans.parent!.set({
      'totalScans': FieldValue.increment(-1),
      (isHealthy ? 'healthyCount' : 'diseasedCount'):
          FieldValue.increment(-1),
    }, SetOptions(merge: true));
  }

  /// Scores are stored as 0..1 in Firestore; the UI uses 0..100.
  double _pct(dynamic v) {
    final n = (v as num?)?.toDouble() ?? 0;
    return n <= 1 ? n * 100 : n;
  }

  /// Ignores empty or placeholder URLs such as "https://".
  String? _url(dynamic v) {
    final s = (v ?? '').toString();
    return ((s.startsWith('http') || s.startsWith('data:')) && s.length > 8) ? s : null;
  }

  /// Reads the disease description from diseases/{diseaseId} (cached).
  Future<String> _description(String diseaseId) async {
    if (diseaseId.isEmpty) return '';
    final cached = _descCache[diseaseId];
    if (cached != null) return cached;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('diseases')
          .doc(diseaseId)
          .get();
      final text = (doc.data()?['description'] ?? '').toString();
      _descCache[diseaseId] = text;
      return text;
    } catch (_) {
      return '';
    }
  }

  Future<ScanRecord> _fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> d) async {
    final j = d.data();
    final diseaseId = (j['diseaseId'] ?? '').toString();
    final isHealthy =
        (j['status'] ?? '').toString().toLowerCase() == 'healthy' ||
            diseaseId == 'healthy';
    final conf = _pct(j['confidence']);

    // XAI steps are derived from the `predictions` list.
    double typeConf = conf;
    double healthConf = conf;
    final preds = j['predictions'];
    if (preds is List && preds.isNotEmpty) {
      final first = preds.first;
      if (first is Map) typeConf = _pct(first['score']);
      if (!isHealthy) {
        for (final p in preds) {
          if (p is Map && p['name'].toString().toLowerCase() == 'healthy') {
            healthConf = 100 - _pct(p['score']);
          }
        }
      }
    }

    var desc = await _description(diseaseId);
    if (desc.isEmpty && isHealthy) {
      desc = 'No signs of disease were detected on this palm.';
    }

    return ScanRecord(
      id: d.id,
      title: (j['diseaseName'] ?? j['title'] ?? diseaseId).toString(),
      isHealthy: isHealthy,
      date: (j['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confidence: conf,
      diseaseId: diseaseId,
      description: desc,
      imageUrl: _url(j['imageUrl']),
      heatmapUrl: _url(j['heatmapUrl']),
      regionUrl: _url(j['regionUrl']),
      healthConfidence: healthConf,
      typeConfidence: typeConf,
    );
  }
}

// ============================================================
// HELPERS: dates, image, status tag
// ============================================================

const List<String> _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _time(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

/// For the list: "Today, 8:02 AM" / "Yesterday, 2:15 PM" / "22 August".
String formatScanDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today, ${_time(d)}';
  if (diff == 1) return 'Yesterday, ${_time(d)}';
  return '${d.day} ${_months[d.month - 1]}';
}

/// For the details screen: "1 August, 10:21 AM".
String formatScanDateFull(DateTime d) =>
    '${d.day} ${_months[d.month - 1]}, ${_time(d)}';

/// Scan image. Falls back to a colored placeholder when there is no URL.
class ScanImage extends StatelessWidget {
  const ScanImage({
    super.key,
    this.url,
    this.isHealthy = true,
    this.width,
    this.height,
    this.radius = 8,
  });

  final String? url;
  final bool isHealthy;
  final double? width;
  final double? height;
  final double radius;

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isHealthy
              ? const [Color(0xFF315C3B), Color(0xFF87A878)]
              : const [Color(0xFF432F25), Color(0xFFB87938)],
        ),
      ),
      child: const Center(child: Icon(Icons.eco, color: Colors.white54)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = url;
    Widget content;
           if (u == null || u.isEmpty) {
         content = _placeholder();
       } else if (u.startsWith('data:')) {
         content = Image.memory(base64Decode(u.split(',').last),
             fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
       } else if (u.startsWith('http')) {
         content = Image.network(u,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    } else {
      content = Image.asset(u,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, height: height, child: content),
    );
  }
}

class ScanStatusTag extends StatelessWidget {
  const ScanStatusTag({super.key, required this.isHealthy});
  final bool isHealthy;

  @override
  Widget build(BuildContext context) {
    final color = isHealthy ? AppColors.leafGreen : AppColors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        isHealthy ? 'Healthy' : 'Diseased',
        style: TextStyle(
          color: color,
          fontSize: 8,
          height: 1,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ============================================================
// SCREEN 1: HISTORY (list)
// ============================================================

enum _Filter { all, healthy, diseased }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryRepository _repo = HistoryRepository();
  late final Stream<List<ScanRecord>> _stream = _repo.watchScans();
  final TextEditingController _search = TextEditingController();
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openScan() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ScanPage()),
    );
  }

  void _openDetails(ScanRecord r) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ScanDetailsScreen(record: r)),
    );
  }

  /// Applies the status filter and the search text.
  List<ScanRecord> _apply(List<ScanRecord> all) {
    final q = _query.trim().toLowerCase();
    return all.where((r) {
      final okFilter = _filter == _Filter.all
          ? true
          : _filter == _Filter.healthy
              ? r.isHealthy
              : !r.isHealthy;
      final okQuery = q.isEmpty || r.title.toLowerCase().contains(q);
      return okFilter && okQuery;
    }).toList();
  }

  /// Confirmation dialog, then deletes the scan from Firestore.
  Future<void> _delete(ScanRecord r) async {
    final ok = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete this scan?',
      message:
          "${r.title} · ${formatScanDate(r.date)} will be removed. This can't be undone.",
      confirmLabel: 'Delete',
      danger: true,
    );
    if (ok) await _repo.deleteScan(r.id);
  }

  // ---------- Header ----------
  Widget _header(List<ScanRecord> all) {
    final count = all.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'History',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'scan' : 'scans'} saved',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          if (all.isNotEmpty)
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _showStats(all),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: AppColors.primary, size: 22),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Search ----------
  Widget _searchField() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: AppColors.inputBorder),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 6),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(fontSize: 14, color: AppColors.primary),
        decoration: InputDecoration(
          hintText: 'Search by disease name',
          hintStyle: const TextStyle(fontSize: 14, color: AppColors.mutedText),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 8),
            child: Icon(Icons.search_rounded,
                size: 22, color: AppColors.mutedText),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 46),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.mutedText),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          enabledBorder: border,
          border: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
        ),
      ),
    );
  }

  // ---------- Filter chips ----------
  Widget _chip(String label, _Filter f, int count) {
    final selected = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => setState(() => _filter = f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(18, 9, 9, 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.inputBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 26),
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.lime : AppColors.pageBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? AppColors.primary : AppColors.mutedText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chips(List<ScanRecord> all) {
    final healthy = all.where((r) => r.isHealthy).length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(22, 8, 12, 8),
      child: Row(
        children: [
          _chip('All', _Filter.all, all.length),
          _chip('Healthy', _Filter.healthy, healthy),
          _chip('Diseased', _Filter.diseased, all.length - healthy),
        ],
      ),
    );
  }

  // ---------- Delete button inside the card ----------
  Widget _deleteButton(ScanRecord r) {
    return Material(
      color: AppColors.pageBg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _delete(r),
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.delete_outline_rounded,
              size: 18, color: AppColors.mutedText),
        ),
      ),
    );
  }

  // ---------- Empty state ----------
  Widget _emptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lime.withValues(alpha: 0.35),
                    blurRadius: 40,
                    spreadRadius: 6,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  color: AppColors.softGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_rounded,
                    size: 52, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No scans yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Scan your first date palm and its\ndiagnosis will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.mutedText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _openScan,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.center_focus_strong_rounded,
                        color: AppColors.lime, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Start scan',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Stats sheet (chart button) ----------
  void _showStats(List<ScanRecord> all) {
    final healthy = all.where((r) => r.isHealthy).length;
    final diseased = all.length - healthy;

    // Count each disease name.
    final byDisease = <String, int>{};
    for (final r in all.where((r) => !r.isHealthy)) {
      byDisease[r.title] = (byDisease[r.title] ?? 0) + 1;
    }
    final entries = byDisease.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.inputBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Scan summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _statTile('Total', all.length, AppColors.primary),
                    const SizedBox(width: 10),
                    _statTile('Healthy', healthy, AppColors.healthyGreen),
                    const SizedBox(width: 10),
                    _statTile('Diseased', diseased, AppColors.diseased),
                  ],
                ),
                if (entries.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Text(
                    'BY DISEASE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedText,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Text(
                                '${e.value}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: e.value / diseased,
                              minHeight: 6,
                              backgroundColor: AppColors.pageBg,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.diseased),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statTile(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: SafeArea(
          bottom: false,
          child: StreamBuilder<List<ScanRecord>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load history:\n${snap.error}',
                        textAlign: TextAlign.center),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              final all = snap.data!;
              final shown = _apply(all);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(all),
                  if (all.isEmpty)
                    Expanded(child: _emptyState())
                  else ...[
                    _searchField(),
                    _chips(all),
                    Expanded(
                      child: shown.isEmpty
                          ? const Center(
                              child: Text(
                                'No results',
                                style: TextStyle(
                                    fontSize: 15, color: AppColors.mutedText),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(22, 6, 22, 24),
                              itemCount: shown.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) {
                                final r = shown[i];
                                return RecentScanCard(
                                  record: r,
                                  onTap: () => _openDetails(r),
                                  trailing: _deleteButton(r),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        // The nav bar is hidden while the keyboard is open.
        bottomNavigationBar: keyboardOpen
            ? null
            : const AppBottomNavigationBar(current: NavTab.history),
      ),
    );
  }
}
// ============================================================
// SCREEN 2: SCAN DETAILS
// ============================================================

/// Opens the chatbot linked to this scan result.
void _openChatbotFor(BuildContext context, ScanRecord r) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ChatbotScreen(
        diseaseId: r.diseaseId,
        confidence: r.confidence / 100, // The chatbot expects 0..1.
      ),
    ),
  );
}

/// Big rounded photo. Tap it to open the full-screen viewer.
class _PhotoBox extends StatelessWidget {
  const _PhotoBox({
    required this.url,
    required this.isHealthy,
    this.badge,
  });

  final String? url;
  final bool isHealthy;
  final String? badge; // e.g. "Scanned photo"

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final u = url;
        if (u == null) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => FullImageViewer(url: u)),
        );
      },
      child: Stack(
        children: [
          ScanImage(
            url: url,
            isHealthy: isHealthy,
            width: double.infinity,
            height: 240,
            radius: 28,
          ),
          if (badge != null)
            Positioned(
              left: 16,
              top: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppColors.lime,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dark green full-width pill button.
class _DarkPillButton extends StatelessWidget {
  const _DarkPillButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// White pill button with a dark green border and a chat icon.
class _ChatPillButton extends StatelessWidget {
  const _ChatPillButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.6),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

/// White rounded card used on both screens.
BoxDecoration _whiteCard() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFFEDEFEA)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );

class ScanDetailsScreen extends StatelessWidget {
  const ScanDetailsScreen({super.key, required this.record});
  final ScanRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final percent = r.confidence.round().clamp(0, 100);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SubPageHeader(title: 'Scan Details'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PhotoBox(
                        url: r.imageUrl,
                        isHealthy: r.isHealthy,
                        badge: 'Scanned photo',
                      ),
                      const SizedBox(height: 16),

                      // Result card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                        decoration: _whiteCard(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    r.title,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                StatusPill(isHealthy: r.isHealthy),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 16, color: AppColors.mutedText),
                                const SizedBox(width: 6),
                                Text(
                                  formatScanDateFull(r.date),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.mutedText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Confidence',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mutedText,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$percent%',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ConfidenceBar(
                                percent: percent, isHealthy: r.isHealthy),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // About
                      Text(
                        r.isHealthy ? 'About this result' : 'About this disease',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        r.description.isEmpty
                            ? 'No description available.'
                            : r.description,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 32),

                      _DarkPillButton(
                        label: 'View XAI Explanation',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => XaiExplanationScreen(record: r),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ChatPillButton(
                        label: 'Ask the Chatbot',
                        onPressed: () => _openChatbotFor(context, r),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar:
            const AppBottomNavigationBar(current: NavTab.history),
      ),
    );
  }
}

// ============================================================
// SCREEN 3: XAI EXPLANATION
// ============================================================

class XaiExplanationScreen extends StatefulWidget {
  const XaiExplanationScreen({super.key, required this.record});
  final ScanRecord record;

  @override
  State<XaiExplanationScreen> createState() => _XaiExplanationScreenState();
}

class _XaiExplanationScreenState extends State<XaiExplanationScreen> {
  bool _heatmap = true; // true = Heatmap tab, false = Region tab.

  // Heatmap / Region switch.
  Widget _toggle() {
    Widget seg(String label, bool value) {
      final sel = _heatmap == value;
      return GestureDetector(
        onTap: () => setState(() => _heatmap = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 112,
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: sel ? Colors.white : AppColors.mutedText,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E9E3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('Heatmap', true), seg('Region', false)],
      ),
    );
  }

  // Legend: color scale for the heatmap, outline key for the region view.
  Widget _legend() {
    const style = TextStyle(fontSize: 13, color: AppColors.mutedText);
    if (_heatmap) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Low', style: style),
          const SizedBox(width: 6),
          Container(
            width: 56,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(colors: [
                Color(0xFF3B5BDB),
                Color(0xFF22B8CF),
                Color(0xFFFAB005),
                Color(0xFFE03131),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          const Text('High', style: style),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE03131),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        const Text('High attention', style: style),
      ],
    );
  }

  // One step of the "How the AI decided" card.
  Widget _step(int n, String label, String value, double percent,
      bool isHealthy, {required bool showLine}) {
    final p = percent.round().clamp(0, 100);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Number circle + connecting line
          SizedBox(
            width: 30,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$n',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: AppColors.inputBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 18 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Text(
                        '$p%',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ConfidenceBar(percent: p, isHealthy: isHealthy),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final imageUrl =
        _heatmap ? (r.heatmapUrl ?? r.imageUrl) : (r.regionUrl ?? r.imageUrl);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SubPageHeader(title: 'XAI Explanation'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PhotoBox(url: imageUrl, isHealthy: r.isHealthy),
                      const SizedBox(height: 18),

                      // Toggle + legend
                      Row(
                        children: [
                          _toggle(),
                          const Spacer(),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: _legend(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _heatmap
                            ? "Grad-CAM++ heatmap: red areas are the parts of the photo that most influenced the AI's decision."
                            : 'Red outline: the region of the leaf the AI focused on most when making its decision.',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // How the AI decided
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                        decoration: _whiteCard(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'How the AI decided',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _step(
                              1,
                              'Health check',
                              r.isHealthy ? 'Healthy' : 'Diseased',
                              r.healthConfidence,
                              r.isHealthy,
                              showLine: !r.isHealthy,
                            ),
                            if (!r.isHealthy)
                              _step(
                                2,
                                'Disease type',
                                r.title,
                                r.typeConfidence,
                                r.isHealthy,
                                showLine: false,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Note
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F0E6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppColors.healthyGreen, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Highlights show where the AI looked, not confirmed disease spots. Ask a specialist.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.healthyGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      _ChatPillButton(
                        label: 'Ask the Chatbot about this',
                        onPressed: () => _openChatbotFor(context, r),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar:
            const AppBottomNavigationBar(current: NavTab.history),
      ),
    );
  }
}
// ============================================================
// FULL-SCREEN IMAGE VIEWER (tap an XAI image to open it)
// ============================================================

class FullImageViewer extends StatelessWidget {
  const FullImageViewer({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final Widget image = url.startsWith('data:')
        ? Image.memory(base64Decode(url.split(',').last), fit: BoxFit.contain)
        : Image.network(url, fit: BoxFit.contain);

        return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: const Text('Pinch to zoom', style: TextStyle(fontSize: 14)),
      ),
      body: SizedBox.expand(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
            child: Center(
     child: SizedBox(width: double.infinity, child: image),
   ),
        ),
      ),
    );
  }
}