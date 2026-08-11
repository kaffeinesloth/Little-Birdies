import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SmartHelpdeskWebApp());
}

class SmartHelpdeskWebApp extends StatefulWidget {
  const SmartHelpdeskWebApp({super.key});

  @override
  State<SmartHelpdeskWebApp> createState() => _SmartHelpdeskWebAppState();
}

class _SmartHelpdeskWebAppState extends State<SmartHelpdeskWebApp> {
  UserSession? _session;

  void _signIn(UserRole role) {
    setState(() {
      _session = UserSession(
        id: role == UserRole.superAdmin ? ownerDemoId : agentDemoId,
        email: role == UserRole.superAdmin
            ? 'owner@example.com'
            : 'agent@example.com',
        fullName: role == UserRole.superAdmin ? 'Shop Owner' : 'Support Agent',
        role: role,
      );
    });
  }

  void _signOut() => setState(() => _session = null);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Helpdesk Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff0f766e),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff7fafc),
        useMaterial3: true,
      ),
      home: _session == null
          ? LoginPage(onSignIn: _signIn)
          : AdminShell(session: _session!, onSignOut: _signOut),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onSignIn});

  final ValueChanged<UserRole> onSignIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(text: 'owner@example.com');
  final _password = TextEditingController(text: 'password');
  UserRole _role = UserRole.superAdmin;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xffd8dee4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.radio_button_checked,
                        color: Color(0xff0f766e), size: 42),
                    const SizedBox(height: 16),
                    Text(
                      'Smart Helpdesk',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Flutter web admin console',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<UserRole>(
                      selected: {_role},
                      onSelectionChanged: (value) {
                        setState(() => _role = value.first);
                      },
                      segments: const [
                        ButtonSegment(
                          value: UserRole.superAdmin,
                          icon: Icon(Icons.admin_panel_settings),
                          label: Text('Owner'),
                        ),
                        ButtonSegment(
                          value: UserRole.agent,
                          icon: Icon(Icons.support_agent),
                          label: Text('Agent'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => widget.onSignIn(_role),
                      icon: const Icon(Icons.login),
                      label: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.session,
    required this.onSignOut,
  });

  final UserSession session;
  final VoidCallback onSignOut;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _api = SmartHelpdeskWebApiClient();
  int _selectedIndex = 0;

  List<NavItem> get _items {
    final items = <NavItem>[
      const NavItem('Inbox', Icons.inbox),
      const NavItem('Dashboard', Icons.bar_chart),
    ];
    if (widget.session.role == UserRole.superAdmin) {
      items.addAll(const [
        NavItem('Knowledge Base', Icons.menu_book),
        NavItem('Staff', Icons.groups),
        NavItem('Channels', Icons.settings_input_component),
      ]);
    }
    items.add(const NavItem('Widget Demo', Icons.chat_bubble_outline));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final selected = items[_selectedIndex.clamp(0, items.length - 1)];

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final content = _screenFor(selected.label);
          if (!wide) {
            return Column(
              children: [
                _MobileTopBar(
                    session: widget.session, onSignOut: widget.onSignOut),
                Expanded(child: content),
              ],
            );
          }
          return Row(
            children: [
              _SideNav(
                items: items,
                selectedIndex: _selectedIndex,
                session: widget.session,
                onSignOut: widget.onSignOut,
                onSelect: (index) => setState(() => _selectedIndex = index),
              ),
              Expanded(child: content),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) return const SizedBox.shrink();
          return NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: [
              for (final item in items)
                NavigationDestination(icon: Icon(item.icon), label: item.label),
            ],
          );
        },
      ),
    );
  }

  Widget _screenFor(String label) {
    return switch (label) {
      'Dashboard' => const DashboardPage(),
      'Knowledge Base' => const KnowledgeBasePage(),
      'Staff' => const StaffPage(),
      'Channels' => const ChannelsPage(),
      'Widget Demo' => WidgetDemoPage(api: _api),
      _ => InboxPage(api: _api, session: widget.session),
    };
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.items,
    required this.selectedIndex,
    required this.session,
    required this.onSignOut,
    required this.onSelect,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final UserSession session;
  final VoidCallback onSignOut;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xffd8dee4))),
      ),
      child: Column(
        children: [
          const SizedBox(
            height: 72,
            child: ListTile(
              leading: _BrandIcon(),
              title: Text('Smart Helpdesk',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Admin Console'),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    selected: selectedIndex == index,
                    selectedTileColor: const Color(0xffe6fffb),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    onTap: () => onSelect(index),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(session.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(roleLabel(session.role)),
            trailing: IconButton(
              tooltip: 'Sign out',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.session, required this.onSignOut});

  final UserSession session;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xffd8dee4))),
        ),
        child: Row(
          children: [
            const _BrandIcon(),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Smart Helpdesk',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            Text(roleLabel(session.role)),
            IconButton(
              tooltip: 'Sign out',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
      ),
    );
  }
}

