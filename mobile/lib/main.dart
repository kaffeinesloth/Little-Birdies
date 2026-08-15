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
      home: const StaffWorkspaceShell(),
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
            label: 'Tickets',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
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
                Text(
                  'Unified Inbox',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
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

  @override
  void initState() {
    super.initState();
    _status = widget.ticket.status;
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
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ticket.customerName),
            Text(
              '#${ticket.number} · ${ticket.source.label}',
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _status = TicketStatus.inProgress);
                        },
                        icon: const Icon(Icons.pan_tool_alt_outlined, size: 18),
                        label: const Text('Take ticket'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() => _status = TicketStatus.resolved);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Resolve'),
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
                return ChatBubble(message: ticket.messages[index]);
              },
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: ticket.messages.length,
            ),
          ),
          ReplyComposer(controller: _replyController),
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
          title: 'Urgent Alerts',
          subtitle: 'Push notifications that need staff attention.',
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
          title: 'Push service',
          body:
              'FCM token ready · Complaint escalation enabled · Realtime sync active',
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
          title: 'Simple Dashboard',
          subtitle: 'Super admin mobile summary.',
        ),
        const SizedBox(height: 14),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatCard(label: 'Tickets today', value: '34', icon: Icons.today),
            StatCard(label: 'Open tickets', value: '8', icon: Icons.inbox),
            StatCard(label: 'Resolved', value: '26', icon: Icons.task_alt),
            StatCard(label: 'AI handled', value: '76%', icon: Icons.smart_toy),
          ],
        ),
        const SizedBox(height: 18),
        SectionPanel(
          icon: Icons.trending_up,
          title: 'Response performance',
          body:
              'Average first response is 42 seconds. Urgent complaint handoff is currently under 1 minute.',
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
          title: 'Profile',
          subtitle: 'Staff account and availability.',
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
                      'Nguyen Agent',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'agent · Staff mobile app',
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
          title: 'Permissions',
          body:
              'Can view assigned or open tickets, reply to customers, and close resolved conversations.',
        ),
        const SizedBox(height: 12),
        const SectionPanel(
          icon: Icons.phone_android,
          title: 'Device status',
          body:
              'FCM push token registered · Last seen just now · Realtime channel subscribed',
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
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
                'Smart Helpdesk',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                isOnline
                    ? 'Online · receiving tickets'
                    : 'Offline · notifications paused',
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
              '2 urgent complaints are waiting for human takeover.',
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
        padding: const EdgeInsets.all(14),
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
  const ReplyComposer({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Reply to customer...',
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
            onPressed: () => controller.clear(),
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
  all('All'),
  urgent('Urgent'),
  open('Open'),
  inProgress('In Progress'),
  resolved('Resolved');

  const TicketFilter(this.label);
  final String label;
}

enum TicketSource {
  web('Web', Icons.language, AppColors.primary, AppColors.primarySoft),
  facebook('Facebook', Icons.facebook, AppColors.indigo, AppColors.indigoSoft),
  email('Email', Icons.mail_outline, AppColors.success, AppColors.successSoft);

  const TicketSource(this.label, this.icon, this.color, this.softColor);
  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
}

enum TicketStatus {
  open('Open', AppColors.warning, AppColors.warningSoft),
  inProgress('In Progress', AppColors.primary, AppColors.primarySoft),
  pending('Pending', AppColors.warning, AppColors.warningSoft),
  resolved('Resolved', AppColors.success, AppColors.successSoft);

  const TicketStatus(this.label, this.color, this.softColor);
  final String label;
  final Color color;
  final Color softColor;
}

enum TicketIntent {
  question(
    'Question',
    Icons.help_outline,
    AppColors.primary,
    AppColors.primarySoft,
  ),
  complaint(
    'Complaint',
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
  customer('Customer', Icons.person, AppColors.slate500),
  bot('AI Bot', Icons.smart_toy, AppColors.primary),
  human('Staff', Icons.support_agent, AppColors.success);

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
    customerName: 'Khach Hang SP-992',
    source: TicketSource.web,
    status: TicketStatus.open,
    intent: TicketIntent.complaint,
    summary:
        'San pham bi rach, khach yeu cau shop xu ly ngay va can nhan vien tiep nhan.',
    createdAgo: 'Just now',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content: 'Ao moi nhan da bi rach o phan vai. Shop xu ly ngay giup toi.',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content:
            'Em da ghi nhan van de va chuyen ticket nay cho nhan vien ho tro.',
      ),
      TicketMessage(
        sender: SenderType.customer,
        content: 'Toi can doi hang hoac hoan tien hom nay.',
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
    createdAgo: '15 min ago',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content: 'San pham nay bao hanh bao lau vay shop?',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content: 'San pham duoc bao hanh 6 thang theo chinh sach cua shop.',
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
    createdAgo: '22 min ago',
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
    customerName: 'Le Minh',
    source: TicketSource.web,
    status: TicketStatus.resolved,
    intent: TicketIntent.question,
    summary: 'AI da tu van size XL va ticket da duoc dong.',
    createdAgo: '1 hour ago',
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
