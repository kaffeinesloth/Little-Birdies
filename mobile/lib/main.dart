import 'package:flutter/material.dart';

void main() {
  runApp(const SmartHelpdeskApp());
}

class SmartHelpdeskApp extends StatelessWidget {
  const SmartHelpdeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Helpdesk',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: Colors.white,
        ),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: AppColors.slate900,
          displayColor: AppColors.slate900,
        ),
      ),
      home: const SmartHelpdeskResponsiveHome(),
    );
  }
}

class SmartHelpdeskResponsiveHome extends StatelessWidget {
  const SmartHelpdeskResponsiveHome({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 980) {
          return const WebAdminWorkspace();
        }
        return const StaffWorkspaceShell();
      },
    );
  }
}

class WebAdminWorkspace extends StatefulWidget {
  const WebAdminWorkspace({super.key});

  @override
  State<WebAdminWorkspace> createState() => _WebAdminWorkspaceState();
}

class _WebAdminWorkspaceState extends State<WebAdminWorkspace> {
  int _tabIndex = 0;
  TicketSource? _channelFilter;
  TicketStatus? _statusFilter;
  SupportTicket _selectedTicket = demoTickets.first;
  bool _humanTakeover = false;
  bool _uploading = false;
  double _uploadProgress = 0;
  final _replyController = TextEditingController();
  final List<TicketMessage> _liveMessages = [
    const TicketMessage(
      sender: SenderType.bot,
      content:
          'AI Agent connected and escalated this conversation to staff workspace.',
    ),
    const TicketMessage(
      sender: SenderType.customer,
      content: 'San pham bi rach roi, shop xu ly giup toi ngay duoc khong?',
    ),
    const TicketMessage(
      sender: SenderType.bot,
      content:
          'Em da tao ticket uu tien cao va chuyen nhan vien CSKH ho tro minh ngay.',
    ),
  ];

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _sendReply() {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _liveMessages.add(TicketMessage(sender: SenderType.human, content: text));
      _replyController.clear();
    });
  }

  Future<void> _simulateUpload() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    for (final progress in [0.25, 0.5, 0.75, 1.0]) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      setState(() => _uploadProgress = progress);
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _WebHeader(
            selectedIndex: _tabIndex,
            onTabChanged: (index) => setState(() => _tabIndex = index),
            onAutoDemo: () {
              setState(() {
                _tabIndex = 0;
                _humanTakeover = true;
                _replyController.text =
                    'Da chao ban, shop da tiep nhan su co hang bi rach. Ben minh se gui san pham moi bu ngay trong hom nay.';
              });
            },
          ),
          _DemoGuideBanner(isAnalytics: _tabIndex == 1),
          Expanded(
            child: _tabIndex == 0
                ? _WorkspaceDashboard(
                    selectedTicket: _selectedTicket,
                    channelFilter: _channelFilter,
                    statusFilter: _statusFilter,
                    humanTakeover: _humanTakeover,
                    liveMessages: _liveMessages,
                    replyController: _replyController,
                    uploading: _uploading,
                    uploadProgress: _uploadProgress,
                    onSelectTicket: (ticket) =>
                        setState(() => _selectedTicket = ticket),
                    onChannelFilter: (filter) =>
                        setState(() => _channelFilter = filter),
                    onStatusFilter: (filter) =>
                        setState(() => _statusFilter = filter),
                    onToggleTakeover: () =>
                        setState(() => _humanTakeover = !_humanTakeover),
                    onFillDraft: (text) =>
                        setState(() => _replyController.text = text),
                    onSendReply: _sendReply,
                    onUpload: _simulateUpload,
                  )
                : const _AnalyticsDashboard(),
          ),
        ],
      ),
    );
  }
}