class InboxPage extends StatefulWidget {
  const InboxPage({super.key, required this.api, required this.session});

  final SmartHelpdeskWebApiClient api;
  final UserSession session;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  TicketStatus? _status;
  ChannelType? _channel;
  Ticket? _selected;
  List<Ticket> _tickets = DemoData.tickets;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tickets = await widget.api.fetchTickets(widget.session.accessToken);
      if (!mounted) return;
      setState(() {
        _tickets = tickets.isEmpty ? DemoData.tickets : tickets;
        _selected = _tickets.isEmpty ? null : _tickets.first;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _tickets = DemoData.tickets;
        _selected = DemoData.tickets.first;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _replaceSelectedTicket(Ticket ticket) {
    setState(() {
      _selected = ticket;
      _tickets = [
        for (final item in _tickets) item.id == ticket.id ? ticket : item,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final tickets = _tickets.where((ticket) {
      return (_status == null || ticket.status == _status) &&
          (_channel == null || ticket.source == _channel);
    }).toList();

    return PageScaffold(
      title: 'Unified Inbox',
      subtitle: 'Web, Facebook, and email conversations in one Flutter view.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final list = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                InlineNotice(
                  icon: Icons.cloud_off,
                  text: 'Using local demo data. Backend said: $_error',
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All status'),
                    selected: _status == null,
                    onSelected: (_) => setState(() => _status = null),
                  ),
                  for (final status in TicketStatus.values)
                    FilterChip(
                      label: Text(statusLabel(status)),
                      selected: _status == status,
                      onSelected: (_) => setState(() => _status = status),
                    ),
                  const SizedBox(width: 8),
                  for (final channel in ChannelType.values)
                    FilterChip(
                      avatar: Icon(channelIcon(channel), size: 16),
                      label: Text(channelLabel(channel)),
                      selected: _channel == channel,
                      onSelected: (_) => setState(() {
                        _channel = _channel == channel ? null : channel;
                      }),
                    ),
                  IconButton.outlined(
                    tooltip: 'Refresh tickets',
                    onPressed: _loading ? null : _loadTickets,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: tickets.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final ticket = tickets[index];
                          return TicketCard(
                            ticket: ticket,
                            selected: _selected?.id == ticket.id,
                            onTap: () => setState(() => _selected = ticket),
                          );
                        },
                      ),
              ),
            ],
          );
          if (!wide) return list;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 420, child: list),
              const SizedBox(width: 16),
              Expanded(
                child: TicketDetailPanel(
                  api: widget.api,
                  session: widget.session,
                  ticket: _selected,
                  onTicketChanged: _replaceSelectedTicket,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.ticket,
    required this.selected,
    required this.onTap,
  });

  final Ticket ticket;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: selected ? const Color(0xffecfeff) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? const Color(0xff0f766e) : const Color(0xffd8dee4),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xffe2e8f0),
          child:
              Icon(channelIcon(ticket.source), color: const Color(0xff334155)),
        ),
        title: Text(ticket.customerName,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Chip(label: Text(channelLabel(ticket.source))),
                  Chip(label: Text(statusLabel(ticket.status))),
                  Chip(label: Text(ticket.intent)),
                ],
              ),
              const SizedBox(height: 8),
              Text(ticket.summary,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class TicketDetailPanel extends StatelessWidget {
  const TicketDetailPanel({
    super.key,
    required this.api,
    required this.session,
    required this.ticket,
    required this.onTicketChanged,
  });

  final SmartHelpdeskWebApiClient api;
  final UserSession session;
  final Ticket? ticket;
  final ValueChanged<Ticket> onTicketChanged;

  @override
  Widget build(BuildContext context) {
    if (ticket == null) {
      return const EmptyPanel(icon: Icons.inbox, title: 'Select a ticket');
    }
    return TicketDetailBody(
      api: api,
      session: session,
      ticket: ticket!,
      onTicketChanged: onTicketChanged,
    );
  }
}

class TicketDetailBody extends StatefulWidget {
  const TicketDetailBody({
    super.key,
    required this.api,
    required this.session,
    required this.ticket,
    required this.onTicketChanged,
  });

  final SmartHelpdeskWebApiClient api;
  final UserSession session;
  final Ticket ticket;
  final ValueChanged<Ticket> onTicketChanged;

  @override
  State<TicketDetailBody> createState() => _TicketDetailBodyState();
}

class _TicketDetailBodyState extends State<TicketDetailBody> {
  final _reply = TextEditingController();
  List<MessageItem> _messages = const <MessageItem>[];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void didUpdateWidget(covariant TicketDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticket.id != widget.ticket.id) {
      _reply.clear();
      _loadMessages();
    }
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await widget.api.fetchMessages(
        widget.ticket.id,
        widget.session.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages.isEmpty
            ? DemoData.messages[widget.ticket.id] ?? const <MessageItem>[]
            : messages;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _messages =
            DemoData.messages[widget.ticket.id] ?? const <MessageItem>[];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendReply() async {
    final content = _reply.text.trim();
    if (content.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await widget.api.sendReply(
        widget.ticket.id,
        content,
        widget.session.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _reply.clear();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resolve() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.api.resolveTicket(
        widget.ticket,
        widget.session.accessToken,
      );
      if (!mounted) return;
      widget.onTicketChanged(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.ticket.customerName,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text('${widget.ticket.id} · ${widget.ticket.summary}'),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed:
                    _saving || widget.ticket.status == TicketStatus.resolved
                        ? null
                        : _resolve,
                icon: const Icon(Icons.check),
                label: const Text('Resolve'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InlineNotice(icon: Icons.error_outline, text: _error!),
          ],
          const SizedBox(height: 18),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final human = message.senderType == 'human';
                      return Align(
                        alignment: human
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: human
                                  ? const Color(0xff0f766e)
                                  : const Color(0xfff1f5f9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                message.content,
                                style: TextStyle(
                                  color: human
                                      ? Colors.white
                                      : const Color(0xff0f172a),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _reply,
                  decoration: InputDecoration(
                    hintText: 'Write a reply',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: _saving ? null : _sendReply,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Dashboard',
      subtitle: 'Operational metrics for AI-assisted support.',
      child: SingleChildScrollView(
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width >= 1100 ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.5,
              children: const [
                MetricCard(
                    label: 'Messages today', value: '186', delta: '+12%'),
                MetricCard(label: 'AI handled', value: '78%', delta: '+6%'),
                MetricCard(label: 'Avg response', value: '4.2s', delta: '-31%'),
                MetricCard(label: 'Open tickets', value: '14', delta: '+3'),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final trend = SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PanelTitle('Seven-day message trend'),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 220,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final point in DemoData.trend)
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 5),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: FractionallySizedBox(
                                            heightFactor: point.count / 100,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xff0f766e),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(point.day),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
                final questions = SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PanelTitle('Top questions'),
                      const SizedBox(height: 10),
                      for (final item in DemoData.topQuestions)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.question),
                          trailing: Text('${item.count}'),
                        ),
                    ],
                  ),
                );
                if (!wide) {
                  return Column(
                      children: [trend, const SizedBox(height: 16), questions]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: trend),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: questions),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class KnowledgeBasePage extends StatelessWidget {
  const KnowledgeBasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Knowledge Base',
      subtitle: 'Document ingestion status for RAG answers.',
      child: SurfacePanel(
        child: ListView.separated(
          itemCount: DemoData.documents.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final doc = DemoData.documents[index];
            return ListTile(
              leading: Icon(fileIcon(doc.fileType)),
              title: Text(doc.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${doc.chunkCount} chunks · uploaded by ${doc.uploadedBy}'),
              trailing: Chip(label: Text(doc.status)),
            );
          },
        ),
      ),
    );
  }
}

class StaffPage extends StatelessWidget {
  const StaffPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Staff',
      subtitle: 'Agents, owners, and account status.',
      child: SurfacePanel(
        child: ListView.separated(
          itemCount: DemoData.staff.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final staff = DemoData.staff[index];
            return ListTile(
              leading: CircleAvatar(child: Text(staff.name.substring(0, 1))),
              title: Text(staff.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${staff.email} · ${roleLabel(staff.role)}'),
              trailing: Chip(label: Text(staff.status)),
            );
          },
        ),
      ),
    );
  }
}

class ChannelsPage extends StatelessWidget {
  const ChannelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Channels',
      subtitle: 'Inbound and outbound integration status.',
      child: GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width >= 1000 ? 3 : 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.8,
        children: const [
          ChannelPanel(
            icon: Icons.public,
            title: 'Web chat',
            body: 'Widget enabled with local sender identity.',
            status: 'active',
          ),
          ChannelPanel(
            icon: Icons.facebook,
            title: 'Facebook',
            body: 'Webhook boundary configured for Messenger events.',
            status: 'mock',
          ),
          ChannelPanel(
            icon: Icons.email,
            title: 'Email',
            body: 'Inbound email provider adapter ready for secrets.',
            status: 'mock',
          ),
        ],
      ),
    );
  }
}

