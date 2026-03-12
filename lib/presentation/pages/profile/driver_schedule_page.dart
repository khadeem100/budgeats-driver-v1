import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import 'package:driver/domain/di/dependency_manager.dart';
import 'package:driver/infrastructure/services/services.dart';
import 'package:driver/presentation/component/components.dart';
import 'package:driver/presentation/component/loading.dart';
import 'package:driver/presentation/styles/style.dart';

class DriverSchedulePage extends StatefulWidget {
  const DriverSchedulePage({super.key});

  @override
  State<DriverSchedulePage> createState() => _DriverSchedulePageState();
}

class _DriverSchedulePageState extends State<DriverSchedulePage> {
  final bool isLtr = LocalStorage.getLangLtr();
  final intl.DateFormat _dateFormat = intl.DateFormat('EEE, dd MMM yyyy');

  bool _loading = true;
  bool _saving = false;
  List<_DriverScheduleZoneItem> _zones = [];
  List<_DriverScheduleItem> _schedules = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final client = dioHttp.client(requireAuth: true);
      final results = await Future.wait([
        client.get('/api/v1/dashboard/deliveryman/schedule-zones'),
        client.get('/api/v1/dashboard/deliveryman/schedules', queryParameters: {
          'perPage': 50,
        }),
      ]);

      final zonesResponse = results[0].data;
      final schedulesResponse = results[1].data;

        final zonesPayload = zonesResponse['data'] ?? zonesResponse;
        final schedulesPayload = schedulesResponse['data'] ?? schedulesResponse;

        final zonesRaw = zonesPayload is List ? zonesPayload : <dynamic>[];
        final schedulesRaw = schedulesPayload is Map<String, dynamic>
          ? (schedulesPayload['data'] as List? ?? [])
          : (schedulesPayload is List ? schedulesPayload : <dynamic>[]);

