import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/core.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/widgets/widgets.dart';
import 'package:nudgee/features/home/presentation/home_helpers.dart';

// ═══════════════════════════════════════════════════════════════════════
// Tab 2: Components Showcase
// ═══════════════════════════════════════════════════════════════════════

class ComponentsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LingScaffold(
      title: '组件库',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner ──────────────────────────────────────────────
              SectionTitle('Banner'),
              LingBanner(
                message: '这是一条信息提示',
                variant: LingBannerVariant.info,
                onDismiss: () {},
              ),
              const SizedBox(height: 8),
              LingBanner(
                message: '操作成功完成',
                variant: LingBannerVariant.success,
                onDismiss: () {},
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Badge ───────────────────────────────────────────────
              SectionTitle('Badge'),
              Row(
                children: [
                  LingBadge.count(count: 5, child: const Icon(Icons.notifications, size: 32)),
                  const SizedBox(width: 24),
                  LingBadge.count(count: 99, child: const Icon(Icons.email, size: 32)),
                  const SizedBox(width: 24),
                  LingBadge.count(count: 100, child: const Icon(Icons.chat, size: 32)),
                  const SizedBox(width: 24),
                  LingBadge.dot(child: const Icon(Icons.person, size: 32)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const LingBadge(label: 'New'),
                  const SizedBox(width: 8),
                  LingBadge(label: 'Hot', variant: LingBadgeVariant.outlined, color: AppColors.error),
                  const SizedBox(width: 8),
                  LingBadge(label: 'Beta', variant: LingBadgeVariant.filled, color: AppColors.secondary),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Avatar ──────────────────────────────────────────────
              SectionTitle('Avatar'),
              Row(
                children: [
                  const LingAvatar(name: '张三', size: LingAvatarSize.md),
                  const SizedBox(width: 12),
                  const LingAvatar(name: 'Li Si', size: LingAvatarSize.md),
                  const SizedBox(width: 12),
                  LingAvatar(
                    name: '王五',
                    size: LingAvatarSize.md,
                    showOnlineStatus: true,
                    isOnline: true,
                  ),
                  const SizedBox(width: 12),
                  LingAvatar(
                    name: '赵六',
                    size: LingAvatarSize.md,
                    showOnlineStatus: true,
                    isOnline: false,
                  ),
                  const SizedBox(width: 12),
                  LingAvatar(
                    icon: Icons.group,
                    size: LingAvatarSize.md,
                    showRing: true,
                    ringColor: AppColors.activeSpeakerGlow,
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Buttons ─────────────────────────────────────────────
              SectionTitle('Buttons'),
              Wrap(
                spacing: AppConstants.spacingSm,
                runSpacing: AppConstants.spacingSm,
                children: [
                  LingButton(label: 'Filled', icon: Icons.check,
                      onPressed: () => LingSnackbar.success(context, 'Filled')),
                  LingButton(label: 'Outlined', variant: LingButtonVariant.outlined,
                      onPressed: () => LingSnackbar.info(context, 'Outlined')),
                  LingButton(label: 'Text', variant: LingButtonVariant.text,
                      onPressed: () => LingSnackbar.info(context, 'Text')),
                  LingButton(label: 'Tonal', variant: LingButtonVariant.tonal,
                      onPressed: () => LingSnackbar.info(context, 'Tonal')),
                  LingButton(label: 'Loading', loading: true, onPressed: () {}),
                  const LingButton(label: 'Disabled', onPressed: null),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Icon Buttons (call controls) ────────────────────────
              SectionTitle('Icon Buttons (Call Controls)'),
              Row(
                children: [
                  LingIconButton(icon: Icons.mic, active: true, tooltip: 'Mute',
                      onPressed: () => LingSnackbar.info(context, 'Mic toggled')),
                  const SizedBox(width: AppConstants.spacingSm),
                  LingIconButton(icon: Icons.mic_off, activeColor: AppColors.muteRed, tooltip: 'Unmute',
                      onPressed: () => LingSnackbar.info(context, 'Mic off')),
                  const SizedBox(width: AppConstants.spacingSm),
                  LingIconButton(icon: Icons.videocam, tooltip: 'Camera on',
                      onPressed: () => LingSnackbar.info(context, 'Camera')),
                  const SizedBox(width: AppConstants.spacingSm),
                  LingIconButton(icon: Icons.videocam_off, activeColor: AppColors.videoOffGray, active: true,
                      tooltip: 'Camera off',
                      onPressed: () => LingSnackbar.info(context, 'Camera off')),
                  const SizedBox(width: AppConstants.spacingSm),
                  LingIconButton(icon: Icons.call_end, activeColor: AppColors.muteRed, active: true, size: 56,
                      tooltip: 'Hang up',
                      onPressed: () => LingSnackbar.error(context, 'Call ended')),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Chips ───────────────────────────────────────────────
              SectionTitle('Chips / Tags'),
              LingChipGroup(
                chips: [
                  LingChip(label: 'Flutter'),
                  LingChip(label: 'WebRTC', variant: LingChipVariant.tonal),
                  LingChip(label: 'Go', variant: LingChipVariant.outlined),
                  LingChip(label: 'Rust', variant: LingChipVariant.filled, color: AppColors.secondary),
                  LingChip(label: 'Audio', icon: Icons.graphic_eq),
                  LingChip(label: 'Video', icon: Icons.videocam_outlined, variant: LingChipVariant.tonal),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Text Fields ─────────────────────────────────────────
              SectionTitle('Text Fields'),
              const LingTextField(label: 'Room ID', hint: 'Enter room ID', prefixIcon: Icons.meeting_room),
              const SizedBox(height: AppConstants.spacingSm),
              const LingTextField(label: 'Password', hint: 'Room password', prefixIcon: Icons.lock, obscureText: true),
              const SizedBox(height: AppConstants.spacingSm),
              const LingTextArea(label: 'Description', hint: 'Enter room description...', minLines: 3, showCounter: true, maxLength: 200),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Switch ──────────────────────────────────────────────
              SectionTitle('Switch'),
              LingCard(
                child: Column(
                  children: [
                    StatefulSwitch(label: 'Enable microphone', description: 'Allow others to hear you'),
                    const LingDivider(),
                    StatefulSwitch(label: 'Enable camera', description: 'Allow others to see you'),
                    const LingDivider(),
                    StatefulSwitch(label: 'Enable noise suppression', description: 'Reduce background noise'),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Slider ──────────────────────────────────────────────
              SectionTitle('Slider'),
              LingCard(
                child: Column(
                  children: [
                    StatefulSlider(label: 'Volume', min: 0, max: 100, valueFormatter: (v) => '${v.toInt()}%'),
                    StatefulSlider(label: 'Mic sensitivity', min: 0, max: 100, valueFormatter: (v) => '${v.toInt()}%'),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Segmented Control ───────────────────────────────────
              SectionTitle('Segmented Control'),
              StatefulSegmented(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Progress ────────────────────────────────────────────
              SectionTitle('Progress'),
              LingCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LingLinearProgress(value: 0.3, label: 'Downloading', showPercentage: true),
                    const SizedBox(height: 16),
                    const LingLinearProgress(value: 0.75, label: 'Uploading', showPercentage: true),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        LingCircularProgress(value: 0.25, centerLabel: '25%'),
                        LingCircularProgress(value: 0.60, centerLabel: '60%'),
                        LingCircularProgress(value: 1.0, centerLabel: '100%'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── List Items ──────────────────────────────────────────
              SectionTitle('List Items'),
              LingListSection(
                title: 'Settings',
                children: [
                  LingListItem(leadingIcon: Icons.person, title: 'Account', subtitle: 'Manage your account',
                      trailing: const Icon(Icons.chevron_right), onTap: () => LingSnackbar.info(context, 'Account')),
                  LingListItem(leadingIcon: Icons.lock, title: 'Privacy', subtitle: 'Privacy settings',
                      trailing: const Icon(Icons.chevron_right), onTap: () => LingSnackbar.info(context, 'Privacy')),
                  LingListItem(leadingIcon: Icons.notifications, title: 'Notifications',
                      trailing: const Icon(Icons.chevron_right), onTap: () => LingSnackbar.info(context, 'Notifications')),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Divider ─────────────────────────────────────────────
              SectionTitle('Divider'),
              const LingDivider(),
              const SizedBox(height: 8),
              const LingDivider(label: 'OR'),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Dialogs ─────────────────────────────────────────────
              SectionTitle('Dialogs'),
              Wrap(
                spacing: AppConstants.spacingSm,
                runSpacing: AppConstants.spacingSm,
                children: [
                  LingButton(label: 'Confirm', variant: LingButtonVariant.outlined, icon: Icons.help_outline,
                      onPressed: () async {
                        final result = await LingDialog.confirm(context, title: 'Join Room',
                            content: 'Are you sure you want to join this room?');
                        if (result == true && context.mounted) LingSnackbar.success(context, 'Joined!');
                      }),
                  LingButton(label: 'Alert', variant: LingButtonVariant.outlined, icon: Icons.info_outline,
                      onPressed: () => LingDialog.alert(context, title: 'About Nudgee',
                          content: 'Nudgee is a Flutter client for LingVoice.')),
                  LingButton(label: 'Destructive', variant: LingButtonVariant.outlined, icon: Icons.delete_outline,
                      foregroundColor: AppColors.error,
                      onPressed: () async {
                        final result = await LingDialog.confirm(context, title: 'Delete Recording',
                            content: 'This action cannot be undone.', confirmLabel: 'Delete', isDestructive: true);
                        if (result == true && context.mounted) LingSnackbar.warning(context, 'Deleted');
                      }),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Empty State ─────────────────────────────────────────
              SectionTitle('Empty State'),
              LingCard(
                child: LingEmptyState(
                  icon: Icons.history,
                  title: 'No Call History',
                  message: 'Your recent calls will appear here',
                  action: LingButton(label: 'Start a Call', icon: Icons.call, onPressed: () {}),
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Error View ──────────────────────────────────────────
              SectionTitle('Error View'),
              LingCard(
                child: LingErrorView(
                  error: const NetworkException('Failed to connect to server'),
                  onRetry: () => LingSnackbar.info(context, 'Retrying...'),
                ),
              ),
              const SizedBox(height: AppConstants.spacingXxl),

              // ── Skeleton Loading ─────────────────────────────────────
              SectionTitle('Skeleton Loading'),
              StatefulSkeleton(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Nine Grid ────────────────────────────────────────────
              SectionTitle('Nine Grid (图片九宫格)'),
              LingCard(
                child: LingNineGrid(
                  urls: List.generate(6, (i) => 'https://picsum.photos/200/200?random=$i'),
                  maxWidth: 240,
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Loading Queue ────────────────────────────────────────
              SectionTitle('Loading Queue'),
              LingButton(
                label: 'Show Loading 2s',
                icon: Icons.hourglass_top,
                onPressed: () {
                  loadingQueue.show('Loading...', context);
                  Future.delayed(const Duration(seconds: 2), loadingQueue.dismiss);
                },
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Tooltip ─────────────────────────────────────────────
              SectionTitle('Tooltip'),
              Row(
                children: [
                  LingTooltip(
                    message: '这是一条深色提示',
                    child: const Icon(Icons.info, size: 28),
                  ),
                  const SizedBox(width: 24),
                  LingTooltip(
                    message: '彩色提示',
                    variant: LingTooltipVariant.colored,
                    color: AppColors.secondary,
                    child: const Icon(Icons.lightbulb, size: 28),
                  ),
                  const SizedBox(width: 24),
                  LingTooltip(
                    message: '浅色提示',
                    variant: LingTooltipVariant.light,
                    child: const Icon(Icons.help, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Bottom Sheet ────────────────────────────────────────
              SectionTitle('Bottom Sheet'),
              Wrap(
                spacing: AppConstants.spacingSm,
                runSpacing: AppConstants.spacingSm,
                children: [
                  LingButton(
                    label: 'Modal Sheet',
                    variant: LingButtonVariant.outlined,
                    icon: Icons.layers,
                    onPressed: () => LingBottomSheet.show(
                      context: context,
                      title: '标题',
                      subtitle: '这是一个底部弹窗',
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('这里是 Bottom Sheet 的内容区域。可以放置任意 Widget。'),
                      ),
                    ),
                  ),
                  LingButton(
                    label: 'Action Sheet',
                    variant: LingButtonVariant.outlined,
                    icon: Icons.list,
                    onPressed: () => LingBottomSheet.showActions<String>(
                      context: context,
                      title: '请选择操作',
                      actions: [
                        const LingSheetAction(value: 'save', label: '保存', icon: Icons.save),
                        const LingSheetAction(value: 'share', label: '分享', icon: Icons.share),
                        const LingSheetAction(value: 'delete', label: '删除', icon: Icons.delete, isDestructive: true),
                      ],
                    ).then((result) {
                      if (result != null) LingSnackbar.info(context, '选择了: $result');
                    }),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Dropdown ────────────────────────────────────────────
              SectionTitle('Dropdown'),
              StatefulDropdown(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Rating ──────────────────────────────────────────────
              SectionTitle('Rating'),
              StatefulRating(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Stepper ─────────────────────────────────────────────
              SectionTitle('Stepper'),
              StatefulStepper(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── OTP Input ───────────────────────────────────────────
              SectionTitle('OTP Input'),
              LingOtpInput(
                length: 6,
                onChanged: (code) {},
                onCompleted: (code) => LingSnackbar.success(context, '验证码: $code'),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Countdown ───────────────────────────────────────────
              SectionTitle('Countdown'),
              Row(
                children: [
                  LingCountdown(
                    duration: const Duration(seconds: 60),
                    variant: LingCountdownVariant.text,
                  ),
                  const SizedBox(width: 24),
                  LingCountdown(
                    duration: const Duration(seconds: 30),
                    variant: LingCountdownVariant.box,
                  ),
                  const SizedBox(width: 24),
                  LingCountdown(
                    duration: const Duration(seconds: 45),
                    variant: LingCountdownVariant.circular,
                    size: 56,
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── FAB ─────────────────────────────────────────────────
              SectionTitle('Floating Action Button'),
              Row(
                children: [
                  LingFab(icon: Icons.add, size: LingFabSize.small, heroTag: 'fab_small', onPressed: () {}),
                  const SizedBox(width: 16),
                  LingFab(icon: Icons.edit, heroTag: 'fab_edit', onPressed: () {}),
                  const SizedBox(width: 16),
                  LingFab(
                    icon: Icons.favorite,
                    size: LingFabSize.regular,
                    heroTag: 'fab_heart',
                    gradient: const LinearGradient(
                      colors: [AppColors.error, AppColors.secondary],
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Marquee ─────────────────────────────────────────────
              SectionTitle('Marquee (跑马灯)'),
              LingMarquee(
                backgroundColor: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.campaign, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Text('这是一条滚动通知 — Nudgee 组件库演示中 ', style: context.theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Timeline ────────────────────────────────────────────
              SectionTitle('Timeline (时间线)'),
              LingCard(
                child: LingTimeline(
                  items: const [
                    LingTimelineItem(
                      title: '通话已结束',
                      subtitle: '时长 12:34',
                      icon: Icons.call_end,
                      isHighlighted: true,
                    ),
                    LingTimelineItem(
                      title: '加入房间',
                      subtitle: 'room-abc-123',
                      icon: Icons.login,
                    ),
                    LingTimelineItem(
                      title: '请求麦克风权限',
                      subtitle: '已授权',
                      icon: Icons.mic,
                    ),
                    LingTimelineItem(
                      title: '应用启动',
                      icon: Icons.rocket_launch,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Image Cropper ───────────────────────────────────────
              SectionTitle('Image Cropper (图片裁剪)'),
              LingButton(
                label: '打开裁剪器',
                variant: LingButtonVariant.outlined,
                icon: Icons.crop,
                onPressed: () => LingSnackbar.info(context, '需要传入图片 bytes 后跳转 LingImageCropper 页面'),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Audio Player ────────────────────────────────────────
              SectionTitle('Audio Player'),
              LingAudioPlayer(
                url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
                title: 'SoundHelix Song 1',
                subtitle: 'Demo Audio',
                variant: LingAudioPlayerVariant.compact,
              ),
              const SizedBox(height: 8),
              LingAudioPlayer(
                url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
                title: 'SoundHelix Song 2',
                subtitle: 'Full Player Demo',
                variant: LingAudioPlayerVariant.full,
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Video Player ────────────────────────────────────────
              SectionTitle('Video Player'),
              LingVideoPlayer(
                url: 'https://cdn.lingecho.com/jieji/boot/boot_loading.mp4',
                autoPlay: true,
                loop: true,
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Waveform ────────────────────────────────────────────
              SectionTitle('Waveform (音频波形)'),
              StatefulWaveform(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Volume Slider ───────────────────────────────────────
              SectionTitle('Volume Slider'),
              StatefulVolume(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Typing Indicator ────────────────────────────────
              SectionTitle('IM · Typing Indicator'),
              const LingTypingIndicator(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Message Bubble ──────────────────────────────────
              SectionTitle('IM · Message Bubble'),
              const ImBubbleDemo(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Quick Reaction ──────────────────────────────────
              SectionTitle('IM · Quick Reaction Bar'),
              LingQuickReactionBar(
                onReactionSelected: (emoji) => LingSnackbar.info(context, 'Reaction: $emoji'),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Emoji Picker ────────────────────────────────────
              SectionTitle('IM · Emoji Picker'),
              const ImEmojiDemo(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Message Tooltip ─────────────────────────────────
              SectionTitle('IM · Message Tooltip'),
              LingButton(
                label: '长按操作菜单',
                icon: Icons.more_horiz,
                variant: LingButtonVariant.outlined,
                onPressed: () => _showMessageTooltipDemo(context),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Message Recalled ────────────────────────────────
              SectionTitle('IM · Message Recalled'),
              const LingMessageRecalled(text: '你撤回了一条消息'),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Message Multi Select ────────────────────────────
              SectionTitle('IM · Message Multi Select'),
              LingMessageMultiSelect(
                selectedCount: 3,
                actions: [
                  LingMultiSelectAction(label: '转发', icon: Icons.shortcut, onTap: () => LingSnackbar.info(context, '转发 3 条消息')),
                  LingMultiSelectAction(label: '收藏', icon: Icons.star_outline, onTap: () => LingSnackbar.info(context, '收藏 3 条消息')),
                  LingMultiSelectAction(label: '删除', icon: Icons.delete_outline, onTap: () => LingSnackbar.info(context, '删除 3 条消息')),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Message Edit Banner ─────────────────────────────
              SectionTitle('IM · Message Edit Banner'),
              LingMessageEdit(
                originalText: '这是要编辑的原消息内容...',
                onCancel: () => LingSnackbar.info(context, '取消编辑'),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Link Preview ────────────────────────────────────
              SectionTitle('IM · Link Preview'),
              LingLinkPreview(
                title: 'Flutter — Beautiful apps in record time',
                description: 'Flutter is Google\'s portable UI toolkit for building applications across mobile, web, and desktop.',
                imageUrl: 'https://flutter.dev/images/flutter-logo-sharing.png',
                url: 'https://flutter.dev',
                onTap: () => LingSnackbar.info(context, '打开链接'),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Conversation Draft ──────────────────────────────
              SectionTitle('IM · Conversation Draft'),
              const LingConversationDraft(draftText: '这是一段未发送的草稿内容'),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Total Unread Badge ──────────────────────────────
              SectionTitle('IM · Total Unread Badge'),
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      children: [
                        const Center(child: Icon(Icons.notifications, size: 28)),
                        const LingTotalUnreadBadge(count: 5),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      children: [
                        const Center(child: Icon(Icons.notifications, size: 28)),
                        const LingTotalUnreadBadge(count: 99),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      children: [
                        const Center(child: Icon(Icons.notifications, size: 28)),
                        const LingTotalUnreadBadge(count: 100),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      children: [
                        const Center(child: Icon(Icons.notifications, size: 28)),
                        const LingTotalUnreadBadge(count: 0),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Group Avatar ────────────────────────────────────
              SectionTitle('IM · Group Avatar'),
              Row(
                children: [
                  LingGroupAvatar(
                    avatarUrls: [null, null, null, null],
                    names: ['张三', '李四', '王五', '赵六'],
                  ),
                  const SizedBox(width: 16),
                  LingGroupAvatar(
                    avatarUrls: [null, null],
                    names: ['Alice', 'Bob'],
                  ),
                  const SizedBox(width: 16),
                  LingGroupAvatar(
                    avatarUrls: [null],
                    names: ['单人'],
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Voice Recorder ──────────────────────────────────
              SectionTitle('IM · Voice Recorder'),
              const ImVoiceRecorderDemo(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Image Picker Preview ────────────────────────────
              SectionTitle('IM · Image Picker Preview'),
              LingImagePickerPreview(
                imagePaths: const [],
                onAdd: () => LingSnackbar.info(context, '选择图片'),
                onRemove: (i) {},
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: At Mention Panel ────────────────────────────────
              SectionTitle('IM · At Mention Panel'),
              const ImAtMentionDemo(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Chat Background ─────────────────────────────────
              SectionTitle('IM · Chat Background'),
              const ImChatBgDemo(),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Group Announcement ──────────────────────────────
              SectionTitle('IM · Group Announcement'),
              LingGroupAnnouncement(
                title: '群公告',
                content: '欢迎大家加入 Nudgee 开发群！请遵守群规，文明交流。本周五下午 3 点有技术分享会，欢迎大家参加。',
                publisherName: '群主',
                publishedAt: DateTime.now(),
                canEdit: true,
                onEdit: () => LingSnackbar.info(context, '编辑公告'),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Date Separator ──────────────────────────────────
              SectionTitle('IM · Date Separator'),
              LingMessageDateSeparator(date: DateTime.now()),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Online Status ───────────────────────────────────
              SectionTitle('IM · Online Status'),
              Row(
                children: [
                  const LingOnlineStatus(status: LingUserStatus.online, showLabel: true),
                  const SizedBox(width: 16),
                  const LingOnlineStatus(status: LingUserStatus.away, showLabel: true),
                  const SizedBox(width: 16),
                  const LingOnlineStatus(status: LingUserStatus.busy, showLabel: true),
                  const SizedBox(width: 16),
                  const LingOnlineStatus(status: LingUserStatus.offline, showLabel: true),
                  const SizedBox(width: 16),
                  const LingOnlineStatus(status: LingUserStatus.invisible, showLabel: true),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Message Status Indicator ────────────────────────
              SectionTitle('IM · Message Status Indicator'),
              Row(
                children: [
                  const LingMessageStatusIndicator(status: LingMessageStatus.sending),
                  const SizedBox(width: 20),
                  const LingMessageStatusIndicator(status: LingMessageStatus.sent),
                  const SizedBox(width: 20),
                  const LingMessageStatusIndicator(status: LingMessageStatus.delivered),
                  const SizedBox(width: 20),
                  const LingMessageStatusIndicator(status: LingMessageStatus.read),
                  const SizedBox(width: 20),
                  LingMessageStatusIndicator(
                    status: LingMessageStatus.failed,
                    onResend: () => LingSnackbar.info(context, '重发消息'),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Message Reply ───────────────────────────────────
              SectionTitle('IM · Message Reply'),
              LingMessageReply(
                replyQuote: const LingReplyQuote(
                  messageId: '1',
                  authorId: 'other',
                  authorName: '张三',
                  messageType: LingMessageType.text,
                  preview: '这是被引用的原始消息内容',
                ),
                authorName: '张三',
                onClose: () => LingSnackbar.info(context, '取消回复'),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Message Quote ───────────────────────────────────
              SectionTitle('IM · Message Quote'),
              LingMessageQuote(
                quote: const LingReplyQuote(
                  messageId: '1',
                  authorId: 'other',
                  authorName: '张三',
                  messageType: LingMessageType.text,
                  preview: '这是被引用的原始消息内容，可以显示最多三行，超出部分会省略号截断。',
                ),
                authorName: '张三',
                onTap: () => LingSnackbar.info(context, '跳转到原消息'),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Message Star ────────────────────────────────────
              SectionTitle('IM · Message Star'),
              Row(
                children: [
                  const LingMessageStar(isStarred: true),
                  const SizedBox(width: 20),
                  LingMessageStar(
                    isStarred: false,
                    onTap: () => LingSnackbar.info(context, '收藏消息'),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Unread Divider ──────────────────────────────────
              SectionTitle('IM · Unread Divider'),
              const LingUnreadDivider(count: 5),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Typing Status ───────────────────────────────────
              SectionTitle('IM · Typing Status'),
              const LingTypingStatus(userNames: ['张三']),
              const SizedBox(height: 4),
              const LingTypingStatus(userNames: ['张三', '李四']),
              const SizedBox(height: 4),
              const LingTypingStatus(userNames: ['张三', '李四', '王五', '赵六']),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Scroll To Bottom ────────────────────────────────
              SectionTitle('IM · Scroll To Bottom'),
              SizedBox(
                height: 60,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: LingMessageScrollToBottom(
                        unreadCount: 3,
                        onTap: () => LingSnackbar.info(context, '滚动到底部'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Load More ───────────────────────────────────────
              SectionTitle('IM · Load More'),
              LingMessageLoadMore(
                isLoading: false,
                onLoadMore: () => LingSnackbar.info(context, '加载更多'),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── IM: Report ──────────────────────────────────────────
              SectionTitle('IM · Message Report'),
              LingButton(
                label: '举报消息',
                icon: Icons.flag_outlined,
                variant: LingButtonVariant.outlined,
                onPressed: () => LingMessageReport.show(
                  context,
                  onSubmit: (reason, desc) => LingSnackbar.info(context, '举报: $reason'),
                ),
              ),
              const SizedBox(height: AppConstants.spacingXxl),

              // ── Bluetooth: Status ───────────────────────────────────
              SectionTitle('Bluetooth · Status'),
              Row(
                children: [
                  const LingBluetoothStatus(state: LingBluetoothState.ready),
                  const SizedBox(width: 12),
                  const LingBluetoothStatus(state: LingBluetoothState.poweredOff),
                  const SizedBox(width: 12),
                  const LingBluetoothStatus(state: LingBluetoothState.unauthorized),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Upload: Progress ────────────────────────────────────
              SectionTitle('Upload · Progress'),
              LingUploadProgress(
                task: UploadTask(
                  id: 'demo1',
                  filePath: '/tmp/demo.jpg',
                  fileName: 'demo_image.jpg',
                  fileSize: 1024 * 512,
                  mimeType: 'image/jpeg',
                  status: UploadStatus.uploading,
                  progress: 0.65,
                  uploadedBytes: (1024 * 512 * 0.65).round(),
                  totalBytes: 1024 * 512,
                  createdAt: DateTime.now(),
                ),
                onCancel: () => LingSnackbar.info(context, '取消上传'),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // ── Logger Demo ─────────────────────────────────────────
              SectionTitle('Logger · Demo'),
              LingButton(
                label: '测试日志输出',
                icon: Icons.terminal,
                variant: LingButtonVariant.outlined,
                onPressed: () {
                  final logger = sl<LoggerService>();
                  logger.d('Debug log', tag: 'Demo');
                  logger.i('Info log', tag: 'Demo');
                  logger.w('Warning log', tag: 'Demo');
                  logger.e('Error log', tag: 'Demo');
                  LingSnackbar.success(context, '日志已输出到控制台和文件');
                },
              ),
              const SizedBox(height: AppConstants.spacingXxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// IM Demos
// ═══════════════════════════════════════════════════════════════════════

class ImBubbleDemo extends StatelessWidget {
  const ImBubbleDemo();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          LingMessageBubble(
            message: LingMessage(
              id: '1',
              conversationId: 'demo',
              authorId: 'other',
              type: LingMessageType.text,
              text: '你好！这是一条收到的消息 👋',
              createdAt: now,
              status: LingMessageStatus.delivered,
            ),
            isOutgoing: false,
            currentUserId: 'me',
            showAvatar: true,
            authorName: '张三',
          ),
          const SizedBox(height: 4),
          LingMessageBubble(
            message: LingMessage(
              id: '2',
              conversationId: 'demo',
              authorId: 'me',
              type: LingMessageType.text,
              text: '你好！这是发出的消息 ✅',
              createdAt: now,
              status: LingMessageStatus.read,
              reactions: [
                const LingMessageReaction(emoji: '👍', userIds: ['other']),
                const LingMessageReaction(emoji: '❤️', userIds: ['other', 'user2']),
              ],
            ),
            isOutgoing: true,
            currentUserId: 'me',
          ),
          const SizedBox(height: 4),
          LingMessageBubble(
            message: LingMessage(
              id: '3',
              conversationId: 'demo',
              authorId: 'other',
              type: LingMessageType.audio,
              mediaUrl: 'https://example.com/audio.mp3',
              duration: const Duration(seconds: 15),
              waveform: [0.3, 0.5, 0.8, 0.4, 0.6, 0.9, 0.3, 0.5, 0.7, 0.4],
              createdAt: now,
            ),
            isOutgoing: false,
            currentUserId: 'me',
            showAvatar: true,
            authorName: '张三',
          ),
          const SizedBox(height: 4),
          LingMessageBubble(
            message: LingMessage(
              id: '4',
              conversationId: 'demo',
              authorId: 'system',
              type: LingMessageType.system,
              text: '张三 加入了群聊',
              createdAt: now,
            ),
            isOutgoing: false,
            currentUserId: 'me',
          ),
        ],
      ),
    );
  }
}

class ImEmojiDemo extends StatefulWidget {
  const ImEmojiDemo();

  @override
  State<ImEmojiDemo> createState() => _ImEmojiDemoState();
}

class _ImEmojiDemoState extends State<ImEmojiDemo> {
  bool _showPicker = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LingButton(
          label: _showPicker ? '收起表情' : '展开表情',
          icon: _showPicker ? Icons.keyboard_arrow_up : Icons.emoji_emotions,
          variant: LingButtonVariant.outlined,
          onPressed: () => setState(() => _showPicker = !_showPicker),
        ),
        if (_showPicker)
          LingEmojiPicker(
            onEmojiSelected: (emoji) => LingSnackbar.info(context, emoji),
            onBackspacePressed: () {},
            height: 240,
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// IM Demos — Additional
// ═══════════════════════════════════════════════════════════════════════

void _showMessageTooltipDemo(BuildContext context) {
  LingMessageTooltip.show(
    context,
    canRecall: true,
    canDelete: true,
    actions: [
      LingMessageTooltipAction.reply(onTap: () { Navigator.pop(context); LingSnackbar.info(context, '回复'); }),
      LingMessageTooltipAction.copy(onTap: () { Navigator.pop(context); LingSnackbar.info(context, '复制'); }),
      LingMessageTooltipAction.forward(onTap: () { Navigator.pop(context); LingSnackbar.info(context, '转发'); }),
      LingMessageTooltipAction.multiSelect(onTap: () { Navigator.pop(context); LingSnackbar.info(context, '多选'); }),
      LingMessageTooltipAction.recall(onTap: () { Navigator.pop(context); LingSnackbar.info(context, '撤回'); }),
      LingMessageTooltipAction.delete(onTap: () { Navigator.pop(context); LingSnackbar.info(context, '删除'); }),
    ],
  );
}

class ImVoiceRecorderDemo extends StatefulWidget {
  const ImVoiceRecorderDemo();

  @override
  State<ImVoiceRecorderDemo> createState() => _ImVoiceRecorderDemoState();
}

class _ImVoiceRecorderDemoState extends State<ImVoiceRecorderDemo> {
  LingVoiceRecorderState _state = LingVoiceRecorderState.idle;
  Duration _duration = Duration.zero;

  @override
  Widget build(BuildContext context) {
    return LingVoiceRecorder(
      state: _state,
      duration: _duration,
      onStart: () => setState(() {
        _state = LingVoiceRecorderState.recording;
        _duration = Duration.zero;
      }),
      onComplete: (d) => setState(() {
        _state = LingVoiceRecorderState.idle;
        LingSnackbar.info(context, '语音消息 ${d.inSeconds}s');
      }),
      onCancel: () => setState(() {
        _state = LingVoiceRecorderState.idle;
        _duration = Duration.zero;
      }),
    );
  }
}

class ImAtMentionDemo extends StatelessWidget {
  const ImAtMentionDemo();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LingAtMentionPanel(
        members: const [
          LingChatUser(id: '1', name: '张三'),
          LingChatUser(id: '2', name: '李四'),
          LingChatUser(id: '3', name: '王五'),
          LingChatUser(id: '4', name: '赵六'),
          LingChatUser(id: '5', name: 'Alice'),
        ],
        onMemberSelected: (user) => LingSnackbar.info(context, '@${user.name}'),
      ),
    );
  }
}

class ImChatBgDemo extends StatelessWidget {
  const ImChatBgDemo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 80,
            child: LingChatBackground(
              type: LingChatBackgroundType.color,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Text('纯色背景', style: theme.textTheme.labelSmall),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 80,
            child: LingChatBackground(
              type: LingChatBackgroundType.gradient,
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFE3F2FD)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              child: Center(
                child: Text('渐变背景', style: theme.textTheme.labelSmall),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