class WidgetDemoPage extends StatefulWidget {
  const WidgetDemoPage({super.key, required this.api});

  final SmartHelpdeskWebApiClient api;

  @override
  State<WidgetDemoPage> createState() => _WidgetDemoPageState();
}

class _WidgetDemoPageState extends State<WidgetDemoPage> {
  final _message = TextEditingController(text: 'How long is the warranty?');
  final _senderId = 'web-demo-customer';
  final List<WidgetChatMessage> _messages = [
    const WidgetChatMessage(
      content: 'Hi, how long is the headphone warranty?',
      isCustomer: true,
    ),
    const WidgetChatMessage(
      content:
          'Most headphones include a 12-month warranty. I can connect you with an agent for order-specific help.',
      isCustomer: false,
    ),
  ];
  bool _sending = false;
  String? _status;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _message.text.trim();
    if (content.isEmpty) return;
    setState(() {
      _sending = true;
      _status = null;
      _messages.add(WidgetChatMessage(content: content, isCustomer: true));
      _message.clear();
    });
    try {
      final result = await widget.api.sendWebMessage(
        senderId: _senderId,
        customerName: 'Demo Customer',
        content: content,
      );
      final bot = result.botMessage;
      if (!mounted) return;
      setState(() {
        if (bot != null) {
          _messages
              .add(WidgetChatMessage(content: bot.content, isCustomer: false));
        }
        _status =
            '${result.action} · ${result.intent} · ticket ${result.ticketId}';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          WidgetChatMessage(
            content:
                'The local API is not reachable. Start the stack with ./start.sh.',
            isCustomer: false,
          ),
        );
        _status = error.message;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Widget Demo',
      subtitle: 'Customer-side chat flow rendered in Flutter.',
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SurfacePanel(
            child: Column(
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _BrandIcon(),
                  title: Text('Little Birdies Support',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Usually replies in a few seconds'),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: [
                      for (final message in _messages)
                        ChatBubble(
                          text: message.content,
                          alignRight: message.isCustomer,
                        ),
                    ],
                  ),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 10),
                  InlineNotice(icon: Icons.info_outline, text: _status!),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _message,
                        onSubmitted: (_) => _sending ? null : _send(),
                        decoration: const InputDecoration(
                          hintText: 'Ask a question',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xffd8dee4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Chip(label: Text(delta)),
            ],
          ),
        ],
      ),
    );
  }
}

