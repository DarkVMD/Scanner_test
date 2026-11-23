import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/excel_service.dart';
import 'scanner_screen.dart';
import 'records_screen.dart';

const _background = Color(0xFF0B1220);
const _surface = Color(0xFF151F30);
const _muted = Color(0xFF91A0B5);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, Product> _catalog = {};
  bool _busy = false;

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final products = await ExcelService.importProducts();
      if (!mounted) return;
      if (products.isNotEmpty) {
        setState(() => _catalog = {for (final product in products) product.barcode: product});
        _message('Загружено товаров: ${products.length}');
      }
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    try {
      final records = await DatabaseService.instance.allRecords();
      if (!mounted) return;
      if (records.isEmpty) {
        _message('Пока нечего экспортировать');
        return;
      }
      final bytes = ExcelService.exportRecords(records);
      await Share.shareXFiles([
        XFile.fromData(bytes, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: 'sroki_godnosti.xlsx'),
      ], text: 'Экспорт сроков годности');
    } catch (e) {
      if (mounted) _message('Ошибка экспорта: $e');
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  void _openScanner() {
    if (_catalog.isEmpty) {
      _message('Сначала загрузите справочник .xlsx');
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ScannerScreen(catalog: _catalog)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Shelf Life Scanner', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2)),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.primary),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B3552), Color(0xFF17263B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF294563)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Управление сроками', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Text('Сканируйте товары и сохраняйте даты годности в одном месте.', style: TextStyle(color: Colors.blueGrey.shade100, height: 1.4)),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.library_books_outlined, color: Color(0xFF78B9FF), size: 19),
                const SizedBox(width: 8),
                Expanded(child: Text(_catalog.isEmpty ? 'Справочник не загружен' : 'В справочнике: ${_catalog.length} товаров', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                if (_catalog.isNotEmpty) const Icon(Icons.check_circle, color: Color(0xFF68D6A8), size: 19),
              ]),
            ]),
          ),
          const SizedBox(height: 25),
          const Text('БЫСТРЫЕ ДЕЙСТВИЯ', style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.12,
            children: [
              _ActionCard(icon: Icons.qr_code_scanner_rounded, title: 'Сканировать', subtitle: 'Добавить срок годности', color: const Color(0xFF70B7FF), onTap: _openScanner),
              _ActionCard(icon: Icons.history_rounded, title: 'История', subtitle: 'Сохранённые записи', color: const Color(0xFF70D6B0), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordsScreen()))),
              _ActionCard(icon: Icons.file_upload_outlined, title: 'Загрузить Excel', subtitle: _busy ? 'Загрузка файла…' : 'Импорт каталога', color: const Color(0xFFC6A0FF), onTap: _busy ? null : _import),
              _ActionCard(icon: Icons.ios_share_rounded, title: 'Экспорт', subtitle: 'Выгрузить результаты', color: const Color(0xFFFFCA78), onTap: _export),
            ],
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Icon(Icons.wifi_off_rounded, size: 15, color: _muted),
            SizedBox(width: 7),
            Text('Работает офлайн · Данные хранятся на устройстве', style: TextStyle(color: _muted, fontSize: 11)),
          ]),
          const SizedBox(height: 5),
          const Text('Для импорта используйте формат .xlsx', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _surface,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF26364B))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 25),
          ),
          const Spacer(),
          Text(title, style: const TextStyle(color: Color(0xFFEAF0F8), fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 11)),
        ]),
      ),
    ),
  );
}
