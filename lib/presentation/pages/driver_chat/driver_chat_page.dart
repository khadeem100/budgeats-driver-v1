import 'dart:async';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:driver/domain/di/dependency_manager.dart';
import 'package:driver/infrastructure/models/models.dart';
import 'package:driver/infrastructure/services/services.dart';
import 'package:driver/presentation/styles/style.dart';

@RoutePage()
class DriverChatPage extends StatefulWidget {
  const DriverChatPage({super.key});

  @override
  State<DriverChatPage> createState() => _DriverChatPageState();
}

class _DriverChatPageState extends State<DriverChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _orderIdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<DriverChatMessageData> _messages = [];
  DriverChatStatusData? _chatStatus;
  String _messageType = 'general';
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollTimer;

  int get _currentUserId => LocalStorage.getUser()?.id ?? 0;

  @override
  void initState() {
    super.initState();
    _fetchOverview();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _fetchOverview(scrollToBottom: false, showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _orderIdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchOverview({bool scrollToBottom = true, bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
      });
    }

    final response = await driverChatRepository.getOverview();
    response.when(
      success: (data) {
        if (!mounted) return;
        setState(() {
          _messages = data.data?.messages ?? [];
          _chatStatus = data.data?.chatStatus;
          _isLoading = false;
          if ((_chatStatus?.messageTypes?.isNotEmpty ?? false) &&
              !_chatStatus!.messageTypes!.contains(_messageType)) {
            _messageType = _chatStatus!.messageTypes!.first;
          }
        });
        if (scrollToBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
        }
      },
      failure: (error, statusCode) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || (_chatStatus?.isBanned ?? false)) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    final response = await driverChatRepository.sendMessage(
      message: text,
      messageType: _messageType,
      orderId: int.tryParse(_orderIdController.text.trim()),
    );

    response.when(
      success: (data) {
        if (!mounted) return;
        setState(() {
          _messages = [..._messages, data];
          _messageController.clear();
          _orderIdController.clear();
          _messageType = 'general';
        });
        _jumpToBottom();
      },
      failure: (error, statusCode) async {
        await _fetchOverview(scrollToBottom: false, showLoader: false);
      },
    );

    if (mounted) {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _reportMessage(DriverChatMessageData message) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report message'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Reason (optional)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Report'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      controller.dispose();
      return;
    }

    await driverChatRepository.reportMessage(
      messageId: message.id ?? 0,
      reason: result,
    );
    controller.dispose();
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return DateFormat('MMM d, HH:mm').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Style.greyColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Style.white,
        foregroundColor: Style.blackColor,
        title: const Text('Drivers Chat'),
      ),
      body: Column(
        children: [
          if (_chatStatus?.isBanned ?? false)
            Container(
              width: double.infinity,
              margin: EdgeInsets.all(16.r),
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Chat access suspended until ${_chatStatus?.chatBannedUntil ?? '-'}\n${_chatStatus?.chatBanReason ?? ''}',
                style: Style.interRegular(size: 12.sp, color: Colors.red.shade700),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Style.white,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Text(
                'Use this room for traffic updates, delivery help, and transfer coordination. Tag your assigned order ID to share the order details with other drivers.',
                style: Style.interRegular(size: 12.sp, color: Style.textGrey),
              ),
            ),
          ),
          12.verticalSpace,
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _fetchOverview(scrollToBottom: false),
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                      itemBuilder: (context, index) {
                        final item = _messages[index];
                        final isMine = item.sender?.id == _currentUserId;
                        return Align(
                          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 300.w),
                            child: Container(
                              padding: EdgeInsets.all(12.r),
                              decoration: BoxDecoration(
                                color: isMine ? Style.primaryColor : Style.white,
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.sender?.fullName.isNotEmpty == true
                                              ? item.sender!.fullName
                                              : 'Driver',
                                          style: Style.interSemi(
                                            size: 12.sp,
                                            color: isMine ? Style.white : Style.blackColor,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: isMine
                                              ? Colors.white24
                                              : Style.greyColor,
                                          borderRadius: BorderRadius.circular(20.r),
                                        ),
                                        child: Text(
                                          (item.messageType ?? 'general').toUpperCase(),
                                          style: Style.interSemi(
                                            size: 9.sp,
                                            color: isMine ? Style.white : Style.primaryColor,
                                          ),
                                        ),
                                      ),
                                      if (!isMine) ...[
                                        6.horizontalSpace,
                                        InkWell(
                                          onTap: () => _reportMessage(item),
                                          child: Icon(
                                            Icons.flag_outlined,
                                            size: 18.r,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  8.verticalSpace,
                                  Text(
                                    item.message ?? '',
                                    style: Style.interRegular(
                                      size: 13.sp,
                                      color: isMine ? Style.white : Style.blackColor,
                                    ),
                                  ),
                                  if (item.order != null) ...[
                                    10.verticalSpace,
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(10.r),
                                      decoration: BoxDecoration(
                                        color: isMine ? Colors.white24 : Style.greyColor,
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Order #${item.order?.id ?? '-'} • ${item.order?.status ?? ''}',
                                            style: Style.interSemi(
                                              size: 12.sp,
                                              color: isMine ? Style.white : Style.blackColor,
                                            ),
                                          ),
                                          4.verticalSpace,
                                          Text(
                                            item.order?.shop?.title ?? 'Tagged order',
                                            style: Style.interRegular(
                                              size: 12.sp,
                                              color: isMine ? Style.white : Style.blackColor,
                                            ),
                                          ),
                                          if ((item.order?.customer?.fullName ?? '').isNotEmpty)
                                            Text(
                                              'Customer: ${item.order?.customer?.fullName ?? ''}',
                                              style: Style.interRegular(
                                                size: 11.sp,
                                                color: isMine ? Style.white : Style.textGrey,
                                              ),
                                            ),
                                          if ((item.order?.addressText ?? '').isNotEmpty)
                                            Text(
                                              item.order?.addressText ?? '',
                                              style: Style.interRegular(
                                                size: 11.sp,
                                                color: isMine ? Style.white : Style.textGrey,
                                              ),
                                            ),
                                          if ((item.order?.note ?? '').isNotEmpty)
                                            Text(
                                              'Note: ${item.order?.note ?? ''}',
                                              style: Style.interRegular(
                                                size: 11.sp,
                                                color: isMine ? Style.white : Style.textGrey,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  8.verticalSpace,
                                  Text(
                                    _formatTime(item.createdAt),
                                    style: Style.interRegular(
                                      size: 10.sp,
                                      color: isMine ? Colors.white70 : Style.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => 10.verticalSpace,
                      itemCount: _messages.length,
                    ),
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: Style.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _messageType,
                        decoration: const InputDecoration(
                          labelText: 'Message type',
                        ),
                        items: (_chatStatus?.messageTypes ?? ['general', 'help', 'transfer'])
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(type.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (_chatStatus?.isBanned ?? false)
                            ? null
                            : (value) {
                                setState(() {
                                  _messageType = value ?? 'general';
                                });
                              },
                      ),
                    ),
                    12.horizontalSpace,
                    SizedBox(
                      width: 120.w,
                      child: TextField(
                        controller: _orderIdController,
                        enabled: !(_chatStatus?.isBanned ?? false),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Order ID',
                          hintText: 'Optional',
                        ),
                      ),
                    ),
                  ],
                ),
                12.verticalSpace,
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: !(_chatStatus?.isBanned ?? false),
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Write a traffic update, help request, or transfer note...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    12.horizontalSpace,
                    SizedBox(
                      height: 48.h,
                      child: FilledButton(
                        onPressed: (_chatStatus?.isBanned ?? false) || _isSending
                            ? null
                            : _sendMessage,
                        child: _isSending
                            ? SizedBox(
                                height: 18.r,
                                width: 18.r,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