class ChannelPanel extends StatelessWidget {
  const ChannelPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String body;
  final String status;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      child: Row(
        children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Chip(label: Text(status)),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.text, required this.alignRight});

  final String text;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: alignRight ? const Color(0xff0f766e) : const Color(0xfff1f5f9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(color: alignRight ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}

class InlineNotice extends StatelessWidget {
  const InlineNotice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xfffffbeb),
        border: Border.all(color: const Color(0xfff59e0b)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xff92400e), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Colors.grey),
            const SizedBox(height: 12),
            Text(title),
          ],
        ),
      ),
    );
  }
}

class PanelTitle extends StatelessWidget {
  const PanelTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w800));
  }
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xff0f766e),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.radio_button_checked, color: Colors.white),
    );
  }
}

enum UserRole { superAdmin, agent }

enum TicketStatus { open, inProgress, pending, resolved }

enum ChannelType { web, facebook, email }

class UserSession {
  const UserSession({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;

  String get accessToken {
    return 'mock:$id:$email:${roleLabel(role)}:online';
  }
}

class NavItem {
  const NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class Ticket {
  const Ticket({
    required this.id,
    required this.customerName,
    required this.source,
    required this.status,
    required this.intent,
    required this.summary,
  });

  final String id;
  final String customerName;
  final ChannelType source;
  final TicketStatus status;
  final String intent;
  final String summary;

  Ticket copyWith({TicketStatus? status, String? summary}) {
    return Ticket(
      id: id,
      customerName: customerName,
      source: source,
      status: status ?? this.status,
      intent: intent,
      summary: summary ?? this.summary,
    );
  }
}

class MessageItem {
  const MessageItem({
    required this.senderType,
    required this.content,
  });

  final String senderType;
  final String content;
}

class WidgetChatMessage {
  const WidgetChatMessage({required this.content, required this.isCustomer});

  final String content;
  final bool isCustomer;
}

class WebMessageResult {
  const WebMessageResult({
    required this.ticketId,
    required this.action,
    required this.intent,
    this.botMessage,
  });

  final String ticketId;
  final String action;
  final String intent;
  final MessageItem? botMessage;
}

class KnowledgeDocument {
  const KnowledgeDocument({
    required this.name,
    required this.fileType,
    required this.status,
    required this.chunkCount,
    required this.uploadedBy,
  });

  final String name;
  final String fileType;
  final String status;
  final int chunkCount;
  final String uploadedBy;
}

class StaffUser {
  const StaffUser({
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });

  final String name;
  final String email;
  final UserRole role;
  final String status;
}

class TrendPoint {
  const TrendPoint(this.day, this.count);

  final String day;
  final int count;
}

class QuestionCount {
  const QuestionCount(this.question, this.count);

  final String question;
  final int count;
}

class DemoData {
  static const tickets = <Ticket>[
    Ticket(
      id: 'TCK-1024',
      customerName: 'Linh Tran',
      source: ChannelType.web,
      status: TicketStatus.pending,
      intent: 'complaint',
      summary: 'Refund request after delayed delivery',
    ),
    Ticket(
      id: 'TCK-1023',
      customerName: 'Minh Pham',
      source: ChannelType.facebook,
      status: TicketStatus.open,
      intent: 'question',
      summary: 'Asked about warranty period for headphones',
    ),
    Ticket(
      id: 'TCK-1022',
      customerName: 'An Nguyen',
      source: ChannelType.email,
      status: TicketStatus.inProgress,
      intent: 'question',
      summary: 'Needs invoice copy for order #4821',
    ),
  ];

  static const messages = <String, List<MessageItem>>{
    'TCK-1024': [
      MessageItem(
        senderType: 'customer',
        content:
            'I want a refund because my delivery is late and nobody has replied.',
      ),
      MessageItem(
        senderType: 'bot',
        content:
            'I am sorry about the delay. A staff member is reviewing this now.',
      ),
    ],
    'TCK-1023': [
      MessageItem(
        senderType: 'customer',
        content: 'How long is the warranty for the wireless headphones?',
      ),
      MessageItem(
        senderType: 'bot',
        content:
            'Most headphones include a 12-month warranty. I can connect you with an agent if you need order-specific help.',
      ),
    ],
    'TCK-1022': [
      MessageItem(
        senderType: 'customer',
        content: 'Can you send me another invoice copy for order #4821?',
      ),
      MessageItem(
        senderType: 'human',
        content: 'I found the order and will send the invoice to this thread.',
      ),
    ],
  };

  static const documents = <KnowledgeDocument>[
    KnowledgeDocument(
      name: 'Return policy.txt',
      fileType: 'txt',
      status: 'ready',
      chunkCount: 18,
      uploadedBy: 'Shop Owner',
    ),
    KnowledgeDocument(
      name: 'Warranty terms.pdf',
      fileType: 'pdf',
      status: 'processing',
      chunkCount: 0,
      uploadedBy: 'Shop Owner',
    ),
    KnowledgeDocument(
      name: 'Shipping FAQ.docx',
      fileType: 'docx',
      status: 'ready',
      chunkCount: 24,
      uploadedBy: 'Shop Owner',
    ),
  ];

  static const staff = <StaffUser>[
    StaffUser(
      name: 'Support Agent',
      email: 'agent@example.com',
      role: UserRole.agent,
      status: 'online',
    ),
    StaffUser(
      name: 'Shop Owner',
      email: 'owner@example.com',
      role: UserRole.superAdmin,
      status: 'online',
    ),
    StaffUser(
      name: 'Evening Agent',
      email: 'evening@example.com',
      role: UserRole.agent,
      status: 'offline',
    ),
  ];

  static const trend = <TrendPoint>[
    TrendPoint('Mon', 48),
    TrendPoint('Tue', 62),
    TrendPoint('Wed', 71),
    TrendPoint('Thu', 56),
    TrendPoint('Fri', 88),
    TrendPoint('Sat', 93),
    TrendPoint('Sun', 78),
  ];

  static const topQuestions = <QuestionCount>[
    QuestionCount('What is the warranty period?', 31),
    QuestionCount('How do I request a refund?', 24),
    QuestionCount('Where is my delivery?', 22),
    QuestionCount('Can I get another invoice?', 17),
  ];
}

class SmartHelpdeskWebApiClient {
  SmartHelpdeskWebApiClient({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://localhost:8000',
            ),
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Future<List<Ticket>> fetchTickets(String accessToken) async {
    final payload = await _get('/tickets?limit=50&offset=0', accessToken);
    final items = payload['items'] as List<dynamic>? ?? const <dynamic>[];
    return [
      for (final item in items) _ticketFromJson(item as Map<String, dynamic>),
    ];
  }

  Future<List<MessageItem>> fetchMessages(
    String ticketId,
    String accessToken,
  ) async {
    final payload = await _get('/tickets/$ticketId/messages', accessToken);
    final items = payload['items'] as List<dynamic>? ?? const <dynamic>[];
    return [
      for (final item in items) _messageFromJson(item as Map<String, dynamic>),
    ];
  }

  Future<MessageItem> sendReply(
    String ticketId,
    String content,
    String accessToken,
  ) async {
    final payload = await _post(
      '/tickets/$ticketId/messages',
      accessToken,
      {'content': content},
    );
    return _messageFromJson(payload['message'] as Map<String, dynamic>);
  }

  Future<Ticket> resolveTicket(Ticket ticket, String accessToken) async {
    final payload =
        await _post('/tickets/${ticket.id}/resolve', accessToken, {});
    return _ticketFromJson(payload);
  }

  Future<WebMessageResult> sendWebMessage({
    required String senderId,
    required String customerName,
    required String content,
  }) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/webhooks/web-message'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'sender_id': senderId,
        'customer_name': customerName,
        'content': content,
      }),
    );
    final payload = _decode(response);
    final botPayload = payload['bot_message'];
    return WebMessageResult(
      ticketId: ((payload['ticket'] as Map?)?['id'] ?? 'unknown').toString(),
      action: (payload['action'] ?? 'recorded').toString(),
      intent: (payload['intent'] ?? 'question').toString(),
      botMessage: botPayload is Map<String, dynamic>
          ? _messageFromJson(botPayload)
          : null,
    );
  }

