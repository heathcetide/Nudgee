import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/models/schedule_model.dart';
import 'package:nudgee/core/services/schedule_service.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// 添加日程页面。
///
/// 用户可以填写任务名称、地点、备注，选择日期和自定义起止时间，
/// 保存后写入 SharedPreferences，今日日程页面会读取并显示。
class AddSchedulePage extends StatefulWidget {
  /// 编辑模式时传入的日程项；null 表示新增模式。
  final ScheduleItem? editItem;

  const AddSchedulePage({super.key, this.editItem});

  @override
  State<AddSchedulePage> createState() => _AddSchedulePageState();
}

class _AddSchedulePageState extends State<AddSchedulePage> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 15);
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 编辑模式：预填充已有数据。
    if (widget.editItem != null) {
      final item = widget.editItem!;
      _nameController.text = item.name;
      _locationController.text = item.location == '未指定' ? '' : item.location;
      _noteController.text = item.note == '无' ? '' : item.note;
      _selectedDate = DateTime.parse(item.date);
      _startTime = _parseTime(item.startTime);
      _endTime = _parseTime(item.endTime);
    }
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

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

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? '选择开始时间' : '选择结束时间',
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // 如果开始时间晚于结束时间，自动调整结束时间
          if (_toMinutes(picked) >= _toMinutes(_endTime)) {
            _endTime = TimeOfDay(
              hour: picked.hour,
              minute: picked.minute + 15 >= 60
                  ? (picked.minute + 15) % 60
                  : picked.minute + 15,
            );
            if (_endTime.minute < picked.minute) {
              _endTime = TimeOfDay(hour: picked.hour + 1, minute: _endTime.minute);
            }
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

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

    // 校验结束时间必须晚于开始时间
    if (_toMinutes(_endTime) <= _toMinutes(_startTime)) {
      _showError(l10n.scheduleAddSelectTimeSlot);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final startTime = _formatTime(_startTime);
      final endTime = _formatTime(_endTime);
      final startMin = _toMinutes(_startTime);
      final endMin = _toMinutes(_endTime);

      // 计算 startIndex：用开始时间相对 06:00 的偏移估算（用于 timetable 网格定位）
      const dayStartMinutes = 6 * 60; // 06:00
      final startIndex = ((startMin - dayStartMinutes) / 60).round().clamp(0, 17);
      // length: 占用的时段数（向上取整）
      final length = ((endMin - startMin) / 60).ceil().clamp(1, 18 - startIndex);

      final isEditing = widget.editItem != null;
      final item = ScheduleItem(
        id: isEditing
            ? widget.editItem!.id
            : '${_dateStr}_${startTime}_${_nameController.text.trim()}',
        name: _nameController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? '未指定'
            : _locationController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? '无'
            : _noteController.text.trim(),
        date: _dateStr,
        startTime: startTime,
        endTime: endTime,
        startIndex: startIndex,
        length: length,
        isExtra: false,
      );

      if (isEditing) {
        await sl<ScheduleService>().updateSchedule(item);
      } else {
        await sl<ScheduleService>().addSchedule(item);
      }

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

            // 开始时间 & 结束时间
            Row(
              children: [
                // 开始时间
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LabelField(label: '开始时间'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _pickTime(true),
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(
                            _formatTime(_startTime),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 结束时间
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LabelField(label: '结束时间'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _pickTime(false),
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.access_time_filled),
                          ),
                          child: Text(
                            _formatTime(_endTime),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
