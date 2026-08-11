import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'auth_service.dart';
import 'models.dart';
import 'push_service.dart';

void main() {
  runApp(const SmartHelpdeskMobileApp());
}

class SmartHelpdeskMobileApp extends StatefulWidget {
  const SmartHelpdeskMobileApp({super.key});

  @override
  State<SmartHelpdeskMobileApp> createState() => _SmartHelpdeskMobileAppState();
}

class _SmartHelpdeskMobileAppState extends State<SmartHelpdeskMobileApp> {
  final _auth = SupabaseAuthPlaceholder();
  final _api = SmartHelpdeskApiClient();
  final _push = PushNotificationService();
  AuthSession? _session;

  Future<void> _signIn(String email, String password, UserRole role) async {
    final session =
        await _auth.signIn(email: email, password: password, role: role);
    setState(() => _session = session);
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Helpdesk',
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
          ? LoginScreen(onSignIn: _signIn, mockMode: _auth.isMockMode)
          : MainShell(
              api: _api,
              push: _push,
              session: _session!,
              onSignOut: _signOut,
            ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen(
      {super.key, required this.onSignIn, required this.mockMode});

  final Future<void> Function(String email, String password, UserRole role)
      onSignIn;
  final bool mockMode;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'owner@example.com');
  final _passwordController = TextEditingController(text: 'password');
  UserRole _role = UserRole.superAdmin;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSignIn(
          _emailController.text, _passwordController.text, _role);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.support_agent,
                          size: 42, color: Color(0xff0f766e)),
                      const SizedBox(height: 16),
                      Text(
                        'Smart Helpdesk',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Supabase Auth-compatible local mock login',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: StatusChip(
                            label: widget.mockMode
                                ? 'local mock mode'
                                : 'supabase env configured'),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                            labelText: 'Email', border: OutlineInputBorder()),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder()),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<UserRole>(
                        segments: const [
                          ButtonSegment(
                              value: UserRole.superAdmin,
                              label: Text('super_admin')),
                          ButtonSegment(
                              value: UserRole.agent, label: Text('agent')),
                        ],
                        selected: {_role},
                        onSelectionChanged: (value) =>
                            setState(() => _role = value.first),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.api,
    required this.push,
    required this.session,
    required this.onSignOut,
  });

  final SmartHelpdeskApiClient api;
  final PushNotificationService push;
  final AuthSession session;
  final Future<void> Function() onSignOut;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  PresenceStatus _presence = PresenceStatus.online;
  Timer? _heartbeatTimer;
  final List<NotificationItem> _notifications = List.of(MockData.notifications);

  @override
  void initState() {
    super.initState();
    _startOnlineWorkflows();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _startOnlineWorkflows() async {
    await widget.api
        .updatePresence(_presence, accessToken: widget.session.accessToken);
    final token = await widget.push.getDeviceToken();
    if (token != null) {
      await widget.api
          .registerPushToken(token, accessToken: widget.session.accessToken);
    }
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    if (_presence != PresenceStatus.online) return;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      widget.api.sendHeartbeat(accessToken: widget.session.accessToken);
    });
  }

  List<_Destination> get _destinations {
    final base = <_Destination>[
      const _Destination('Inbox', Icons.inbox),
      const _Destination('Notifications', Icons.notifications),
    ];
    if (widget.session.user.role == UserRole.superAdmin) {
      base.add(const _Destination('Dashboard', Icons.bar_chart));
    }
    base.add(const _Destination('Profile', Icons.person));
    return base;
  }

  Future<void> _setPresence(bool online) async {
    final next = online ? PresenceStatus.online : PresenceStatus.offline;
    setState(() => _presence = next);
    await widget.api
        .updatePresence(next, accessToken: widget.session.accessToken);
    _startHeartbeat();
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    final selected = destinations[_index.clamp(0, destinations.length - 1)];
    final body = switch (selected.label) {
      'Inbox' => InboxScreen(api: widget.api, session: widget.session),
      'Notifications' => NotificationsScreen(
          api: widget.api,
          session: widget.session,
          notifications: _notifications,
          onCreateMockNotification: () {
            setState(() {
              _notifications.insert(
                  0, widget.push.mockUrgentTicketNotification());
            });
          }),
      'Dashboard' => DashboardScreen(api: widget.api, session: widget.session),
      _ => ProfileScreen(session: widget.session, onSignOut: widget.onSignOut),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(selected.label),
        actions: [
          Row(
            children: [
              Text(_presence == PresenceStatus.online ? 'Online' : 'Offline'),
              Switch(
                  value: _presence == PresenceStatus.online,
                  onChanged: _setPresence),
            ],
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon);

  final String label;
  final IconData icon;
}

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key, required this.api, required this.session});

  final SmartHelpdeskApiClient api;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Ticket>>(
      future: api.fetchTickets(accessToken: session.accessToken),
      builder: (context, snapshot) {
        final tickets = snapshot.data ?? MockData.tickets;
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return TicketTile(
              ticket: ticket,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TicketDetailScreen(
                      api: api, session: session, ticket: ticket),
                ),
              ),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemCount: tickets.length,
        );
      },
    );
  }
}