  Future<Map<String, dynamic>> _get(String path, String accessToken) async {
    final response = await _http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(accessToken),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    String accessToken,
    Map<String, dynamic> body,
  ) async {
    final response = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, String> _headers(String accessToken) {
    return {
      'authorization': 'Bearer $accessToken',
      'content-type': 'application/json',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(
        'API ${response.statusCode}: ${response.body.isEmpty ? response.reasonPhrase : response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

Ticket _ticketFromJson(Map<String, dynamic> json) {
  return Ticket(
    id: json['id']?.toString() ?? '',
    customerName:
        (json['customer_name'] ?? json['customerName'] ?? 'Unknown customer')
            .toString(),
    source: channelFromValue(json['source']?.toString()),
    status: ticketStatusFromValue(json['status']?.toString()),
    intent: (json['intent'] ?? 'question').toString(),
    summary: (json['summary'] ?? json['last_message_preview'] ?? 'No preview')
        .toString(),
  );
}

MessageItem _messageFromJson(Map<String, dynamic> json) {
  return MessageItem(
    senderType:
        (json['sender_type'] ?? json['senderType'] ?? 'customer').toString(),
    content: (json['content'] ?? '').toString(),
  );
}

const ownerDemoId = '00000000-0000-4000-8000-000000000001';
const agentDemoId = '00000000-0000-4000-8000-000000000002';

String roleLabel(UserRole role) {
  return switch (role) {
    UserRole.superAdmin => 'super_admin',
    UserRole.agent => 'agent',
  };
}

String statusLabel(TicketStatus status) {
  return switch (status) {
    TicketStatus.open => 'open',
    TicketStatus.inProgress => 'in_progress',
    TicketStatus.pending => 'pending',
    TicketStatus.resolved => 'resolved',
  };
}

TicketStatus ticketStatusFromValue(String? value) {
  return switch (value) {
    'in_progress' => TicketStatus.inProgress,
    'pending' => TicketStatus.pending,
    'resolved' => TicketStatus.resolved,
    _ => TicketStatus.open,
  };
}

String channelLabel(ChannelType channel) {
  return switch (channel) {
    ChannelType.web => 'web',
    ChannelType.facebook => 'facebook',
    ChannelType.email => 'email',
  };
}

ChannelType channelFromValue(String? value) {
  return switch (value) {
    'facebook' => ChannelType.facebook,
    'email' => ChannelType.email,
    _ => ChannelType.web,
  };
}

IconData channelIcon(ChannelType channel) {
  return switch (channel) {
    ChannelType.web => Icons.public,
    ChannelType.facebook => Icons.facebook,
    ChannelType.email => Icons.email,
  };
}

IconData fileIcon(String fileType) {
  return switch (fileType) {
    'pdf' => Icons.picture_as_pdf,
    'docx' => Icons.description,
    _ => Icons.article,
  };
}
