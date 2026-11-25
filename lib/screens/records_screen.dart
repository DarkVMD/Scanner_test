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
      await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: 'vscan_sroki_godnosti.xlsx')], text: 'Экспорт сроков годности');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e')));
    }
  }

  Future<void> _delete(ExpiryRecord record) async {
    if (record.id == null) return;
    await DatabaseService.instance.delete(record.id!);
    _reload();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Все сохранённые записи будут удалены без возможности восстановления.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB94A55)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить всё'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseService.instance.deleteAll();
    if (mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('История очищена')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('История записей', style: TextStyle(fontWeight: FontWeight.w700)),
      leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
    ),
    body: FutureBuilder<List<ExpiryRecord>>(
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text('Не удалось загрузить записи'));
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 76, height: 76, decoration: BoxDecoration(color: const Color(0xFF1C2B3F), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF70B7FF))),
              const SizedBox(height: 18),
              const Text('Пока пусто', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              const Text('Отсканированные товары и их сроки годности появятся здесь.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF91A0B5), height: 1.4)),
            ]),
          ));
        }
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: const Color(0xFF151F30), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF26364B))),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.checklist_rounded, color: Color(0xFF70D6B0), size: 21),
                  const SizedBox(width: 10),
                  Text('Всего записей: ${records.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 11),
                Row(children: [
                  Expanded(child: FilledButton.tonalIcon(onPressed: () => _export(records), icon: const Icon(Icons.ios_share_rounded, size: 17), label: const Text('Экспорт'))),
                  const SizedBox(width: 9),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Color(0xFFFF8585)),
                    label: const Text('Очистить всё', style: TextStyle(color: Color(0xFFFF8585))),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF75404A))),
                  )),
                ]),
              ]),
            ),
          ),
          Expanded(child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final record = records[index];
              return Container(
                decoration: BoxDecoration(color: const Color(0xFF151F30), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF26364B))),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(15, 7, 7, 7),
                  leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF1D344D), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF70B7FF))),
                  title: Text(record.name.isEmpty ? 'Без названия' : record.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text('${record.barcode}\nГоден до: ${DateFormat('dd.MM.yyyy').format(DateTime.parse(record.expiryDate))}', style: const TextStyle(color: Color(0xFF91A0B5), height: 1.5))),
                  isThreeLine: true,
                  trailing: IconButton(tooltip: 'Удалить запись', icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF8585)), onPressed: () => _delete(record)),
                ),
              );
            },
          )),
        ]);
      },
    ),
  );
}
