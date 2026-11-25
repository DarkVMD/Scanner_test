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
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _dialogOpen = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_dialogOpen || !mounted) return;
    final code = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    // Only EAN-8 and EAN-13 barcodes are accepted by the app.
    if (!RegExp(r'^(\d{8}|\d{13})$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Некорректный штрихкод: допускается 8 или 13 цифр')),
      );
      return;
    }

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
    appBar: AppBar(
      title: const Text('Сканирование', style: TextStyle(fontWeight: FontWeight.w700)),
      actions: [IconButton(tooltip: 'Фонарик', onPressed: () => _controller.toggleTorch(), icon: const Icon(Icons.flashlight_on_rounded))],
    ),
    body: Column(children: [
      Expanded(child: MobileScanner(controller: _controller, onDetect: _onDetect)),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 17, 22, 22),
        decoration: const BoxDecoration(color: Color(0xFF151F30), borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: const Column(children: [
          Icon(Icons.center_focus_strong_rounded, color: Color(0xFF70B7FF), size: 25),
          SizedBox(height: 8),
          Text('Наведите камеру на штрихкод', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          SizedBox(height: 5),
          Text('Поддерживаются только EAN-8 и EAN-13', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF91A0B5), fontSize: 12)),
        ]),
      ),
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
  bool _calculateFromDuration = false;
  String _durationUnit = 'Дней';
  final _manual = TextEditingController();
  final _duration = TextEditingController();
  final _format = DateFormat('dd.MM.yyyy');

  DateTime? _parseDateText(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) {
      final normalized = '${digits.substring(0, 2)}.${digits.substring(2, 4)}.${digits.substring(4, 8)}';
      try { return _format.parseStrict(normalized); } catch (_) { return null; }
    }
    try { return _format.parseStrict(value.trim()); } catch (_) { return null; }
  }

  DateTime? get _calculatedExpiry {
    final start = _parseDateText(_manual.text);
    final amount = int.tryParse(_duration.text.trim());
    if (start == null || amount == null || amount < 1 || amount > 36500) return null;
    if (_durationUnit == 'Дней') return start.add(Duration(days: amount));
    final monthIndex = start.month - 1 + amount;
    final year = start.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, start.day > lastDay ? lastDay : start.day);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseDateText(_manual.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: _calculateFromDuration ? 'Дата начала срока' : 'Выберите срок годности',
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _manual.text = _format.format(picked);
      });
    }
  }

  DateTime? _expiryDate() {
    if (_calculateFromDuration) return _calculatedExpiry;
    if (_date != null && _manual.text == _format.format(_date!)) return _date;
    return _parseDateText(_manual.text);
  }

  Future<void> _save() async {
    final date = _expiryDate();
    if (date == null) {
      final message = _calculateFromDuration
          ? 'Проверьте дату начала и срок в днях или месяцах'
          : 'Введите дату в формате ДД.ММ.ГГГГ';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    setState(() => _saving = true);
    try {
      await DatabaseService.instance.save(ExpiryRecord(
        name: widget.name,
        barcode: widget.barcode,
        expiryDate: DateFormat('yyyy-MM-dd').format(date),
        createdAt: DateTime.now().toIso8601String(),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _manual.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calculated = _calculatedExpiry;
    return AlertDialog(
      title: Text(widget.productFound ? 'Товар найден' : 'Нет в справочнике'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.productFound)
            Text(widget.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
          else
            const Text('Наименование не обнаружено, можно сохранить штрихкод без названия', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Штрихкод', style: TextStyle(color: Colors.grey)),
          SelectableText(widget.barcode),
          const SizedBox(height: 14),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _calculateFromDuration,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Рассчитать срок автоматически', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            onChanged: (value) => setState(() {
              _calculateFromDuration = value ?? false;
              _manual.clear();
              _date = null;
            }),
          ),
          const SizedBox(height: 4),
          Text(_calculateFromDuration ? 'Дата начала срока' : 'Дата окончания срока годности', style: const TextStyle(color: Color(0xFF91A0B5))),
          const SizedBox(height: 6),
          TextField(
            controller: _manual,
            keyboardType: TextInputType.number,
            inputFormatters: [DateDigitsFormatter()],
            decoration: InputDecoration(
              hintText: 'ДД.ММ.ГГГГ',
              suffixIcon: IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate),
            ),
            onChanged: (_) => setState(() => _date = null),
          ),
          if (_calculateFromDuration) ...[
            const SizedBox(height: 13),
            const Text('Продолжительность срока', style: TextStyle(color: Color(0xFF91A0B5))),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                  decoration: const InputDecoration(hintText: 'Например, 30'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _durationUnit,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                  items: const [
                    DropdownMenuItem(value: 'Дней', child: Text('Дней')),
                    DropdownMenuItem(value: 'Месяцев', child: Text('Месяцев')),
                  ],
                  onChanged: (value) => setState(() => _durationUnit = value ?? 'Дней'),
                ),
              ),
            ]),
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1C344A), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.event_available_rounded, color: Color(0xFF70D6B0)),
                const SizedBox(width: 9),
                Expanded(child: Text(
                  calculated == null ? 'Укажите дату и продолжительность' : 'Дата окончания: ${_format.format(calculated)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )),
              ]),
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Сохранение…' : 'Сохранить')),
      ],
    );
  }
}

class DateDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 2 || i == 4) buffer.write('.');
      buffer.write(limited[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