class _WebHeader extends StatelessWidget {
  const _WebHeader({
    required this.selectedIndex,
    required this.onTabChanged,
    required this.onAutoDemo,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onAutoDemo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.slate200)),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.indigo],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.headset_mic, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Smart Helpdesk Workspace',
                      style: TextStyle(
                        color: AppColors.slate900,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 10),
                    BadgeChip(
                      label: 'Web Admin & Staff Management',
                      color: AppColors.primary,
                      backgroundColor: AppColors.primarySoft,
                    ),
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  'He thong quan ly hop nhat kenh Web Store & Facebook Messenger + RAG KB',
                  style: TextStyle(
                    color: AppColors.slate500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _SegmentedHeaderTabs(
            selectedIndex: selectedIndex,
            onChanged: onTabChanged,
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onAutoDemo,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Auto Demo'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            onPressed: () {},
            tooltip: 'Reset demo',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _SegmentedHeaderTabs extends StatelessWidget {
  const _SegmentedHeaderTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderTabButton(
            selected: selectedIndex == 0,
            icon: Icons.forum_outlined,
            label: '1. Quan Ly Chat & Ticket',
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 5),
          _HeaderTabButton(
            selected: selectedIndex == 1,
            icon: Icons.trending_up,
            label: '2. Bao Cao Chu Shop',
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _HeaderTabButton extends StatelessWidget {
  const _HeaderTabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.slate600,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.slate700,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoGuideBanner extends StatelessWidget {
  const _DemoGuideBanner({required this.isAnalytics});

  final bool isAnalytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        border: Border(bottom: BorderSide(color: Color(0xFFDBEAFE))),
      ),
      child: Row(
        children: [
          const BadgeChip(
            label: 'CHE DO XEM',
            color: Colors.white,
            backgroundColor: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAnalytics
                  ? 'Dang xem Tab 2: Bao cao thong ke danh cho chu shop.'
                  : 'Dang xem Tab 1: Quan ly Chat & Ticket Live. Nhan vien co the Human Override hoac chon Nhap AI de sua.',
              style: const TextStyle(
                color: AppColors.slate800,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.circle, color: AppColors.success, size: 9),
          const SizedBox(width: 7),
          const Text(
            'Live Broadcast Ready',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceDashboard extends StatelessWidget {
  const _WorkspaceDashboard({
    required this.selectedTicket,
    required this.channelFilter,
    required this.statusFilter,
    required this.humanTakeover,
    required this.liveMessages,
    required this.replyController,
    required this.uploading,
    required this.uploadProgress,
    required this.onSelectTicket,
    required this.onChannelFilter,
    required this.onStatusFilter,
    required this.onToggleTakeover,
    required this.onFillDraft,
    required this.onSendReply,
    required this.onUpload,
  });

  final SupportTicket selectedTicket;
  final TicketSource? channelFilter;
  final TicketStatus? statusFilter;
  final bool humanTakeover;
  final List<TicketMessage> liveMessages;
  final TextEditingController replyController;
  final bool uploading;
  final double uploadProgress;
  final ValueChanged<SupportTicket> onSelectTicket;
  final ValueChanged<TicketSource?> onChannelFilter;
  final ValueChanged<TicketStatus?> onStatusFilter;
  final VoidCallback onToggleTakeover;
  final ValueChanged<String> onFillDraft;
  final VoidCallback onSendReply;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final visibleTickets = demoTickets.where((ticket) {
      final matchesChannel =
          channelFilter == null || ticket.source == channelFilter;
      return matchesChannel;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1850),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _LiveWorkspacePanel(
                      tickets: visibleTickets,
                      selectedTicket: selectedTicket,
                      channelFilter: channelFilter,
                      humanTakeover: humanTakeover,
                      liveMessages: liveMessages,
                      replyController: replyController,
                      onChannelFilter: onChannelFilter,
                      onSelectTicket: onSelectTicket,
                      onToggleTakeover: onToggleTakeover,
                      onFillDraft: onFillDraft,
                      onSendReply: onSendReply,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 5,
                    child: _KnowledgePanel(
                      uploading: uploading,
                      uploadProgress: uploadProgress,
                      onUpload: onUpload,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _TicketManagementHub(
                statusFilter: statusFilter,
                onStatusFilter: onStatusFilter,
                onSelectTicket: onSelectTicket,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.number,
    required this.title,
    required this.color,
    required this.backgroundColor,
  });

  final String number;
  final String title;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.slate900,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveWorkspacePanel extends StatelessWidget {
  const _LiveWorkspacePanel({
    required this.tickets,
    required this.selectedTicket,
    required this.channelFilter,
    required this.humanTakeover,
    required this.liveMessages,
    required this.replyController,
    required this.onChannelFilter,
    required this.onSelectTicket,
    required this.onToggleTakeover,
    required this.onFillDraft,
    required this.onSendReply,
  });

  final List<SupportTicket> tickets;
  final SupportTicket selectedTicket;
  final TicketSource? channelFilter;
  final bool humanTakeover;
  final List<TicketMessage> liveMessages;
  final TextEditingController replyController;
  final ValueChanged<TicketSource?> onChannelFilter;
  final ValueChanged<SupportTicket> onSelectTicket;
  final VoidCallback onToggleTakeover;
  final ValueChanged<String> onFillDraft;
  final VoidCallback onSendReply;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SectionTitle(
          number: '1',
          title: 'Hop Thu Hop Nhat & Chat 2 Chieu (Live Chat Workspace)',
          color: AppColors.primary,
          backgroundColor: AppColors.primarySoft,
        ),
        const SizedBox(height: 14),
        _ChannelFilterBar(selected: channelFilter, onChanged: onChannelFilter),
        const SizedBox(height: 14),
        Container(
          height: 610,
          decoration: cardDecoration().copyWith(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 320,
                child: _ConversationList(
                  tickets: tickets,
                  selectedTicket: selectedTicket,
                  onSelectTicket: onSelectTicket,
                ),
              ),
              const VerticalDivider(width: 1, color: AppColors.slate200),
              Expanded(
                child: _ActiveChatRoom(
                  ticket: selectedTicket,
                  humanTakeover: humanTakeover,
                  messages: liveMessages,
                  replyController: replyController,
                  onToggleTakeover: onToggleTakeover,
                  onFillDraft: onFillDraft,
                  onSendReply: onSendReply,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelFilterBar extends StatelessWidget {
  const _ChannelFilterBar({required this.selected, required this.onChanged});

  final TicketSource? selected;
  final ValueChanged<TicketSource?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          _FilterButton(
            selected: selected == null,
            icon: Icons.layers_outlined,
            label: 'Tat Ca Kenh (4)',
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 7),
          _FilterButton(
            selected: selected == TicketSource.web,
            icon: Icons.language,
            label: 'Website Live Chat (2)',
            onTap: () => onChanged(TicketSource.web),
          ),
          const SizedBox(width: 7),
          _FilterButton(
            selected: selected == TicketSource.facebook,
            icon: Icons.facebook,
            label: 'Facebook Messenger (1)',
            onTap: () => onChanged(TicketSource.facebook),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.slate100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : AppColors.slate600,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.slate600,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.tickets,
    required this.selectedTicket,
    required this.onSelectTicket,
  });

  final List<SupportTicket> tickets;
  final SupportTicket selectedTicket;
  final ValueChanged<SupportTicket> onSelectTicket;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.slate50,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 7),
            child: Text(
              'DANH SACH HOI THOAI CHAT',
              style: TextStyle(
                color: AppColors.slate500,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                return _ConversationCard(
                  ticket: ticket,
                  selected: ticket.number == selectedTicket.number,
                  onTap: () => onSelectTicket(ticket),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 9),
              itemCount: tickets.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.ticket,
    required this.selected,
    required this.onTap,
  });

  final SupportTicket ticket;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.slate200,
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SourceBadge(source: ticket.source),
                const Spacer(),
                StatusBadge(status: ticket.status),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              'Ticket #${ticket.number}: ${ticket.customerName}',
              style: const TextStyle(
                color: AppColors.slate900,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              ticket.summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.slate600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Text(
                  'Intent: ${ticket.intent.label}',
                  style: const TextStyle(
                    color: AppColors.slate400,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  ticket.createdAgo,
                  style: const TextStyle(
                    color: AppColors.slate400,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveChatRoom extends StatelessWidget {
  const _ActiveChatRoom({
    required this.ticket,
    required this.humanTakeover,
    required this.messages,
    required this.replyController,
    required this.onToggleTakeover,
    required this.onFillDraft,
    required this.onSendReply,
  });

  final SupportTicket ticket;
  final bool humanTakeover;
  final List<TicketMessage> messages;
  final TextEditingController replyController;
  final VoidCallback onToggleTakeover;
  final ValueChanged<String> onFillDraft;
  final VoidCallback onSendReply;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.slate50,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Ticket #${ticket.number}: ${ticket.customerName}',
                          style: const TextStyle(
                            color: AppColors.slate900,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SourceBadge(source: ticket.source),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      humanTakeover
                          ? 'Trang thai: HUMAN TAKEOVER ACTIVE - AI tu dong tam dung'
                          : 'Trang thai: URGENT PENDING - Can nhan vien tiep nhan va phan hoi',
                      style: TextStyle(
                        color: humanTakeover
                            ? AppColors.success
                            : AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onToggleTakeover,
                icon: Icon(
                  humanTakeover ? Icons.verified_user : Icons.pan_tool_alt,
                ),
                label: Text(
                  humanTakeover ? 'Nhan Vien Dang Truc' : 'Human Takeover',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: humanTakeover
                      ? AppColors.success
                      : AppColors.warning,
                  side: BorderSide(
                    color: humanTakeover
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Hoan Thanh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.slate200),
        Expanded(
          child: Container(
            color: const Color(0xFFFBFDFF),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) =>
                  ChatBubble(message: messages[index]),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: messages.length,
            ),
          ),
        ),
        _WebReplyComposer(
          controller: replyController,
          onFillDraft: onFillDraft,
          onSend: onSendReply,
        ),
      ],
    );
  }
}

class _WebReplyComposer extends StatelessWidget {
  const _WebReplyComposer({
    required this.controller,
    required this.onFillDraft,
    required this.onSend,
  });

  final TextEditingController controller;
  final ValueChanged<String> onFillDraft;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate200)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'AI Suggested Drafts (Click de chen & chinh sua):',
                      style: TextStyle(
                        color: AppColors.slate900,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Human-in-the-Loop Approved',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _DraftButton(
                      label: 'Nhap 1: Gui san pham moi',
                      onTap: () => onFillDraft(
                        'Da chao ban, shop da tiep nhan su co hang bi rach. Shop xin loi ban va se gui san pham moi bu ngay trong hom nay.',
                      ),
                    ),
                    _DraftButton(
                      label: 'Nhap 2: Voucher 10%',
                      onTap: () => onFillDraft(
                        'Da chao ban, shop xin gui ma giam gia 10% de xin loi vi su co van chuyen cham tre.',
                      ),
                    ),
                    _DraftButton(
                      label: 'Nhap 3: Kiem tra buu cuc',
                      onTap: () => onFillDraft(
                        'Da chao anh chi, em la nhan vien CSKH dang kiem tra lai don #SP-992 voi buu cuc.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText:
                        'Nhap hoac chinh sua cau tra loi cua nhan vien...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 13,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send, size: 17),
                label: const Text('Gui'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(86, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DraftButton extends StatelessWidget {
  const _DraftButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.auto_fix_high, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF93C5FD)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _KnowledgePanel extends StatelessWidget {
  const _KnowledgePanel({
    required this.uploading,
    required this.uploadProgress,
    required this.onUpload,
  });

  final bool uploading;
  final double uploadProgress;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SectionTitle(
          number: '2',
          title: 'AI Knowledge Base & Bao Cao Ops',
          color: AppColors.indigo,
          backgroundColor: AppColors.indigoSoft,
        ),
        const SizedBox(height: 14),
        Container(
          height: 610,
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration().copyWith(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Ty le AI tu dong xu ly',
                      value: '89.2%',
                      note: 'Tiet kiem 80% thoi gian nhan vien',
                      valueColor: AppColors.success,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      label: 'Thoi gian phan hoi AI',
                      value: '1.1s',
                      note: 'Phan hoi 24/7 tuc thi',
                      valueColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.psychology_alt,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'AI Knowledge Base (RAG Pipeline)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        BadgeChip(
                          label: 'ChromaDB Active',
                          color: AppColors.primary,
                          backgroundColor: AppColors.primarySoft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tai file tai lieu shop de AI tu hoc va tra loi chinh xac theo van ban.',
                      style: TextStyle(
                        color: AppColors.slate500,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: onUpload,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.slate200,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              color: AppColors.primary,
                              size: 32,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Bam de tai tai lieu moi (PDF, DOCX)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Tu dong chunking & vector embedding',
                              style: TextStyle(
                                color: AppColors.slate400,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (uploading) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Chinh_Sach_Doi_Tra_Moi.pdf',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${(uploadProgress * 100).round()}%',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(value: uploadProgress),
                    ],
                    const SizedBox(height: 12),
                    _DocumentTile(name: 'Bang_Gia_Va_CS_Freeship.pdf'),
                    const SizedBox(height: 8),
                    _DocumentTile(name: 'Huong_Dan_Bao_Hanh_2026.pdf'),
                    if (!uploading && uploadProgress == 1.0) ...[
                      const SizedBox(height: 8),
                      _DocumentTile(
                        name: 'Chinh_Sach_Doi_Tra_Moi.pdf',
                        isNew: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.note,
    required this.valueColor,
  });

  final String label;
  final String value;
  final String note;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.slate500,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            note,
            style: const TextStyle(
              color: AppColors.slate400,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.name, this.isNew = false});

  final String name;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNew ? AppColors.primary : AppColors.slate200,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.picture_as_pdf_outlined,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.slate800,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          BadgeChip(
            label: isNew ? 'NEW INDEXED' : 'INDEXED',
            color: AppColors.success,
            backgroundColor: AppColors.successSoft,
          ),
        ],
      ),
    );
  }
}

class _TicketManagementHub extends StatelessWidget {
  const _TicketManagementHub({
    required this.statusFilter,
    required this.onStatusFilter,
    required this.onSelectTicket,
  });

  final TicketStatus? statusFilter;
  final ValueChanged<TicketStatus?> onStatusFilter;
  final ValueChanged<SupportTicket> onSelectTicket;

  @override
  Widget build(BuildContext context) {
    final rows = demoTickets.where((ticket) {
      if (statusFilter == null) return true;
      if (statusFilter == TicketStatus.open) {
        return ticket.status == TicketStatus.open ||
            ticket.status == TicketStatus.pending;
      }
      return ticket.status == statusFilter;
    }).toList();

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionTitle(
                number: '3',
                title:
                    'Bang Quan Ly Tat Ca Ticket & Trang Thai (Ticket Management Hub)',
                color: AppColors.success,
                backgroundColor: AppColors.successSoft,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Row(
                children: [
                  _SmallStatusFilter(
                    label: 'Tat Ca (4)',
                    selected: statusFilter == null,
                    onTap: () => onStatusFilter(null),
                  ),
                  _SmallStatusFilter(
                    label: 'Cho Xu Ly (2)',
                    selected: statusFilter == TicketStatus.open,
                    onTap: () => onStatusFilter(TicketStatus.open),
                  ),
                  _SmallStatusFilter(
                    label: 'Dang Xu Ly (1)',
                    selected: statusFilter == TicketStatus.inProgress,
                    onTap: () => onStatusFilter(TicketStatus.inProgress),
                  ),
                  _SmallStatusFilter(
                    label: 'Hoan Thanh (1)',
                    selected: statusFilter == TicketStatus.resolved,
                    onTap: () => onStatusFilter(TicketStatus.resolved),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration().copyWith(
            borderRadius: BorderRadius.circular(16),
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.slate100),
            border: TableBorder(
              horizontalInside: const BorderSide(color: AppColors.slate100),
              borderRadius: BorderRadius.circular(12),
            ),
            columns: const [
              DataColumn(label: Text('Ma Ticket')),
              DataColumn(label: Text('Nguon Kenh')),
              DataColumn(label: Text('Khach Hang / Don Hang')),
              DataColumn(label: Text('Noi Dung / Intent')),
              DataColumn(label: Text('Muc Uu Tien')),
              DataColumn(label: Text('Trang Thai')),
              DataColumn(label: Text('Thao Tac')),
            ],
            rows: rows.map((ticket) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      '#${ticket.number}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  DataCell(SourceBadge(source: ticket.source)),
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          ticket.number == 102
                              ? 'Don hang #SP-992'
                              : ticket.source.label,
                          style: const TextStyle(
                            color: AppColors.slate400,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 230,
                      child: Text(
                        ticket.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(IntentBadge(intent: ticket.intent)),
                  DataCell(StatusBadge(status: ticket.status)),
                  DataCell(
                    OutlinedButton.icon(
                      onPressed: () => onSelectTicket(ticket),
                      icon: const Icon(Icons.forum_outlined, size: 16),
                      label: const Text('Chat Live'),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SmallStatusFilter extends StatelessWidget {
  const _SmallStatusFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.slate100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.slate600,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsDashboard extends StatelessWidget {
  const _AnalyticsDashboard();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1850),
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(
                    child: _OwnerMetricCard(
                      icon: Icons.savings_outlined,
                      label: 'Tien Luong Tiet Kiem',
                      value: '8.500.000d/thang',
                      note: 'Tiet kiem 120h truc ca dem cua NV',
                      color: AppColors.success,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: _OwnerMetricCard(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Doanh So AI Ho Tro Chot',
                      value: '15.800.000d',
                      note: '45 don chot truc tiep qua Chat AI',
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: _OwnerMetricCard(
                      icon: Icons.bolt_outlined,
                      label: 'Thoi Gian Tra Loi TB',
                      value: '1.1 giay',
                      note: 'Tu dong 24/7 khong nghi ca',
                      color: AppColors.indigo,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: _OwnerMetricCard(
                      icon: Icons.star_border,
                      label: 'Danh Gia Hai Long',
                      value: '4.8 / 5.0',
                      note: '154 khach hang da danh gia',
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AnalyticsPanel(
                      number: '2',
                      title: 'Canh Bao San Pham Bi Bat Loi & Khieu Nai',
                      badge: 'QUALITY RISK',
                      color: AppColors.danger,
                      child: Column(
                        children: const [
                          _ProgressInsight(
                            title: 'Ao Polo The Thao Pro-Fit 2026',
                            value: '14 luot bao rach',
                            progress: 0.85,
                            color: AppColors.danger,
                          ),
                          SizedBox(height: 14),
                          _ProgressInsight(
                            title: 'Quan Short The Thao Co Gian',
                            value: '8 luot bao sai size',
                            progress: 0.5,
                            color: AppColors.warning,
                          ),
                          SizedBox(height: 16),
                          _AlertBox(
                            icon: Icons.warning_amber,
                            title: 'Khuyen nghi hanh dong khan cap',
                            body:
                                'Ma san pham Ao Polo Pro-Fit co ty le bao rach tang dot bien trong 48h qua.',
                            color: AppColors.danger,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  const Expanded(
                    child: _AnalyticsPanel(
                      number: '3',
                      title: 'Bao Cao Nang Suat & Thai Do Nhan Vien CSKH',
                      badge: 'STAFF METRICS',
                      color: AppColors.primary,
                      child: _StaffMetricsTable(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(child: _PeakHoursPanel()),
                  SizedBox(width: 24),
                  Expanded(child: _KnowledgeGapPanel()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerMetricCard extends StatelessWidget {
  const _OwnerMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(borderColor: AppColors.slate200).copyWith(
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.slate500,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({
    required this.number,
    required this.title,
    required this.badge,
    required this.color,
    required this.child,
  });

  final String number;
  final String title;
  final String badge;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration().copyWith(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              BadgeChip(
                label: badge,
                color: color,
                backgroundColor: color.withValues(alpha: 0.1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ProgressInsight extends StatelessWidget {
  const _ProgressInsight({
    required this.title,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String title;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.slate800,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          borderRadius: BorderRadius.circular(8),
          color: color,
          backgroundColor: AppColors.slate100,
        ),
      ],
    );
  }
}

class _AlertBox extends StatelessWidget {
  const _AlertBox({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(text: body),
                ],
              ),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffMetricsTable extends StatelessWidget {
  const _StaffMetricsTable();

  @override
  Widget build(BuildContext context) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(AppColors.slate100),
      columns: const [
        DataColumn(label: Text('Nhan Vien CSKH')),
        DataColumn(label: Text('Ticket')),
        DataColumn(label: Text('FRT')),
        DataColumn(label: Text('CSAT')),
        DataColumn(label: Text('Trang Thai')),
      ],
      rows: const [
        DataRow(
          cells: [
            DataCell(Text('Tran Tuan Hai')),
            DataCell(Text('42')),
            DataCell(Text('1.2 phut')),
            DataCell(Text('4.9 / 5.0')),
            DataCell(StatusBadge(status: TicketStatus.inProgress)),
          ],
        ),
        DataRow(
          cells: [
            DataCell(Text('Huynh Bao')),
            DataCell(Text('38')),
            DataCell(Text('2.5 phut')),
            DataCell(Text('4.7 / 5.0')),
            DataCell(StatusBadge(status: TicketStatus.inProgress)),
          ],
        ),
      ],
    );
  }
}

class _PeakHoursPanel extends StatelessWidget {
  const _PeakHoursPanel();

  @override
  Widget build(BuildContext context) {
    return _AnalyticsPanel(
      number: '4',
      title: 'Khung Gio Cao Diem & Phan Bo Kenh Chat',
      badge: 'PEAK TRAFFIC',
      color: AppColors.indigo,
      child: Column(
        children: const [
          Row(
            children: [
              Expanded(
                child: _HourTile(
                  label: '00:00 - 08:00',
                  value: '15%',
                  note: 'AI ganh 100%',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _HourTile(
                  label: '08:00 - 13:00',
                  value: '22%',
                  note: 'Ca sang',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _HourTile(
                  label: '13:00 - 18:00',
                  value: '23%',
                  note: 'Ca chieu',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _HourTile(
                  label: '18:00 - 23:30',
                  value: '40%',
                  note: 'Gio vang',
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          _ProgressInsight(
            title: 'Kenh nhan tin chinh: Web Chat 65% | FB Messenger 35%',
            value: '65 / 35',
            progress: 0.65,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _HourTile extends StatelessWidget {
  const _HourTile({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.slate500,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.indigo,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            note,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.slate500,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeGapPanel extends StatelessWidget {
  const _KnowledgeGapPanel();

  @override
  Widget build(BuildContext context) {
    return _AnalyticsPanel(
      number: '5',
      title: 'Nhu Cau Khach Hang & Canh Bao Thieu Kien Thuc AI',
      badge: 'AI KNOWLEDGE GAP',
      color: AppColors.warning,
      child: Column(
        children: const [
          _InquiryRow(
            label: 'Hoi Phi Van Chuyen & Doi Tra',
            value: '38% (88 luot)',
          ),
          SizedBox(height: 8),
          _InquiryRow(
            label: 'Hoi Tu Van Chon Kich Thuoc Size',
            value: '28% (64 luot)',
          ),
          SizedBox(height: 8),
          _InquiryRow(
            label: 'Hoi Thoi Gian Bao Hanh San Pham',
            value: '18% (42 luot)',
          ),
          SizedBox(height: 16),
          _AlertBox(
            icon: Icons.lightbulb_outline,
            title: 'AI RAG Knowledge Gap Alert',
            body:
                'Co 22 luot khach hoi ve chinh sach mua si va dai ly ma AI chua co du lieu.',
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _InquiryRow extends StatelessWidget {
  const _InquiryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.slate800,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          BadgeChip(
            label: value,
            color: AppColors.primary,
            backgroundColor: AppColors.primarySoft,
          ),
        ],
      ),
    );
  }
}

class StaffWorkspaceShell extends StatefulWidget {
  const StaffWorkspaceShell({super.key});

  @override
  State<StaffWorkspaceShell> createState() => _StaffWorkspaceShellState();
}

class _StaffWorkspaceShellState extends State<StaffWorkspaceShell> {
  int _selectedIndex = 0;
  bool _isOnline = true;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TicketListScreen(
        isOnline: _isOnline,
        onOnlineChanged: (value) => setState(() => _isOnline = value),
      ),
      const AlertsScreen(),
      const DashboardScreen(),
      ProfileScreen(
        isOnline: _isOnline,
        onOnlineChanged: (value) => setState(() => _isOnline = value),
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Canh bao',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Bao cao',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Ca truc',
          ),
        ],
      ),
    );
  }
}

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({
    super.key,
    required this.isOnline,
    required this.onOnlineChanged,
  });

  final bool isOnline;
  final ValueChanged<bool> onOnlineChanged;

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  TicketFilter _filter = TicketFilter.all;

  @override
  Widget build(BuildContext context) {
    final tickets = demoTickets.where((ticket) {
      return switch (_filter) {
        TicketFilter.all => true,
        TicketFilter.urgent => ticket.isUrgent,
        TicketFilter.open => ticket.status == TicketStatus.open,
        TicketFilter.inProgress => ticket.status == TicketStatus.inProgress,
        TicketFilter.resolved => ticket.status == TicketStatus.resolved,
      };
    }).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkspaceHeader(
                  isOnline: widget.isOnline,
                  onOnlineChanged: widget.onOnlineChanged,
                ),
                const SizedBox(height: 18),
                const UrgentBanner(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      'Hop thu CSKH',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    const BadgeChip(
                      label: 'Realtime',
                      color: AppColors.success,
                      backgroundColor: AppColors.successSoft,
                      icon: Icons.circle,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const _MobileOpsSummaryStrip(),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: TicketFilter.values.map((filter) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: _filter == filter,
                          label: Text(filter.label),
                          onSelected: (_) => setState(() => _filter = filter),
                          showCheckmark: false,
                          selectedColor: AppColors.primarySoft,
                          side: BorderSide(
                            color: _filter == filter
                                ? AppColors.primary
                                : AppColors.slate200,
                          ),
                          labelStyle: TextStyle(
                            color: _filter == filter
                                ? AppColors.primary
                                : AppColors.slate600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverList.separated(
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return TicketCard(
                ticket: ticket,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TicketDetailScreen(ticket: ticket),
                    ),
                  );
                },
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemCount: tickets.length,
          ),
        ),
      ],
    );
  }
}

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticket});

  final SupportTicket ticket;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  late TicketStatus _status;
  late List<TicketMessage> _messages;
  bool _humanTakeover = false;

  @override
  void initState() {
    super.initState();
    _status = widget.ticket.status;
    _messages = [...widget.ticket.messages];
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ticket.customerName),
            Text(
              '#${ticket.number} - ${ticket.source.label} - Staff mobile',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StatusBadge(status: _status),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SourceBadge(source: ticket.source),
                    const SizedBox(width: 8),
                    IntentBadge(intent: ticket.intent),
                    const Spacer(),
                    Text(
                      ticket.createdAgo,
                      style: const TextStyle(
                        color: AppColors.slate500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  ticket.summary,
                  style: const TextStyle(
                    color: AppColors.slate700,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _humanTakeover
                        ? AppColors.successSoft
                        : AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _humanTakeover
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _humanTakeover
                            ? Icons.verified_user_outlined
                            : Icons.pan_tool_alt_outlined,
                        color: _humanTakeover
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _humanTakeover
                              ? 'Human Takeover dang bat - AI tu dong tam dung.'
                              : 'Ticket dang cho nhan vien tiep nhan, AI chi de xuat nhap.',
                          style: TextStyle(
                            color: _humanTakeover
                                ? AppColors.success
                                : AppColors.warning,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _status = TicketStatus.inProgress;
                            _humanTakeover = true;
                          });
                        },
                        icon: const Icon(Icons.pan_tool_alt_outlined, size: 18),
                        label: const Text('Nhan ca'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() => _status = TicketStatus.resolved);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Hoan thanh'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              itemBuilder: (context, index) {
                return ChatBubble(message: _messages[index]);
              },
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: _messages.length,
            ),
          ),
          ReplyComposer(
            controller: _replyController,
            onDraftSelected: (text) => setState(() {
              _replyController.text = text;
              _humanTakeover = true;
              _status = TicketStatus.inProgress;
            }),
            onSend: () {
              final text = _replyController.text.trim();
              if (text.isEmpty) return;
              setState(() {
                _messages.add(
                  TicketMessage(sender: SenderType.human, content: text),
                );
                _replyController.clear();
                _status = TicketStatus.inProgress;
                _humanTakeover = true;
              });
            },
          ),
        ],
      ),
    );
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final urgentTickets = demoTickets
        .where((ticket) => ticket.isUrgent)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const ScreenTitle(
          title: 'Canh bao khan cap',
          subtitle: 'Ticket can nhan vien CSKH tiep nhan tren mobile.',
        ),
        const SizedBox(height: 14),
        ...urgentTickets.map(
          (ticket) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AlertTile(ticket: ticket),
          ),
        ),
        const SizedBox(height: 6),
        const SectionPanel(
          icon: Icons.notifications_active_outlined,
          title: 'Trang thai push notification',
          body:
              'FCM token san sang - Escalation khi khieu nai dang bat - Realtime sync dang hoat dong.',
        ),
        const SizedBox(height: 12),
        const SectionPanel(
          icon: Icons.support_agent_outlined,
          title: 'Quy tac xu ly cho nhan vien',
          body:
              'Khi ticket Complaint hoac Angry xuat hien, nhan vien bam Nhan ca de kich hoat Human Takeover, sua nhap AI neu can, sau do phan hoi truc tiep cho khach.',
        ),
      ],
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const ScreenTitle(
          title: 'Bao cao ca truc',
          subtitle: 'Tom tat nhanh cho nhan vien va super admin tren mobile.',
        ),
        const SizedBox(height: 14),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatCard(label: 'Ticket hom nay', value: '34', icon: Icons.today),
            StatCard(label: 'Dang mo', value: '8', icon: Icons.inbox),
            StatCard(label: 'Da xong', value: '26', icon: Icons.task_alt),
            StatCard(label: 'AI xu ly', value: '89%', icon: Icons.smart_toy),
          ],
        ),
        const SizedBox(height: 18),
        SectionPanel(
          icon: Icons.trending_up,
          title: 'Hieu suat phan hoi',
          body:
              'Thoi gian phan hoi dau tien trung binh 42 giay. Ticket khieu nai khan cap duoc handoff cho nhan vien duoi 1 phut.',
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: const LinearProgressIndicator(
                minHeight: 10,
                value: 0.76,
                backgroundColor: AppColors.slate100,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SectionPanel(
          icon: Icons.psychology_alt_outlined,
          title: 'AI Knowledge Gap',
          body:
              'Co 22 cau hoi ve chinh sach mua si va dai ly ma AI chua co tai lieu. Chu shop can bo sung PDF vao RAG Knowledge Base.',
        ),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.isOnline,
    required this.onOnlineChanged,
  });

  final bool isOnline;
  final ValueChanged<bool> onOnlineChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const ScreenTitle(
          title: 'Ca truc nhan vien',
          subtitle: 'Tai khoan CSKH, trang thai truc va quyen xu ly ticket.',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary,
                child: Text(
                  'NA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hai CSKH',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'agent - Staff mobile app - Web/Facebook inbox',
                      style: TextStyle(
                        color: AppColors.slate500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: isOnline, onChanged: onOnlineChanged),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SectionPanel(
          icon: Icons.key_outlined,
          title: 'Quyen xu ly',
          body:
              'Duoc xem ticket duoc gan hoac ticket dang mo, kich hoat Human Takeover, phan hoi khach va dong hoi thoai da xu ly.',
        ),
        const SizedBox(height: 12),
        const SectionPanel(
          icon: Icons.phone_android,
          title: 'Trang thai thiet bi',
          body:
              'FCM push token da dang ky - Last seen vua xong - Da subscribe realtime channel smart_helpdesk_omnichannel.',
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.logout),
          label: const Text('Dang xuat'),
        ),
      ],
    );
  }
}

class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.isOnline,
    required this.onOnlineChanged,
  });

  final bool isOnline;
  final ValueChanged<bool> onOnlineChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.headset_mic, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Helpdesk Staff',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                isOnline
                    ? 'Online - dang nhan ticket khan cap'
                    : 'Offline - tam dung push notification',
                style: TextStyle(
                  color: isOnline ? AppColors.success : AppColors.slate500,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(value: isOnline, onChanged: onOnlineChanged),
      ],
    );
  }
}

class UrgentBanner extends StatelessWidget {
  const UrgentBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.priority_high, color: AppColors.danger),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '2 khieu nai khan cap dang cho Human Takeover tu nhan vien.',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileOpsSummaryStrip extends StatelessWidget {
  const _MobileOpsSummaryStrip();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _MiniMetric(
            label: 'AI tu dong',
            value: '89%',
            icon: Icons.smart_toy_outlined,
            color: AppColors.success,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _MiniMetric(
            label: 'FRT TB',
            value: '42s',
            icon: Icons.bolt_outlined,
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _MiniMetric(
            label: 'Khan cap',
            value: '2',
            icon: Icons.priority_high,
            color: AppColors.danger,
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.slate500,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: cardDecoration(
          borderColor: ticket.isUrgent
              ? AppColors.dangerBorder
              : AppColors.slate200,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SourceBadge(source: ticket.source),
                const SizedBox(width: 8),
                IntentBadge(intent: ticket.intent),
                const Spacer(),
                StatusBadge(status: ticket.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '#${ticket.number} · ${ticket.customerName}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              ticket.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.slate600,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 15, color: AppColors.slate400),
                const SizedBox(width: 4),
                Text(
                  ticket.createdAgo,
                  style: const TextStyle(
                    color: AppColors.slate500,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (ticket.isUrgent)
                  const BadgeChip(
                    label: 'Can tiep nhan',
                    color: AppColors.danger,
                    backgroundColor: AppColors.dangerSoft,
                  )
                else
                  const Icon(Icons.chevron_right, color: AppColors.slate400),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final isHuman = message.sender == SenderType.human;
    final isBot = message.sender == SenderType.bot;

    return Row(
      mainAxisAlignment: isHuman
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isHuman) MessageAvatar(sender: message.sender),
        if (!isHuman) const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHuman
                  ? AppColors.primary
                  : isBot
                  ? AppColors.primarySoft
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHuman ? AppColors.primary : AppColors.slate200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.sender.label,
                  style: TextStyle(
                    color: isHuman ? Colors.white70 : AppColors.slate500,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.content,
                  style: TextStyle(
                    color: isHuman ? Colors.white : AppColors.slate800,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isHuman) const SizedBox(width: 8),
        if (isHuman) MessageAvatar(sender: message.sender),
      ],
    );
  }
}

class ReplyComposer extends StatelessWidget {
  const ReplyComposer({
    super.key,
    required this.controller,
    this.onDraftSelected,
    this.onSend,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onDraftSelected;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Nhap AI de nhan vien sua truoc khi gui',
                        style: TextStyle(
                          color: AppColors.slate900,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _CompactDraftChip(
                      label: 'Gui hang moi',
                      onTap: () => onDraftSelected?.call(
                        'Da chao ban, shop xin loi vi san pham bi rach. Ben minh se gui san pham moi bu ngay trong hom nay.',
                      ),
                    ),
                    _CompactDraftChip(
                      label: 'Voucher 10%',
                      onTap: () => onDraftSelected?.call(
                        'Shop xin loi vi trai nghiem nay va xin gui ma giam gia 10% cho don tiep theo.',
                      ),
                    ),
                    _CompactDraftChip(
                      label: 'Kiem tra don',
                      onTap: () => onDraftSelected?.call(
                        'Em da tiep nhan va dang kiem tra don hang voi bo phan kho/buu cuc.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => onSend?.call(),
                  decoration: InputDecoration(
                    hintText: 'Phan hoi truc tiep toi khach...',
                    filled: true,
                    fillColor: AppColors.slate50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onSend ?? () => controller.clear(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactDraftChip extends StatelessWidget {
  const _CompactDraftChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.auto_fix_high, size: 15),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF93C5FD)),
      labelStyle: const TextStyle(
        color: AppColors.primary,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final TicketSource source;

  @override
  Widget build(BuildContext context) {
    return BadgeChip(
      icon: source.icon,
      label: source.label,
      color: source.color,
      backgroundColor: source.softColor,
    );
  }
}

class IntentBadge extends StatelessWidget {
  const IntentBadge({super.key, required this.intent});

  final TicketIntent intent;

  @override
  Widget build(BuildContext context) {
    return BadgeChip(
      icon: intent.icon,
      label: intent.label,
      color: intent.color,
      backgroundColor: intent.softColor,
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    return BadgeChip(
      label: status.label,
      color: status.color,
      backgroundColor: status.softColor,
    );
  }
}

class BadgeChip extends StatelessWidget {
  const BadgeChip({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.icon,
  });

  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class MessageAvatar extends StatelessWidget {
  const MessageAvatar({super.key, required this.sender});

  final SenderType sender;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: sender.color,
      child: Icon(sender.icon, size: 15, color: Colors.white),
    );
  }
}

class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(borderColor: AppColors.dangerBorder),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning_amber, color: AppColors.danger),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${ticket.number} · ${ticket.customerName}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  ticket.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slate600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.slate400),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.slate500,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.slate500,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.child,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.slate600,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

BoxDecoration cardDecoration({Color borderColor = AppColors.slate200}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: borderColor),
    boxShadow: const [
      BoxShadow(color: Color(0x0A0F172A), offset: Offset(0, 4), blurRadius: 14),
    ],
  );
}

enum TicketFilter {
  all('Tat ca'),
  urgent('Khan cap'),
  open('Cho xu ly'),
  inProgress('Dang xu ly'),
  resolved('Hoan thanh');

  const TicketFilter(this.label);
  final String label;
}

enum TicketSource {
  web('Web Store', Icons.language, AppColors.primary, AppColors.primarySoft),
  facebook(
    'FB Messenger',
    Icons.facebook,
    AppColors.indigo,
    AppColors.indigoSoft,
  ),
  email('Email', Icons.mail_outline, AppColors.success, AppColors.successSoft);

  const TicketSource(this.label, this.icon, this.color, this.softColor);
  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
}

enum TicketStatus {
  open('Cho xu ly', AppColors.danger, AppColors.dangerSoft),
  inProgress('Dang xu ly', AppColors.warning, AppColors.warningSoft),
  pending('Pending', AppColors.warning, AppColors.warningSoft),
  resolved('Hoan thanh', AppColors.success, AppColors.successSoft);

  const TicketStatus(this.label, this.color, this.softColor);
  final String label;
  final Color color;
  final Color softColor;
}

enum TicketIntent {
  question('FAQ', Icons.help_outline, AppColors.primary, AppColors.primarySoft),
  complaint(
    'Khieu nai',
    Icons.report_problem_outlined,
    AppColors.danger,
    AppColors.dangerSoft,
  ),
  spam('Spam', Icons.block, AppColors.slate500, AppColors.slate100);

  const TicketIntent(this.label, this.icon, this.color, this.softColor);
  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
}

enum SenderType {
  customer('Khach hang', Icons.person, AppColors.slate500),
  bot('AI Assistant', Icons.smart_toy, AppColors.primary),
  human('Nhan vien CSKH', Icons.support_agent, AppColors.success);

  const SenderType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class SupportTicket {
  const SupportTicket({
    required this.number,
    required this.customerName,
    required this.source,
    required this.status,
    required this.intent,
    required this.summary,
    required this.createdAgo,
    required this.messages,
  });

  final int number;
  final String customerName;
  final TicketSource source;
  final TicketStatus status;
  final TicketIntent intent;
  final String summary;
  final String createdAgo;
  final List<TicketMessage> messages;

  bool get isUrgent =>
      intent == TicketIntent.complaint && status != TicketStatus.resolved;
}

class TicketMessage {
  const TicketMessage({required this.sender, required this.content});

  final SenderType sender;
  final String content;
}

class AppColors {
  static const background = Color(0xFFF8FAFC);
  static const primary = Color(0xFF2563EB);
  static const primarySoft = Color(0xFFEFF6FF);
  static const indigo = Color(0xFF4F46E5);
  static const indigoSoft = Color(0xFFEEF2FF);
  static const success = Color(0xFF059669);
  static const successSoft = Color(0xFFECFDF5);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFFFBEB);
  static const danger = Color(0xFFE11D48);
  static const dangerSoft = Color(0xFFFFF1F2);
  static const dangerBorder = Color(0xFFFECDD3);
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
}

const demoTickets = [
  SupportTicket(
    number: 102,
    customerName: 'Khach Hang Web',
    source: TicketSource.web,
    status: TicketStatus.open,
    intent: TicketIntent.complaint,
    summary:
        'San pham bi rach, khach yeu cau shop xu ly ngay va can nhan vien tiep nhan.',
    createdAgo: 'Vua xong',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content: 'San pham bi rach roi, shop lam an kieu gi the?! Xu ly ngay!',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content:
            'Da shop rat tiec vi su co. AI da tao Ticket uu tien cao #102 va chuyen truc tiep cho nhan vien CSKH.',
      ),
      TicketMessage(
        sender: SenderType.customer,
        content: 'Toi can doi hang hoac hoan tien trong hom nay.',
      ),
    ],
  ),
  SupportTicket(
    number: 103,
    customerName: 'Nguyen Van A',
    source: TicketSource.facebook,
    status: TicketStatus.inProgress,
    intent: TicketIntent.question,
    summary: 'Khach hoi thoi gian bao hanh va chinh sach doi tra.',
    createdAgo: '15 phut truoc',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content: 'Ao Polo nay bao hanh bao lau vay shop?',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content: 'Theo tai lieu bao hanh 2026, san pham duoc bao hanh 6 thang.',
      ),
      TicketMessage(
        sender: SenderType.human,
        content: 'Anh co the gui ma don hang de em kiem tra them chi tiet.',
      ),
    ],
  ),
  SupportTicket(
    number: 104,
    customerName: 'Tran Mai',
    source: TicketSource.email,
    status: TicketStatus.pending,
    intent: TicketIntent.complaint,
    summary: 'Khach bao don giao cham va muon gap nhan vien phu trach.',
    createdAgo: '22 phut truoc',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content:
            'Don hang cua toi tre 3 ngay roi. Vui long cho toi gap nhan vien.',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content:
            'Em xin loi vi trai nghiem nay. Em da tao ticket uu tien cho nhan vien.',
      ),
    ],
  ),
  SupportTicket(
    number: 101,
    customerName: 'Tran Thi B',
    source: TicketSource.web,
    status: TicketStatus.resolved,
    intent: TicketIntent.question,
    summary: 'AI da tu van size XL va ticket da duoc dong.',
    createdAgo: '1 gio truoc',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content: 'Minh cao 1m75 nang 72kg thi mac size nao?',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content:
            'Theo bang size, anh nen chon size XL de thoai mai khi van dong.',
      ),
    ],
  ),
];
