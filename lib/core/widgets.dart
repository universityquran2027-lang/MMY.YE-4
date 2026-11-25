import 'package:flutter/material.dart';

enum FieldType { text, phone, multiline, date, dropdown }

class FieldSpec {
  const FieldSpec(this.key, this.label,
      {this.type = FieldType.text, this.required = false, this.options = const []});
  final String key, label;
  final FieldType type;
  final bool required;
  final List<(String value, String label)> options; // للقوائم المنسدلة
}

/// نافذة نموذج عامة (إضافة/تعديل) مع تحقق من الحقول الإلزامية واختيار التواريخ.
Future<Map<String, Object?>?> showRecordForm(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  Map<String, Object?> initial = const {},
}) {
  return showDialog<Map<String, Object?>>(
    context: context,
    builder: (_) => _RecordForm(title: title, fields: fields, initial: initial),
  );
}

class _RecordForm extends StatefulWidget {
  const _RecordForm({required this.title, required this.fields, required this.initial});
  final String title;
  final List<FieldSpec> fields;
  final Map<String, Object?> initial;
  @override
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late final Map<String, String?> _drop;

  @override
  void initState() {
    super.initState();
    _c = {for (final f in widget.fields) f.key: TextEditingController(text: '${widget.initial[f.key] ?? ''}')};
    _drop = {for (final f in widget.fields.where((f) => f.type == FieldType.dropdown))
      f.key: widget.initial[f.key] as String? ?? (f.required ? null : '')};
  }

  Future<void> _pickDate(FieldSpec f) async {
    final cur = DateTime.tryParse(_c[f.key]!.text) ?? DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: cur, firstDate: DateTime(1950), lastDate: DateTime(2100));
    if (d != null) _c[f.key]!.text = d.toIso8601String().substring(0, 10);
  }

  Widget _field(FieldSpec f) {
    String? req(String? v) => f.required && (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null;
    switch (f.type) {
      case FieldType.dropdown:
        return DropdownButtonFormField<String>(
          value: _drop[f.key] == '' ? null : _drop[f.key],
          decoration: InputDecoration(labelText: f.label),
          items: [for (final o in f.options) DropdownMenuItem(value: o.$1, child: Text(o.$2))],
          onChanged: (v) => _drop[f.key] = v,
          validator: (v) => f.required && v == null ? 'هذا الحقل مطلوب' : null,
        );
      case FieldType.date:
        return TextFormField(
          controller: _c[f.key], readOnly: true, onTap: () => _pickDate(f),
          decoration: InputDecoration(labelText: f.label, suffixIcon: const Icon(Icons.calendar_today_outlined)),
          validator: req,
        );
      case FieldType.phone:
        return TextFormField(
          controller: _c[f.key], keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: f.label),
          validator: (v) {
            final r = req(v);
            if (r != null) return r;
            if (v != null && v.trim().isNotEmpty && !RegExp(r'^[+0-9\s-]{6,20}$').hasMatch(v.trim())) {
              return 'رقم هاتف غير صالح';
            }
            return null;
          },
        );
      case FieldType.multiline:
        return TextFormField(controller: _c[f.key], minLines: 2, maxLines: 5,
            decoration: InputDecoration(labelText: f.label), validator: req);
      case FieldType.text:
        return TextFormField(controller: _c[f.key], decoration: InputDecoration(labelText: f.label), validator: req);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final f in widget.fields)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(f)),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final out = <String, Object?>{};
            for (final f in widget.fields) {
              final v = f.type == FieldType.dropdown ? (_drop[f.key] ?? '') : _c[f.key]!.text.trim();
              out[f.key] = v.isEmpty ? null : v;
            }
            Navigator.pop(context, out);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

Future<bool> confirm(BuildContext context, String message, {String action = 'حذف'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('تأكيد'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final good = status == 'active' || status == 'done';
    final bad = status == 'stopped' || status == 'cancelled';
    final cs = Theme.of(context).colorScheme;
    final color = bad ? cs.error : (good ? cs.primary : cs.onSurface.withValues(alpha: 0.6));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(statusLabels[status] ?? status, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center)));
}
