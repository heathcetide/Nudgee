import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';
import 'package:nudgee/features/timetable/presentation/timetable.dart';

/// 添加日程页面。
///
/// 用户可以填写任务名称、地点、备注，选择日期和时间段，
/// 保存后写入 SharedPreferences，今日日程页面会读取并显示。
class AddSchedulePage extends StatefulWidget {
  const AddSchedulePage({super.key});

  @override
  State<AddSchedulePage> createState() => _AddSchedulePageState();
}

class _AddSchedulePageState extends State<AddSchedulePage> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int _selectedSlotIndex = 0;
  bool _isSaving = false;

  /// SharedPreferences key for user-added schedules.
  static const String _prefsKey = 'user_schedules';

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String get _dateStr {
    final d = _selectedDate;
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    final l10n = context.l10n;

    if (_nameController.text.trim().isEmpty) {
      _showError(l10n.scheduleAddNameRequired);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final startTime = periodsStartTime[_selectedSlotIndex];
      final endTime = periodsEndTime[_selectedSlotIndex];
      final startMin = _timeToMinutes(startTime);
      final endMin = _timeToMinutes(endTime);

      final entry = {
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim().isEmpty
            ? '未指定'
            : _locationController.text.trim(),
        'startIndex': _selectedSlotIndex,
        'length': 1,
        'startTime': startTime,
        'endTime': endTime,
        'duration': endMin - startMin,
        'others': [
          {'key': '任务名称', 'value': _nameController.text.trim()},
          {'key': '地点', 'value': _locationController.text.trim().isEmpty ? '未指定' : _locationController.text.trim()},
          {'key': '备注', 'value': _noteController.text.trim().isEmpty ? '无' : _noteController.text.trim()},
          {'key': '时间', 'value': '$startTime - $endTime'},
        ],
      };

      // Read existing user schedules from SharedPreferences.
      final prefs = sl<SharedPrefsService>();
      final raw = prefs.getString(_prefsKey);
      Map<String, dynamic> userSchedules = {};
      if (raw != null) {
        userSchedules = jsonDecode(raw) as Map<String, dynamic>;
      }

      // Add entry to the date's extra list.
      final dateKey = _dateStr;
      if (userSchedules[dateKey] == null) {
        userSchedules[dateKey] = {'fixed': [], 'extra': []};
      }
      (userSchedules[dateKey]['extra'] as List).add(entry);

      await prefs.setString(_prefsKey, jsonEncode(userSchedules));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.scheduleAddSaved)),
        );
        GoRouter.of(context).pop();
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return PageScaffold(
      title: Text(l10n.scheduleAddTitle),
      leading: getPopLeading(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 任务名称
            _LabelField(label: l10n.scheduleAddTaskName),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: l10n.scheduleAddTaskNameHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.task_outlined),
              ),
            ),
            const SizedBox(height: 20),

            // 地点
            _LabelField(label: l10n.scheduleAddLocation),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: l10n.scheduleAddLocationHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 20),

            // 备注
            _LabelField(label: l10n.scheduleAddNote),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.scheduleAddNoteHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 20),

            // 日期选择
            _LabelField(label: l10n.scheduleAddDate),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 时间段选择
            _LabelField(label: l10n.scheduleAddTimeSlot),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(periodsStartTime.length, (i) {
                final selected = i == _selectedSlotIndex;
                return ChoiceChip(
                  label: Text('${periodsStartTime[i]} - ${periodsEndTime[i]}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedSlotIndex = i),
                  selectedColor: theme.colorScheme.primaryContainer,
                );
              }),
            ),
            const SizedBox(height: 32),

            // 保存按钮
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(l10n.scheduleAddSave),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelField extends StatelessWidget {
  final String label;
  const _LabelField({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
