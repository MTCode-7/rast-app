import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/features/auth/services/auth_service.dart';

import '../../../core/constants/app_strings.dart';

class ChatMessage {
  final String role; // 'user' | 'model'
  final String text;
  final DateTime at;

  ChatMessage({required this.role, required this.text, DateTime? at})
    : at = at ?? DateTime.now();
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  bool _compactHeader = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onChatScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final lang =
        context.read<AppSettingsProvider>().language;
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _sending = true;
    });
    _scrollToEnd();

    try {
      final history = <Map<String, String>>[];
      for (var i = 0; i < _messages.length - 1; i++) {
        final m = _messages[i];
        history.add({'role': m.role, 'text': m.text});
      }
      final res = await Api.chat.sendMessage(text, history: history);
      final reply = res['reply']?.toString() ?? '';
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'model', text: reply));
          _sending = false;
        });
        _scrollToEnd();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        final message =
        e.message.toLowerCase().contains('unauthenticated')
            ? AppStrings.t(
          'chatUnavailable',
          lang,
        )
            : e.message;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString().split('\n').first)));
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onChatScroll() {
    if (!_scrollController.hasClients) return;
    final compact = _scrollController.offset > 24;
    if (compact != _compactHeader && mounted) {
      setState(() => _compactHeader = compact);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: settings.textDirection,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RastUi.headerGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              _buildChatHeader(context),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: RastUi.screenSurface(context),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            Responsive.spacing(context, 18),
                            Responsive.spacing(context, 18),
                            Responsive.spacing(context, 18),
                            Responsive.spacing(context, 14),
                          ),
                          children: [
                            _dayLabel(context),
                            for (final msg in _messages) _messageTile(context, msg),
                            if (_sending) _typingTile(context),
                          ],
                        ),
                      ),
                      _composer(context, isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final isArabic = settings.isArabic;

    return SafeArea(
      bottom: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.fromLTRB(
          Responsive.spacing(context, 18),
          Responsive.spacing(context, _compactHeader ? 8 : 14),
          Responsive.spacing(context, 18),
          Responsive.spacing(context, _compactHeader ? 10 : 18),
        ),
        child: Row(
          children: [
            _roundHeaderButton(
              icon: isArabic
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new_rounded,
              iconTextDirection: TextDirection.ltr,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Row(
                children: [
                  if (!_compactHeader) _assistantAvatar(),
                  if (!_compactHeader) const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.t('smartAssistant', lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: Responsive.fontSize(
                              context,
                              _compactHeader ? 15 : 18,
                            ),
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF3ADB76),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                AuthService.isLoggedIn
                                    ? AppStrings.t('online', lang)
                                    : AppStrings.t('guest', lang),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: Responsive.fontSize(context, 12),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            _roundHeaderButton(
              icon: Icons.more_horiz_rounded,
              onTap: _showChatMenu,
            ),
          ],
        ),
      ),
    );
  }

  Widget _assistantAvatar() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(
        Icons.support_agent_rounded,
        color: RastUi.purple,
        size: 24,
      ),
    );
  }

  void _showChatMenu() {
    final settings = context.read<AppSettingsProvider>();
    final lang = settings.language;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: settings.textDirection,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          decoration: BoxDecoration(
            color: RastUi.cardSurface(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: RastUi.softBorder(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.delete_sweep_rounded),
                title: Text(
                  AppStrings.t('clearConversation', lang),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _messages.clear());
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward_rounded),
                title: Text(
                  AppStrings.t('scrollToTop', lang),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    TextDirection? iconTextDirection,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.24),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            textDirection: iconTextDirection,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _dayLabel(BuildContext context) {
    final lang =
        context.watch<AppSettingsProvider>().language;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: RastUi.subtleFill(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: RastUi.softBorder(context),
            ),
          ),
          child: Text(
            AppStrings.t('today', lang),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RastUi.secondaryText(context),
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageTile(BuildContext context, ChatMessage msg) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: isUser
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.spacing(context, 16),
                vertical: Responsive.spacing(context, 13),
              ),
              decoration: BoxDecoration(
                gradient: isUser ? RastUi.headerGradient : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isUser ? 22 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 22),
                ),
                border: isUser
                    ? null
                    : Border.all(color: RastUi.softBorder(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isUser ? 0.08 : 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                msg.text.isEmpty ? '—' : msg.text,
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: isUser ? Colors.white : RastUi.primaryText(context),
                  fontSize: Responsive.fontSize(context, 13),
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUser) ...[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: RastUi.softBorder(context),
                      ),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      size: 14,
                      color: RastUi.blue,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppStrings.t('healthAssistant', lang),
                    style: TextStyle(
                      color: RastUi.secondaryText(context),
                      fontSize: Responsive.fontSize(context, 11),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  Text(
                    AuthService.currentUser?.name ??
                    AppStrings.t('guest', lang),
                    style: TextStyle(
                      color: RastUi.secondaryText(context),
                      fontSize: Responsive.fontSize(context, 11),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: RastUi.softBorder(context),
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: Color(0xFF5B6472),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  _timeLabel(msg.at),
                  style: TextStyle(
                    color: RastUi.secondaryText(context),
                    fontSize: Responsive.fontSize(context, 10.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typingTile(BuildContext context) {
    final lang =
        context.watch<AppSettingsProvider>().language;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(22),
            ),
            border: Border.all(color: RastUi.softBorder(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RastUi.purple,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.t('typingReply', lang),
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 13),
                  color: RastUi.purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer(BuildContext context, bool isDark) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Responsive.spacing(context, 16),
          Responsive.spacing(context, 8),
          Responsive.spacing(context, 16),
          Responsive.spacing(context, 14),
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? RastUi.darkPanel : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: RastUi.softBorder(context),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: RastUi.headerGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: TextField(
                  controller: _controller,
                  textDirection: settings.textDirection,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: AppStrings.t('writeMessage', lang),
                    hintStyle: TextStyle(
                      color: RastUi.secondaryText(context),
                      fontSize: Responsive.fontSize(context, 13),
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(
                    color: RastUi.primaryText(context),
                    fontSize: Responsive.fontSize(context, 13),
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _sending ? null : _sendMessage,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: _sending ? null : RastUi.headerGradient,
                      color: _sending ? const Color(0xFFE9EAF0) : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: _sending ? const Color(0xFF9AA3AF) : Colors.white,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeLabel(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
