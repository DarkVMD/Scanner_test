import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';

class ExcelService {
  static Future<List<Product>> importProducts() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (picked == null) return [];
    final file = picked.files.single;
    final ext = (file.extension ?? '').toLowerCase();
    if (ext == 'xls') throw Exception('Формат .xls не поддерживается. Откройте файл в Excel или LibreOffice и сохраните его как .xlsx.');
    final bytes = file.bytes;
    if (bytes == null) throw Exception('Не удалось прочитать файл. Попробуйте выбрать его ещё раз.');

    final book = Excel.decodeBytes(Uint8List.fromList(bytes));
    if (book.tables.isEmpty) throw Exception('В файле не найдены листы.');
    final sheet = book.tables.values.first;
    if (sheet == null || sheet.rows.isEmpty) throw Exception('Первый лист пуст.');

    final products = <Product>[];
    final seen = <String>{};
    for (var i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.length < 2) continue;
      final name = _cellText(row[0]?.value).trim();
      final barcode = _barcodeText(row[1]?.value).trim();
      if (name.isEmpty || barcode.isEmpty) continue;
      // Skip a conventional header row without relying on a fixed header spelling.
      if (i == 0 && (name.toLowerCase().contains('назван') || name.toLowerCase() == 'name') &&
          (barcode.toLowerCase().contains('штрих') || barcode.toLowerCase().contains('barcode'))) continue;
      if (seen.add(barcode)) products.add(Product(name: name, barcode: barcode));
    }
    if (products.isEmpty) throw Exception('Не удалось найти строки с названием и штрихкодом в первых двух колонках.');
    return products;
  }

  static String _cellText(CellValue? value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value.toString();
    return value.toString();
  }

  static String _barcodeText(CellValue? value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toString().trim();
    // Convert numeric cell contents directly to a string; never use numbers for lookups.
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) {
      final number = value.value;
      return number == number.roundToDouble() ? number.toInt().toString() : number.toString();
    }
    return _cellText(value).trim();
  }

  static Uint8List exportRecords(List<ExpiryRecord> records) {
    final book = Excel.createExcel();
    final sheet = book['Сроки годности'];
    sheet.appendRow([TextCellValue('Название'), TextCellValue('Штрихкод'), TextCellValue('Срок годности')]);
    for (final record in records) {
      final date = DateFormat('dd.MM.yyyy').format(DateTime.parse(record.expiryDate));
      // TextCellValue is intentional: EANs must never be exported as numeric cells.
      sheet.appendRow([TextCellValue(record.name), TextCellValue(record.barcode), TextCellValue(date)]);
    }
    final bytes = book.encode();
    if (bytes == null) throw Exception('Не удалось сформировать Excel-файл.');
    return Uint8List.fromList(bytes);
  }
}
