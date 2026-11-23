import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/excel_service.dart';
import 'scanner_screen.dart';
import 'records_screen.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Загружено товаров: ${products.length}')));
      }
    } catch (e) {
      if (mounted) _error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Сроки годности')),
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Справочник товаров', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_catalog.isEmpty ? 'Файл ещё не загружен' : 'В памяти: ${_catalog.length} товаров'),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _busy ? null : _import, icon: const Icon(Icons.file_upload_outlined), label: Text(_busy ? 'Загрузка…' : 'Загрузить Excel (.xlsx)')),
          const SizedBox(height: 4),
          const Text('Для .xls сначала сохраните файл в формате .xlsx.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]))),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
          onPressed: _catalog.isEmpty ? () => _error('Сначала загрузите справочник .xlsx') : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScannerScreen(catalog: _catalog))),
          icon: const Icon(Icons.qr_code_scanner), label: const Text('Сканировать штрихкод'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordsScreen())),
          icon: const Icon(Icons.history), label: const Text('Сохранённые записи'),
        ),
        const Spacer(),
        const Text('Работает офлайн. Загруженный справочник хранится в памяти до закрытия приложения.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    )),
  );
}
