import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';
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
    if (ext == 'xls') {
      throw Exception('Формат .xls не поддерживается. Откройте файл в Excel или LibreOffice и сохраните его как .xlsx.');
    }
    final bytes = file.bytes;
    if (bytes == null) throw Exception('Не удалось прочитать файл. Попробуйте выбрать его ещё раз.');

    // Read the XLSX ZIP/XML structure directly. This avoids failures in the
    // excel package's style parser on workbooks with unusual number formats.
    final archive = ZipDecoder().decodeBytes(bytes);
    final workbookXml = _readZipText(archive, 'xl/workbook.xml');
    final relsXml = _readZipText(archive, 'xl/_rels/workbook.xml.rels');
    if (workbookXml == null || relsXml == null) {
      throw Exception('Файл не похож на корректную книгу .xlsx.');
    }

    final workbook = XmlDocument.parse(workbookXml);
    final relationships = XmlDocument.parse(relsXml);
    final firstSheet = workbook.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'sheet')
        .firstOrNull;
    if (firstSheet == null) throw Exception('В файле не найдены листы.');

    final relationshipId = _attribute(firstSheet, 'id');
    if (relationshipId == null) throw Exception('Не удалось определить первый лист Excel.');
    final relationship = relationships.descendants
        .whereType<XmlElement>()
        .where((element) =>
            element.name.local == 'Relationship' &&
            _attribute(element, 'Id') == relationshipId)
        .firstOrNull;
    if (relationship == null) throw Exception('Не найдена ссылка на первый лист Excel.');

    final target = _attribute(relationship, 'Target');
    if (target == null || target.isEmpty) throw Exception('У первого листа отсутствует путь.');
    final sheetPath = _resolveSheetPath(target);
    final sheetXml = _readZipText(archive, sheetPath);
    if (sheetXml == null) throw Exception('Не удалось прочитать первый лист Excel.');

    final sharedStrings = <String>[];
    final sharedXml = _readZipText(archive, 'xl/sharedStrings.xml');
    if (sharedXml != null) {
      final sharedDocument = XmlDocument.parse(sharedXml);
      for (final item in sharedDocument.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 'si')) {
        sharedStrings.add(_allTextNodes(item));
      }
    }

    final sheetDocument = XmlDocument.parse(sheetXml);
    final products = <Product>[];
    final seen = <String>{};

    for (final row in sheetDocument.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'row')) {
      String name = '';
      String barcode = '';
      for (final cell in row.children
          .whereType<XmlElement>()
          .where((element) => element.name.local == 'c')) {
        final reference = _attribute(cell, 'r') ?? '';
        final column = _columnIndex(reference);
        if (column != 0 && column != 1) continue;
        final value = _readCellValue(cell, sharedStrings).trim();
        if (column == 0) name = value;
        if (column == 1) barcode = value;
      }

      // Header rows, category labels, blank rows and entries without a
      // barcode are intentionally ignored.
      if (name.isEmpty || barcode.isEmpty) continue;
      final normalizedName = name.toLowerCase();
      final normalizedBarcode = barcode.toLowerCase();
      if ((normalizedName.contains('номенклатур') ||
              normalizedName.contains('наименован') ||
              normalizedName.contains('назван') ||
              normalizedName == 'name') &&
          (normalizedBarcode.contains('штрих') ||
              normalizedBarcode.contains('ш/к') ||
              normalizedBarcode.contains('barcode'))) {
        continue;
      }
      if (seen.add(barcode)) {
        products.add(Product(name: name, barcode: barcode));
      }
    }

    if (products.isEmpty) {
      throw Exception('Не удалось найти товары с названием и штрихкодом в первых двух колонках.');
    }
    return products;
  }

  static String? _readZipText(Archive archive, String path) {
    for (final file in archive.files) {
      if (file.name == path && file.isFile) {
        final content = file.content;
        if (content is List<int>) return utf8.decode(content);
        return utf8.decode(file.readBytes());
      }
    }
    return null;
  }

  static String? _attribute(XmlElement element, String localName) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == localName) return attribute.value;
    }
    return null;
  }

  static String _allTextNodes(XmlElement element) => element.descendants
      .whereType<XmlElement>()
      .where((child) => child.name.local == 't')
      .map((child) => child.innerText)
      .join();

  static String _readCellValue(XmlElement cell, List<String> sharedStrings) {
    final type = _attribute(cell, 't');
    if (type == 'inlineStr') return _allTextNodes(cell);

    final valueElement = cell.children
        .whereType<XmlElement>()
        .where((child) => child.name.local == 'v')
        .firstOrNull;
    if (valueElement == null) return '';
    final raw = valueElement.innerText.trim();

    if (type == 's') {
      final index = int.tryParse(raw);
      if (index == null || index < 0 || index >= sharedStrings.length) return '';
      return sharedStrings[index];
    }
    if (type == 'b') return raw == '1' ? 'TRUE' : 'FALSE';

    // Excel stores many EAN barcodes as numeric values. Normalize integral
    // numbers without introducing a decimal suffix.
    final number = num.tryParse(raw);
    if (number != null && number == number.toInt()) {
      return number.toInt().toString();
    }
    return raw;
  }

  static String _resolveSheetPath(String target) {
    if (target.startsWith('/')) return target.substring(1);
    if (target.startsWith('xl/')) return target;
    return 'xl/$target';
  }

  static int _columnIndex(String cellReference) {
    final match = RegExp(r'^([A-Z]+)', caseSensitive: false).firstMatch(cellReference);
    if (match == null) return -1;
    var result = 0;
    for (final code in match.group(1)!.toUpperCase().codeUnits) {
      result = result * 26 + code - 64;
    }
    return result - 1;
  }

  static Uint8List exportRecords(List<ExpiryRecord> records) {
    final book = Excel.createExcel();
    final sheet = book['Сроки годности'];
    sheet.appendRow([
      TextCellValue('Название'),
      TextCellValue('Штрихкод'),
      TextCellValue('Срок годности'),
    ]);
    for (final record in records) {
      final date = DateFormat('dd.MM.yyyy').format(DateTime.parse(record.expiryDate));
      // TextCellValue is intentional: EANs must never be exported as numeric cells.
      sheet.appendRow([
        TextCellValue(record.name),
        TextCellValue(record.barcode),
        TextCellValue(date),
      ]);
    }
    final bytes = book.encode();
    if (bytes == null) throw Exception('Не удалось сформировать Excel-файл.');
    return Uint8List.fromList(bytes);
  }
}