      setState(() {
        _zones = zonesRaw
            .whereType<Map<String, dynamic>>()
            .map(_DriverScheduleZoneItem.fromJson)
            .toList();
        _schedules = schedulesRaw
            .whereType<Map<String, dynamic>>()
            .map(_DriverScheduleItem.fromJson)
            .toList();
      });
    } catch (e) {
      if (mounted) {
        AppHelpers.showCheckTopSnackBar(
          context,
          AppHelpers.errorHandler(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openScheduleSheet({_DriverScheduleItem? schedule}) async {
    final zoneIds = _zones.map((e) => e.id).toSet();
    int? selectedZoneId = schedule?.zone?.id ?? (_zones.isNotEmpty ? _zones.first.id : null);
    if (selectedZoneId != null && !zoneIds.contains(selectedZoneId)) {
      selectedZoneId = _zones.isNotEmpty ? _zones.first.id : null;
    }

    DateTime selectedDate = schedule?.shiftDate ?? DateTime.now();
    TimeOfDay selectedStart = _timeOfDayFromString(schedule?.startTime ?? '09:00:00');
    TimeOfDay selectedEnd = _timeOfDayFromString(schedule?.endTime ?? '17:00:00');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Style.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 13)),
              );

              if (picked != null) {
                setModalState(() {
                  selectedDate = picked;
                });
              }
            }

            Future<void> pickTime({required bool isStart}) async {
              final picked = await showTimePicker(
                context: context,
                initialTime: isStart ? selectedStart : selectedEnd,
              );

              if (picked != null) {
                setModalState(() {
                  if (isStart) {
                    selectedStart = picked;
                  } else {
                    selectedEnd = picked;
                  }
                });
              }
            }

            Future<void> submit() async {
              if (selectedZoneId == null) {
                AppHelpers.showCheckTopSnackBar(context, 'Select a zone first');
                return;
              }

              final startMinutes = selectedStart.hour * 60 + selectedStart.minute;
              final endMinutes = selectedEnd.hour * 60 + selectedEnd.minute;

              if (endMinutes <= startMinutes) {
                AppHelpers.showCheckTopSnackBar(context, 'End time must be after start time');
                return;
              }

              setModalState(() {
                _saving = true;
              });

              try {
                final client = dioHttp.client(requireAuth: true);
                final payload = {
                  'driver_schedule_zone_id': selectedZoneId,
                  'shift_date': intl.DateFormat('yyyy-MM-dd').format(selectedDate),
                  'start_time': _formatTimeOfDay(selectedStart),
                  'end_time': _formatTimeOfDay(selectedEnd),
                };

                if (schedule?.id != null) {
                  await client.put('/api/v1/dashboard/deliveryman/schedules/${schedule!.id}', data: payload);
                } else {
                  await client.post('/api/v1/dashboard/deliveryman/schedules', data: payload);
                }

                if (mounted) {
                  Navigator.of(context).pop();
                  await _load();
                }
              } catch (e) {
                if (mounted) {
                  AppHelpers.showCheckTopSnackBar(context, AppHelpers.errorHandler(e));
                }
              } finally {
                if (mounted) {
                  setModalState(() {
                    _saving = false;
                  });
                }
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: Style.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
              ),
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, MediaQuery.of(context).viewInsets.bottom + 24.h),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Style.iconColor,
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                      ),
                    ),
                    20.verticalSpace,
                    Text(
                      schedule == null ? 'Plan availability' : 'Edit availability',
                      style: Style.interSemi(size: 18.sp),
                    ),
                    8.verticalSpace,
                    Text(
                      'Drivers can schedule only within the next 14 days and per zone.',
                      style: Style.interRegular(size: 13.sp, color: Style.hintColor),
                    ),
                    20.verticalSpace,
                    Text('Zone', style: Style.interSemi(size: 14.sp)),
                    8.verticalSpace,
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        color: Style.greyColor,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedZoneId,
                          isExpanded: true,
                          items: _zones
                              .map(
                                (zone) => DropdownMenuItem<int>(
                                  value: zone.id,
                                  child: Text(zone.name, style: Style.interRegular(size: 14.sp)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setModalState(() {
                              selectedZoneId = value;
                            });
                          },
                        ),
                      ),
                    ),
                    16.verticalSpace,
                    Row(
                      children: [
                        Expanded(
                          child: _PickerTile(
                            label: 'Date',
                            value: _dateFormat.format(selectedDate),
                            icon: FlutterRemix.calendar_2_line,
                            onTap: pickDate,
                          ),
                        ),
                      ],
                    ),
                    12.verticalSpace,
                    Row(
                      children: [
                        Expanded(
                          child: _PickerTile(
                            label: 'Start',
                            value: _formatTimeOfDay(selectedStart),
                            icon: FlutterRemix.time_line,
                            onTap: () => pickTime(isStart: true),
                          ),
                        ),
                        12.horizontalSpace,
                        Expanded(
                          child: _PickerTile(
                            label: 'End',
                            value: _formatTimeOfDay(selectedEnd),
                            icon: FlutterRemix.time_line,
                            onTap: () => pickTime(isStart: false),
                          ),
                        ),
                      ],
                    ),
                    24.verticalSpace,
                    CustomButton(
                      title: schedule == null ? 'Submit availability' : 'Save changes',
                      isLoading: _saving,
                      onPressed: submit,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelSchedule(_DriverScheduleItem schedule) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      await client.delete('/api/v1/dashboard/deliveryman/schedules/${schedule.id}');
      if (mounted) {
        await _load();
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showCheckTopSnackBar(context, AppHelpers.errorHandler(e));
      }
    }
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule information'),
        content: const Text(
          'Plan your availability per delivery zone for the next 14 days. Every new shift request starts as pending. Admin can approve, deny, edit or assign schedules, and lateness plus driven kilometers are logged on approved shifts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Style.greyColor,
        body: Column(
          children: [
            CustomAppBar(
              bottomPadding: 16.h,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('My schedule', style: Style.interSemi(size: 18.sp)),
                  IconButton(
                    onPressed: _showInfo,
                    icon: Icon(FlutterRemix.information_line, size: 22.r, color: Style.black),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Loading()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 120.h),
                        children: [
                          Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: BoxDecoration(
                              color: Style.white,
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Zone planning', style: Style.interSemi(size: 16.sp)),
                                8.verticalSpace,
                                Text(
                                  'Choose a district zone, pick a date within the next two weeks, and set your available hours. Pending requests can still be edited before approval.',
                                  style: Style.interRegular(size: 13.sp, color: Style.hintColor),
                                ),
                              ],
                            ),
                          ),
                          16.verticalSpace,
                          if (_schedules.isEmpty)
                            Container(
                              padding: EdgeInsets.all(20.r),
                              decoration: BoxDecoration(
                                color: Style.white,
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              child: Column(
                                children: [
                                  Icon(FlutterRemix.calendar_todo_line, size: 42.r, color: Style.primaryColor),
                                  12.verticalSpace,
                                  Text('No availability planned yet', style: Style.interSemi(size: 16.sp)),
                                  6.verticalSpace,
                                  Text(
                                    'Add one or more shifts for the next 14 days. You do not need to fill every day.',
                                    style: Style.interRegular(size: 13.sp, color: Style.hintColor),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ..._schedules.map(
                            (schedule) => Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: Container(
                                padding: EdgeInsets.all(16.r),
                                decoration: BoxDecoration(
                                  color: Style.white,
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(schedule.zone?.name ?? 'Zone', style: Style.interSemi(size: 16.sp)),
                                              4.verticalSpace,
                                              Text(_dateFormat.format(schedule.shiftDate), style: Style.interRegular(size: 13.sp, color: Style.hintColor)),
                                            ],
                                          ),
                                        ),
                                        _StatusChip(status: schedule.status),
                                      ],
                                    ),
                                    12.verticalSpace,
                                    Wrap(
                                      spacing: 8.w,
                                      runSpacing: 8.h,
                                      children: [
                                        _MetricPill(icon: FlutterRemix.time_line, text: '${schedule.displayStartTime} - ${schedule.displayEndTime}'),
                                        _MetricPill(icon: FlutterRemix.navigation_line, text: schedule.zone?.district ?? 'No district'),
                                        _MetricPill(icon: FlutterRemix.road_map_line, text: '${schedule.trackedDistanceKm.toStringAsFixed(2)} km'),
                                        _MetricPill(icon: FlutterRemix.alarm_warning_line, text: 'Late ${schedule.effectiveLateMinutes} min'),
                                      ],
                                    ),
                                    if ((schedule.aiReason ?? '').isNotEmpty) ...[
                                      12.verticalSpace,
                                      Text('AI: ${schedule.aiReason}', style: Style.interRegular(size: 13.sp, color: Style.hintColor)),
                                    ],
                                    if ((schedule.adminNote ?? '').isNotEmpty) ...[
                                      8.verticalSpace,
                                      Text('Admin note: ${schedule.adminNote}', style: Style.interRegular(size: 13.sp, color: Style.hintColor)),
                                    ],
                                    if (schedule.logs.isNotEmpty) ...[
                                      12.verticalSpace,
                                      Text('Latest update', style: Style.interSemi(size: 13.sp)),
                                      6.verticalSpace,
                                      Text(
                                        '${schedule.logs.first.title} · ${schedule.logs.first.description ?? ''}',
                                        style: Style.interRegular(size: 13.sp, color: Style.hintColor),
                                      ),
                                    ],
                                    if (schedule.canEdit || schedule.canCancel) ...[
                                      14.verticalSpace,
                                      Row(
                                        children: [
                                          if (schedule.canEdit)
                                            Expanded(
                                              child: CustomButton(
                                                title: 'Edit',
                                                background: Style.transparent,
                                                borderColor: Style.black,
                                                textColor: Style.black,
                                                onPressed: () => _openScheduleSheet(schedule: schedule),
                                              ),
                                            ),
                                          if (schedule.canEdit && schedule.canCancel)
                                            12.horizontalSpace,
                                          if (schedule.canCancel)
                                            Expanded(
                                              child: CustomButton(
                                                title: 'Cancel',
                                                background: Style.redColor.withOpacity(0.1),
                                                textColor: Style.redColor,
                                                onPressed: () => _cancelSchedule(schedule),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterFloat,
        floatingActionButton: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          child: Row(
            children: [
              const PopButton(),
              10.horizontalSpace,
              Expanded(
                child: CustomButton(
                  title: 'Add availability',
                  icon: Icon(FlutterRemix.add_line, color: Style.white, size: 20.r),
                  onPressed: _zones.isEmpty ? null : _openScheduleSheet,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TimeOfDay _timeOfDayFromString(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: Style.greyColor,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20.r, color: Style.black),
            10.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Style.interRegular(size: 12.sp, color: Style.hintColor)),
                  2.verticalSpace,
                  Text(value, style: Style.interSemi(size: 14.sp)),
                ],
              ),
            ),
            Icon(FlutterRemix.arrow_right_s_line, size: 20.r, color: Style.black),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {
      'pending': const Color(0xFFF4B400),
      'approved': const Color(0xFF34A853),
      'denied': const Color(0xFFEA4335),
      'cancelled': Style.hintColor,
    };

    final color = map[status.toLowerCase()] ?? Style.primaryColor;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Text(
        status.toUpperCase(),
        style: Style.interSemi(size: 11.sp, color: color),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetricPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Style.greyColor,
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.r, color: Style.black),
          6.horizontalSpace,
          Text(text, style: Style.interRegular(size: 12.sp)),
        ],
      ),
    );
  }
}

class _DriverScheduleZoneItem {
  final int id;
  final String name;
  final String? district;

  const _DriverScheduleZoneItem({
    required this.id,
    required this.name,
    required this.district,
  });

  factory _DriverScheduleZoneItem.fromJson(Map<String, dynamic> json) {
    return _DriverScheduleZoneItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      district: json['district'],
    );
  }
}

class _DriverScheduleLogItem {
  final String title;
  final String? description;

  const _DriverScheduleLogItem({required this.title, this.description});

  factory _DriverScheduleLogItem.fromJson(Map<String, dynamic> json) {
    return _DriverScheduleLogItem(
      title: json['title'] ?? '',
      description: json['description'],
    );
  }
}

class _DriverScheduleItem {
  final int id;
  final DateTime shiftDate;
  final String startTime;
  final String endTime;
  final String status;
  final String? aiReason;
  final String? adminNote;
  final double trackedDistanceKm;
  final int lateMinutes;
  final int effectiveOfflineMinutes;
  final _DriverScheduleZoneItem? zone;
  final List<_DriverScheduleLogItem> logs;

  const _DriverScheduleItem({
    required this.id,
    required this.shiftDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.aiReason,
    required this.adminNote,
    required this.trackedDistanceKm,
    required this.lateMinutes,
    required this.effectiveOfflineMinutes,
    required this.zone,
    required this.logs,
  });

  factory _DriverScheduleItem.fromJson(Map<String, dynamic> json) {
    final logsRaw = (json['logs'] as List?) ?? const [];

    return _DriverScheduleItem(
      id: json['id'] ?? 0,
      shiftDate: DateTime.tryParse(json['shift_date'] ?? '') ?? DateTime.now(),
      startTime: json['start_time'] ?? '00:00:00',
      endTime: json['end_time'] ?? '00:00:00',
      status: json['status'] ?? 'pending',
      aiReason: json['ai_reason'],
      adminNote: json['admin_note'],
      trackedDistanceKm: double.tryParse('${json['tracked_distance_km'] ?? 0}') ?? 0,
      lateMinutes: json['late_minutes'] ?? 0,
      effectiveOfflineMinutes: json['effective_offline_minutes'] ?? 0,
      zone: json['zone'] is Map<String, dynamic> ? _DriverScheduleZoneItem.fromJson(json['zone']) : null,
      logs: logsRaw
          .whereType<Map<String, dynamic>>()
          .map(_DriverScheduleLogItem.fromJson)
          .toList(),
    );
  }

  String get displayStartTime => startTime.length >= 5 ? startTime.substring(0, 5) : startTime;

  String get displayEndTime => endTime.length >= 5 ? endTime.substring(0, 5) : endTime;

  int get effectiveLateMinutes => lateMinutes > 0 ? lateMinutes : effectiveOfflineMinutes;

  bool get canEdit => status == 'pending';

  bool get canCancel => status == 'pending' || status == 'approved';
}