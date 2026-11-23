import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/excel_service.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  late Future<List<ExpiryRecord>> _records = DatabaseService.instance.allRecords();
  void _reload() => setState(() => _records = DatabaseService.instance.allRecords());

  Future<void> _export(List<ExpiryRecord> records) async {
    if (records.isEmpty) return;
    try {
      final bytes = ExcelService.exportRecords(records);
      await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: 'sroki_godnosti.xlsx')], text: 'Экспорт сроков годности');
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e'))); }
  }

  Future<void> _delete(ExpiryRecord record) async {
    if (record.id == null) return;
    await DatabaseService.instance.delete(record.id!);
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Сохранённые записи')),
    body: FutureBuilder<List<ExpiryRecord>>(
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final records = snapshot.data ?? [];
        if (records.isEmpty) return const Center(child: Text('Пока нет сохранённых записей'));
        return Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [Text('Всего: ${records.length}', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), FilledButton.icon(onPressed: () => _export(records), icon: const Icon(Icons.ios_share), label: const Text('Экспорт .xlsx'))]),),
          Expanded(child: ListView.separated(itemCount: records.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, index) {
            final record = records[index];
            return ListTile(title: Text(record.name), subtitle: Text('${record.barcode}\nСрок годности: ${DateFormat('dd.MM.yyyy').format(DateTime.parse(record.expiryDate))}'), isThreeLine: true, trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(record)));
          })),
        ]);
      },
    ),
  );
}