class TicketTile extends StatelessWidget {
  const TicketTile({super.key, required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        onTap: onTap,
        title: Text(ticket.customerName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  SourceBadge(source: ticket.source),
                  StatusChip(label: _statusLabel(ticket.status)),
                  StatusChip(label: ticket.intent),
                ],
              ),
              const SizedBox(height: 6),
              Text(ticket.preview,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(_timeAgo(ticket.updatedAt),
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        leading: CircleAvatar(
            child: Text(_sourceLabel(ticket.source).substring(0, 1))),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.api,
    required this.session,
    required this.ticket,
  });

  final SmartHelpdeskApiClient api;
  final AuthSession session;
  final Ticket ticket;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _replyController = TextEditingController();
  late Ticket _ticket = widget.ticket;
  List<Message>? _messages;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages = await widget.api
        .fetchMessages(_ticket.id, accessToken: widget.session.accessToken);
    if (mounted) {
      setState(() {
        _messages = messages;
        _loading = false;
      });
    }
  }

  Future<void> _sendReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final message = await widget.api.sendReply(_ticket.id, content,
        accessToken: widget.session.accessToken);
    setState(() {
      _messages = [...(_messages ?? <Message>[]), message];
      _ticket = _ticket.copyWith(preview: content, updatedAt: DateTime.now());
      _replyController.clear();
      _busy = false;
    });
  }

  Future<void> _toggleResolved() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = _ticket.status == TicketStatus.resolved
          ? await widget.api
              .reopenTicket(_ticket, accessToken: widget.session.accessToken)
          : await widget.api
              .resolveTicket(_ticket, accessToken: widget.session.accessToken);
      setState(() => _ticket = updated);
    } catch (_) {
      setState(() => _error = 'Ticket action failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_ticket.id),
        actions: [
          TextButton.icon(
            onPressed: _busy ? null : _toggleResolved,
            icon: Icon(_ticket.status == TicketStatus.resolved
                ? Icons.refresh
                : Icons.check_circle),
            label: Text(
                _ticket.status == TicketStatus.resolved ? 'Reopen' : 'Resolve'),
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            title: Text(_ticket.customerName,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                SourceBadge(source: _ticket.source),
                StatusChip(label: _ticket.intent),
              ],
            ),
            trailing: StatusChip(label: _statusLabel(_ticket.status)),
          ),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                    onPressed: () => setState(() => _error = null),
                    child: const Text('Dismiss')),
              ],
            ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: (_messages ?? <Message>[]).length,
                    itemBuilder: (context, index) =>
                        MessageBubble(message: _messages![index]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      enabled:
                          !_busy && _ticket.status != TicketStatus.resolved,
                      decoration: const InputDecoration(
                        hintText: 'Write a reply...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy || _ticket.status == TicketStatus.resolved
                        ? null
                        : _sendReply,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final isHuman = message.senderType == 'human';
    final isCustomer = message.senderType == 'customer';
    return Align(
      alignment: isCustomer ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isHuman
              ? const Color(0xffccfbf1)
              : isCustomer
                  ? Colors.white
                  : const Color(0xffeef2ff),
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.senderType.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(message.content),
          ],
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.api,
    required this.session,
    required this.notifications,
    required this.onCreateMockNotification,
  });

  final SmartHelpdeskApiClient api;
  final AuthSession session;
  final List<NotificationItem> notifications;
  final VoidCallback onCreateMockNotification;

  Future<void> _openTicket(
      BuildContext context, NotificationItem notification) async {
    final ticketId = notification.ticketId;
    if (ticketId == null) return;
    final tickets = await api.fetchTickets(accessToken: session.accessToken);
    if (!context.mounted) return;
    Ticket? ticket;
    for (final item in tickets) {
      if (item.id == ticketId) {
        ticket = item;
        break;
      }
    }
    if (ticket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket is not available locally.')),
      );
      return;
    }
    final selectedTicket = ticket;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TicketDetailScreen(
            api: api, session: session, ticket: selectedTicket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MaterialBanner(
          leading: const Icon(Icons.cloud_queue),
          content: const Text(
              'FCM is configured through compile-time env placeholders. Local mock notifications are available for development.'),
          actions: [
            TextButton.icon(
              onPressed: onCreateMockNotification,
              icon: const Icon(Icons.add_alert),
              label: const Text('Mock notification'),
            ),
          ],
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Card(
                elevation: 0,
                child: ListTile(
                  onTap: notification.ticketId == null
                      ? null
                      : () => _openTicket(context, notification),
                  leading: Icon(notification.isRead
                      ? Icons.notifications_none
                      : Icons.notification_important),
                  title: Text(notification.title),
                  subtitle: Text(
                      '${notification.body}\n${_timeAgo(notification.createdAt)}'),
                  isThreeLine: true,
                  trailing: notification.isRead
                      ? const Icon(Icons.chevron_right)
                      : const StatusChip(label: 'new'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.api, required this.session});

  final SmartHelpdeskApiClient api;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSummary>(
      future: api.fetchDashboard(accessToken: session.accessToken),
      builder: (context, snapshot) {
        final summary = snapshot.data ?? MockData.dashboard;
        return GridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 2 : 1,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.6,
          children: [
            MetricCard(
                label: 'Messages today',
                value: '${summary.messagesToday}',
                icon: Icons.message),
            MetricCard(
                label: 'AI handling rate',
                value: '${summary.aiHandlingRate}%',
                icon: Icons.smart_toy),
            MetricCard(
                label: 'Open tickets',
                value: '${summary.openTickets}',
                icon: Icons.inbox),
            MetricCard(
                label: 'Avg response',
                value: '${summary.averageResponseSeconds}s',
                icon: Icons.timer),
          ],
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen(
      {super.key, required this.session, required this.onSignOut});

  final AuthSession session;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          elevation: 0,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(session.user.fullName),
            subtitle: Text(
                '${session.user.email} · ${_roleLabel(session.user.role)}'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Supabase Auth placeholder'),
            subtitle: const Text(
                'Replace the local mock service with Supabase Auth when credentials are configured.'),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xffe6fffb),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xff115e59)),
        ),
      ),
    );
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final ChannelType source;

  @override
  Widget build(BuildContext context) {
    final color = switch (source) {
      ChannelType.facebook => Colors.blue,
      ChannelType.email => Colors.deepPurple,
      ChannelType.web => const Color(0xff0f766e),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          _sourceLabel(source),
          style: TextStyle(fontSize: 12, color: color),
        ),
      ),
    );
  }
}

String _roleLabel(UserRole role) =>
    role == UserRole.superAdmin ? 'super_admin' : 'agent';

String _sourceLabel(ChannelType source) {
  return switch (source) {
    ChannelType.facebook => 'Facebook',
    ChannelType.email => 'Email',
    ChannelType.web => 'Web',
  };
}

String _statusLabel(TicketStatus status) {
  return switch (status) {
    TicketStatus.inProgress => 'in progress',
    TicketStatus.pending => 'pending',
    TicketStatus.resolved => 'resolved',
    TicketStatus.open => 'open',
  };
}

String _timeAgo(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  return '${difference.inDays} day ago';
}
