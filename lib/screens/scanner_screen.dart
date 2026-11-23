import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/product.dart';
import '../services/database_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.catalog});
  final Map<String, Product> catalog;
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.code128, BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _dialogOpen = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_dialogOpen || !mounted) return;
    final code = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;
    final product = widget.catalog[code];
    _dialogOpen = true;
    await _controller.stop();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExpiryDialog(
        name: product?.name ?? '',
        barcode: code,
        productFound: product != null,
      ),
    );
    _dialogOpen = false;
    if (mounted) await _controller.start();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Сканирование'), actions: [IconButton(onPressed: () => _controller.toggleTorch(), icon: const Icon(Icons.flashlight_on))]),
    body: Column(children: [
      Expanded(child: MobileScanner(controller: _controller, onDetect: _onDetect)),
      const Padding(padding: EdgeInsets.all(16), child: Text('Наведите камеру на EAN-13, EAN-8, Code-128 или QR-код', textAlign: TextAlign.center)),
    ]),
  );
}

class _ExpiryDialog extends StatefulWidget {
  const _ExpiryDialog({required this.name, required this.barcode, required this.productFound});
  final String name;
  final String barcode;
  final bool productFound;
  @override
  State<_ExpiryDialog> createState() => _ExpiryDialogState();
}

class _ExpiryDialogState extends State<_ExpiryDialog> {
  DateTime? _date;
  bool _saving = false;
  final _manual = TextEditingController();
  final _format = DateFormat('dd.MM.yyyy');

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100), helpText: 'Выберите срок годности');
    if (picked != null) setState(() { _date = picked; _manual.text = _format.format(picked); });
  }

  DateTime? _parseManual() {
    if (_date != null && _manual.text == _format.format(_date!)) return _date;
    final digits = _manual.text.replaceAll(RegExp(r'\\D'), '');
    if (digits.length == 8) {
      final normalized = '${digits.substring(0, 2)}.${digits.substring(2, 4)}.${digits.substring(4, 8)}';
      try { return _format.parseStrict(normalized); } catch (_) { return null; }
    }
    try { return _format.parseStrict(_manual.text.trim()); } catch (_) { return null; }
  }

  Future<void> _save() async {
    final date = _parseManual();
    if (date == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите дату в формате ДД.ММ.ГГГГ'))); return; }
    setState(() => _saving = true);
    try {
      await DatabaseService.instance.save(ExpiryRecord(name: widget.name, barcode: widget.barcode, expiryDate: DateFormat('yyyy-MM-dd').format(date), createdAt: DateTime.now().toIso8601String()));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  void dispose() { _manual.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.productFound ? 'Товар найден' : 'Нет в справочнике'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.productFound) Text(widget.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))\n      else const Text('Название будет пустым', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 8), const Text('Штрихкод', style: TextStyle(color: Colors.grey)),
      SelectableText(widget.barcode), const SizedBox(height: 18),
      const Text('Срок годности'), const SizedBox(height: 6),
      TextField(
        controller: _manual,
        keyboardType: TextInputType.number,
        inputFormatters: [DateDigitsFormatter()],
        decoration: InputDecoration(
          hintText: 'ДД.ММ.ГГГГ или 25122026',
          suffixIcon: IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate),
        ),
        onChanged: (_) => _date = null,
      ),
    ])),
    actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Отмена')), FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Сохранение…' : 'Сохранить'))],
  );
}

class DateDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 2 || i == 4) buffer.write('.');
      buffer.write(limited[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
