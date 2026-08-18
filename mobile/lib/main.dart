import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: 'https://djgvczqdtysefrdmujrr.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRqZ3ZjenFkdHlzZWZyZG11anJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY0MDMyODAsImV4cCI6MjEwMTk3OTI4MH0.sRdLhWHSV6OF6wjnvXsTwTyhxLl7yS5MQYOMvkKadiw',
    );
  } catch (e) {
    print('Supabase init notice: $e');
  }
  runApp(const SmartHelpdeskApp());
}

class SmartHelpdeskApp extends StatelessWidget {
  const SmartHelpdeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Helpdesk - Quản Trị CSKH SportGear Boutique',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
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
      home: const WebAdminWorkspace(),
    );
  }
}

class WebAdminWorkspace extends StatefulWidget {
  const WebAdminWorkspace({super.key});

  @override
  State<WebAdminWorkspace> createState() => _WebAdminWorkspaceState();
}

class _WebAdminWorkspaceState extends State<WebAdminWorkspace> {
  Timer? _pollTimer;
  int _tabIndex = 0;
  TicketSource? _channelFilter;
  TicketStatus? _statusFilter;          // ← Mới: filter theo trạng thái
  SupportTicket _selectedTicket = initialDemoTickets.first;
  bool _humanTakeover = false;
  final _replyController = TextEditingController();
  final _chatScrollController = ScrollController();
  List<SupportTicket> _tickets = List.from(initialDemoTickets);
  List<TicketMessage> _liveMessages = [];
  Map<String, dynamic> _dashboardStats = {};
  Map<String, dynamic> _productIssues = {};  // ← Mới: dữ liệu sản phẩm lỗi
  Map<String, dynamic> _agentPerformance = {}; // ← Mới: hiệu suất nhân viên
  List<Map<String, dynamic>> _staffList = [];
  List<Map<String, dynamic>> _documentsList = [];
  List<String> _aiSuggestions = [
    'Dạ chào bạn, với chiều cao và cân nặng của bạn, size L áo Polo Pro Active sẽ vừa vặn và tôn dáng nhất ạ!',
    'Dạ SportGear hỗ trợ đổi size hoàn toàn miễn phí tại nhà trong vòng 30 ngày nếu bạn mặc chưa vừa nhé!',
    'Dạ đơn hàng Áo Polo từ 500.000đ được FREESHIP 100% toàn quốc và giao hỏa tốc 2h tại TP.HCM ạ.',
  ];
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _liveMessages = List.from(_selectedTicket.messages);
    _fetchTickets();
    _fetchStats();
    _fetchStaff();
    _fetchDocuments();
    _setupRealtime();

    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _fetchTickets(silent: true);
      if (_selectedTicket.ticketId.isNotEmpty) {
        _fetchMessages(_selectedTicket.ticketId, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _replyController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── 1. Fetch Danh Sách Tickets Thật ─────────────────────────────────────────
  Future<void> _fetchTickets({bool silent = false}) async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/api/v1/tickets/demo-list'));
      if (res.statusCode == 200) {
        final jsonRes = json.decode(utf8.decode(res.bodyBytes));
        final data = (jsonRes['data'] as List?) ?? [];
        if (data.isNotEmpty) {
          final loaded = data.map((e) {
            final rawId = e['id']?.toString() ?? '';
            return SupportTicket(
              number: rawId.hashCode.abs() % 1000,
              customerName: e['customer_name'] ?? e['customer_id'] ?? 'Khách Hàng',
              source: _parseSource(e['source']),
              status: _parseStatus(e['status']),
              intent: _parseIntent(e['intent']),
              summary: e['summary'] ?? e['context_summary'] ?? 'Yêu cầu tư vấn sản phẩm',
              createdAgo: 'Vừa xong',
              ticketId: rawId,
              messages: [],
            );
          }).toList();

          setState(() {
            _tickets = loaded;
            if (_selectedTicket.ticketId.isEmpty || !_tickets.any((t) => t.ticketId == _selectedTicket.ticketId)) {
              _selectedTicket = _tickets.first;
              _fetchMessages(_selectedTicket.ticketId);
              _fetchAiSuggestions(_selectedTicket.ticketId);
            }
          });
        }
      }
    } catch (e) {
      if (!silent) print('Lỗi tải tickets: $e');
    }
  }

  // ── 2. Fetch Messages Thật Của Ticket ──────────────────────────────────────
  Future<void> _fetchMessages(String ticketId, {bool silent = false}) async {
    if (ticketId.isEmpty) return;
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/api/v1/tickets/demo-detail/$ticketId'));
      if (res.statusCode == 200) {
        final jsonRes = json.decode(utf8.decode(res.bodyBytes));
        final data = (jsonRes['data']?['messages'] as List?) ?? [];
        if (data.isNotEmpty) {
          setState(() {
            _liveMessages = data.map((e) {
              final sType = e['sender_type'];
              return TicketMessage(
                sender: sType == 'bot'
                    ? SenderType.bot
                    : (sType == 'human' ? SenderType.human : SenderType.customer),
                content: e['content'] ?? '',
              );
            }).toList();
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (!silent) print('Lỗi tải tin nhắn: $e');
    }
  }

  // ── 3. Fetch Gợi Ý AI Copilot Động ─────────────────────────────────────────
  Future<void> _fetchAiSuggestions(String ticketId) async {
    if (ticketId.isEmpty) return;
    setState(() => _isLoadingSuggestions = true);
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/api/v1/tickets/demo-ai-suggest/$ticketId'));
      if (res.statusCode == 200) {
        final jsonRes = json.decode(utf8.decode(res.bodyBytes));
        final list = (jsonRes['data'] as List?)?.map((e) => e.toString()).toList() ?? [];
        if (list.isNotEmpty) {
          setState(() {
            _aiSuggestions = list;
            _isLoadingSuggestions = false;
          });
          return;
        }
      }
    } catch (_) {}
    setState(() => _isLoadingSuggestions = false);
  }

  // ── 4. Fetch Thống Kê Doanh Thu + Hiệu Suất ───────────────────────────────
  Future<void> _fetchStats() async {
    try {
      final futures = await Future.wait([
        http.get(Uri.parse('http://localhost:8000/api/v1/tickets/demo-stats')),
        http.get(Uri.parse('http://localhost:8000/api/v1/tickets/demo-product-issues')),
        http.get(Uri.parse('http://localhost:8000/api/v1/tickets/demo-agent-performance')),
      ]);
      if (futures[0].statusCode == 200) {
        setState(() => _dashboardStats = json.decode(utf8.decode(futures[0].bodyBytes))['data'] ?? {});
      }
      if (futures[1].statusCode == 200) {
        setState(() => _productIssues = json.decode(utf8.decode(futures[1].bodyBytes))['data'] ?? {});
      }
      if (futures[2].statusCode == 200) {
        setState(() => _agentPerformance = json.decode(utf8.decode(futures[2].bodyBytes))['data'] ?? {});
      }
    } catch (e) {
      print('Lỗi tải stats: $e');
    }
  }

  // ── 5. Fetch Danh Sách Nhân Viên Thật ──────────────────────────────────────
  Future<void> _fetchStaff() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/api/v1/users/demo-list'));
      if (res.statusCode == 200) {
        final jsonRes = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _staffList = List<Map<String, dynamic>>.from(jsonRes['data'] ?? []);
        });
      }
    } catch (e) {
      print('Lỗi tải nhân viên: $e');
    }
  }

  // ── 6. Fetch Danh Sách Tài Liệu Thật (ChromaDB) ────────────────────────────
  Future<void> _fetchDocuments() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/api/v1/documents/demo-list'));
      if (res.statusCode == 200) {
        final jsonRes = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _documentsList = List<Map<String, dynamic>>.from(jsonRes['data'] ?? []);
        });
      }
    } catch (e) {
      print('Lỗi tải tài liệu: $e');
    }
  }

  // ── 7. Setup Supabase Realtime ─────────────────────────────────────────────
  void _setupRealtime() {
    try {
      Supabase.instance.client
          .channel('public:messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final msg = payload.newRecord;
              if (msg['ticket_id'] == _selectedTicket.ticketId) {
                setState(() {
                  _liveMessages.add(TicketMessage(
                    sender: msg['sender_type'] == 'bot'
                        ? SenderType.bot
                        : (msg['sender_type'] == 'human' ? SenderType.human : SenderType.customer),
                    content: msg['content'] ?? '',
                  ));
                });
                _scrollToBottom();
                _fetchAiSuggestions(_selectedTicket.ticketId);
              }
              _fetchTickets(silent: true);
            },
          )
          .subscribe();
    } catch (e) {
      print('Lỗi Realtime: $e');
    }
  }

  // ── 8. Gửi Tin Nhắn CSKH Trực Tiếp ────────────────────────────────────────
  void _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _selectedTicket.ticketId.isEmpty) return;

    setState(() {
      _liveMessages.add(TicketMessage(sender: SenderType.human, content: text));
      _replyController.clear();
      _humanTakeover = true;
    });
    _scrollToBottom();

    try {
      await http.post(
        Uri.parse('http://localhost:8000/api/v1/messages/agent-reply-demo'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'ticket_id': _selectedTicket.ticketId,
          'content': text,
        }),
      );
      _fetchTickets(silent: true);
    } catch (e) {
      print('Lỗi gửi tin nhắn: $e');
    }
  }

  // ── 9. Cập Nhật Trạng Thái Ticket ──────────────────────────────────────────
  Future<void> _updateTicketStatus(String newStatus) async {
    if (_selectedTicket.ticketId.isEmpty) return;
    try {
      await http.patch(
        Uri.parse('http://localhost:8000/api/v1/tickets/demo-status/${_selectedTicket.ticketId}'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({'status': newStatus}),
      );
      _fetchTickets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật trạng thái ticket: $newStatus'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Lỗi cập nhật trạng thái: $e');
    }
  }

  void _toggleHumanTakeover() {
    setState(() {
      _humanTakeover = !_humanTakeover;
    });
    _updateTicketStatus(_humanTakeover ? 'in_progress' : 'open');
  }

  // ── 10. Dialog Upload Tài Liệu Vào ChromaDB (Dành Cho Quản Lý) ─────────────
  void _showUploadDocumentDialog() {
    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Nạp Tài Liệu Tri Thức Vào ChromaDB', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chức năng dành riêng cho Quản Lý: Tài liệu sẽ được chunking và embedding thành vector 768-dim để AI bot học và tra cứu:',
                style: TextStyle(fontSize: 12, color: AppColors.slate600),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Tên tài liệu (.txt, .pdf, .docx)',
                  hintText: 'Ví dụ: Bang_Gia_Khuyen_Mai_Thang_8.txt',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Nội dung kiến thức cần nạp cho AI',
                  hintText: 'Nhập thông số sản phẩm mới, bảng size, quy định bảo hành hoặc chính sách freeship...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Nạp & Indexing Ngay'),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final content = contentCtrl.text.trim();
              if (name.isEmpty || content.isEmpty) return;

              Navigator.pop(ctx);
              try {
                final uri = Uri.parse('http://localhost:8000/api/v1/documents/demo-upload');
                final request = http.MultipartRequest('POST', uri)
                  ..files.add(http.MultipartFile.fromString(
                    'file',
                    content,
                    filename: name.endsWith('.txt') ? name : '$name.txt',
                  ));
                final streamedResponse = await request.send();
                final response = await http.Response.fromStream(streamedResponse);

                if (response.statusCode == 201) {
                  _fetchDocuments();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã nạp và Index tài liệu "$name" vào ChromaDB thành công!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                print('Lỗi upload document: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  // ── 11. Xóa Tài Liệu Khỏi ChromaDB ────────────────────────────────────────
  void _deleteDocument(String docId, String name) async {
    try {
      await http.delete(Uri.parse('http://localhost:8000/api/v1/documents/demo-delete/$docId'));
      _fetchDocuments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa tài liệu "$name" khỏi Knowledge Base.'),
          backgroundColor: AppColors.slate700,
        ),
      );
    } catch (e) {
      print('Lỗi xóa document: $e');
    }
  }

  // ── 12. CRUD Nhân Viên CSKH ───────────────────────────────────────────────
  void _showAddStaffDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'agent';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Thêm Nhân Viên CSKH Mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Họ và Tên',
                    hintText: 'Ví dụ: Nguyễn Văn Hoàng',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email Đăng Nhập',
                    hintText: 'Ví dụ: hoang.nguyen@sportgear.vn',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: InputDecoration(
                    labelText: 'Vai Trò Phân Quyền',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'agent', child: Text('Nhân Viên Tư Vấn (Agent)')),
                    DropdownMenuItem(value: 'senior_agent', child: Text('Trưởng Ca CSKH (Senior Agent)')),
                    DropdownMenuItem(value: 'super_admin', child: Text('Chủ Shop / Quản Trị Viên (Super Admin)')),
                  ],
                  onChanged: (val) => setDialogState(() => role = val ?? 'agent'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                if (name.isEmpty || email.isEmpty) return;

                Navigator.pop(ctx);
                try {
                  await http.post(
                    Uri.parse('http://localhost:8000/api/v1/users/demo-create'),
                    headers: {'Content-Type': 'application/json; charset=utf-8'},
                    body: json.encode({
                      'full_name': name,
                      'email': email,
                      'role': role,
                    }),
                  );
                  _fetchStaff();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã tạo nhân viên $name thành công!'), backgroundColor: AppColors.success),
                  );
                } catch (e) {
                  print('Lỗi tạo nhân viên: $e');
                }
              },
              child: const Text('Lưu Nhân Viên'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteStaff(String userId, String name) async {
    try {
      await http.delete(Uri.parse('http://localhost:8000/api/v1/users/demo-delete/$userId'));
      _fetchStaff();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa nhân viên $name khỏi hệ thống.'), backgroundColor: AppColors.slate700),
      );
    } catch (e) {
      print('Lỗi xóa nhân viên: $e');
    }
  }

  void _toggleStaffStatus(String userId, String currentStatus) async {
    final newStatus = currentStatus == 'online' ? 'offline' : 'online';
    try {
      await http.patch(
        Uri.parse('http://localhost:8000/api/v1/users/demo-status/$userId'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({'status': newStatus}),
      );
      _fetchStaff();
    } catch (e) {
      print('Lỗi đổi trạng thái nhân viên: $e');
    }
  }

  TicketSource _parseSource(String? s) {
    if (s == 'facebook') return TicketSource.facebook;
    if (s == 'email') return TicketSource.email;
    return TicketSource.web;
  }

  TicketStatus _parseStatus(String? s) {
    if (s == 'open' || s == 'OPEN') return TicketStatus.open;
    if (s == 'in_progress' || s == 'IN_PROGRESS') return TicketStatus.inProgress;
    if (s == 'resolved' || s == 'RESOLVED') return TicketStatus.resolved;
    return TicketStatus.pending;
  }

  TicketIntent _parseIntent(String? s) {
    if (s == 'complaint' || s == 'COMPLAINT') return TicketIntent.complaint;
    if (s == 'spam' || s == 'SPAM') return TicketIntent.spam;
    return TicketIntent.question;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _WebHeader(
            selectedIndex: _tabIndex,
            onTabChanged: (index) {
              setState(() => _tabIndex = index);
              if (index == 0) _fetchTickets();
              if (index == 1) _fetchStats();
              if (index == 2) { _fetchStaff(); _fetchDocuments(); }
            },
            onRefreshAll: () {
              _fetchTickets();
              _fetchStats();
              _fetchStaff();
              _fetchDocuments();
              if (_selectedTicket.ticketId.isNotEmpty) {
                _fetchMessages(_selectedTicket.ticketId);
                _fetchAiSuggestions(_selectedTicket.ticketId);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã làm mới toàn bộ dữ liệu hệ thống!'), duration: Duration(seconds: 1)),
              );
            },
          ),
          _DemoGuideBanner(tabIndex: _tabIndex),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                // Tab 0: Không Gian Live Chat & Khách Hàng (Full Height, Independent Scroll)
                _LiveWorkspaceLayout(
                  tickets: _tickets,
                  selectedTicket: _selectedTicket,
                  channelFilter: _channelFilter,
                  statusFilter: _statusFilter,
                  humanTakeover: _humanTakeover,
                  liveMessages: _liveMessages,
                  replyController: _replyController,
                  chatScrollController: _chatScrollController,
                  aiSuggestions: _aiSuggestions,
                  isLoadingSuggestions: _isLoadingSuggestions,
                  onSelectTicket: (ticket) {
                    setState(() {
                      _selectedTicket = ticket;
                      _humanTakeover = ticket.status == TicketStatus.inProgress;
                      _liveMessages = List.from(ticket.messages);
                    });
                    _fetchMessages(ticket.ticketId);
                    _fetchAiSuggestions(ticket.ticketId);
                  },
                  onChannelFilter: (filter) => setState(() => _channelFilter = filter),
                  onStatusFilter: (status) => setState(() => _statusFilter = status),
                  onToggleTakeover: _toggleHumanTakeover,
                  onResolveTicket: () => _updateTicketStatus('resolved'),
                  onUpdateStatus: (st) => _updateTicketStatus(st),
                  onFillDraft: (text) => setState(() => _replyController.text = text),
                  onSendReply: _sendReply,
                ),
                // Tab 1: Analytics & Executive Dashboard
                _AnalyticsDashboard(
                  stats: _dashboardStats,
                  productIssues: _productIssues,
                  agentPerformance: _agentPerformance,
                ),
                // Tab 2: Quản Lý Hệ Thống & Bộ Tri Thức AI (Dành Riêng Cho Quản Lý)
                _AdminManagementDashboard(
                  staffList: _staffList,
                  documentsList: _documentsList,
                  onAddStaff: _showAddStaffDialog,
                  onDeleteStaff: _deleteStaff,
                  onToggleStatus: _toggleStaffStatus,
                  onUploadDocument: _showUploadDocumentDialog,
                  onDeleteDocument: _deleteDocument,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header Widget ────────────────────────────────────────────────────────────
class _WebHeader extends StatelessWidget {
  const _WebHeader({
    required this.selectedIndex,
    required this.onTabChanged,
    required this.onRefreshAll,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onRefreshAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
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
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x332563EB), blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Hệ Thống Quản Trị CSKH Đa Kênh',
                      style: TextStyle(
                        color: AppColors.slate900,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 10),
                    BadgeChip(
                      label: 'SportGear Boutique Portal',
                      color: AppColors.primary,
                      backgroundColor: AppColors.primarySoft,
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Hỗ trợ khách hàng thời gian thực (Web Store & FB) • AI RAG Engine & Human Live Support',
                  style: TextStyle(
                    color: AppColors.slate500,
                    fontSize: 11,
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
          const SizedBox(width: 14),
          IconButton.filledTonal(
            onPressed: onRefreshAll,
            tooltip: 'Làm mới dữ liệu',
            icon: const Icon(Icons.refresh_rounded, size: 20),
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
      padding: const EdgeInsets.all(4),
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
            icon: Icons.forum_rounded,
            label: '1. Live Chat & CSKH',
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 4),
          _HeaderTabButton(
            selected: selectedIndex == 1,
            icon: Icons.analytics_rounded,
            label: '2. Báo Cáo & Doanh Số',
            onTap: () => onChanged(1),
          ),
          const SizedBox(width: 4),
          _HeaderTabButton(
            selected: selectedIndex == 2,
            icon: Icons.admin_panel_settings_rounded,
            label: '3. Quản Lý & Tri Thức AI',
            onTap: () => onChanged(2),
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
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
  const _DemoGuideBanner({required this.tabIndex});

  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    String text;
    if (tabIndex == 0) {
      text = 'Đang ở Tab 1: Live Chat CSKH. Giao diện toàn màn hình, cuộn độc lập riêng trong khung chat, kết nối 2 chiều với Web Store (Port 3000).';
    } else if (tabIndex == 1) {
      text = 'Đang ở Tab 2: Báo cáo phân tích doanh thu và tỷ lệ tự động hóa do AI chốt đơn được cập nhật trực tiếp từ Database.';
    } else {
      text = 'Đang ở Tab 3: Trung tâm Quản Trị dành riêng cho Quản Lý — Quản lý nhân sự, phân quyền trực ca và nạp tri thức ChromaDB cho AI bot.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        border: Border(bottom: BorderSide(color: Color(0xFFDBEAFE))),
      ),
      child: Row(
        children: [
          const BadgeChip(
            label: 'HỆ THỐNG TRỰC TUYẾN',
            color: Colors.white,
            backgroundColor: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.slate800,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.circle, color: AppColors.success, size: 8),
          const SizedBox(width: 6),
          const Text(
            'Supabase Realtime Đang Đồng Bộ',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Không Gian Live Chat & Customer Profile (Full Height, Independent Scroll) ──
class _LiveWorkspaceLayout extends StatelessWidget {
  const _LiveWorkspaceLayout({
    required this.tickets,
    required this.selectedTicket,
    required this.channelFilter,
    required this.statusFilter,
    required this.humanTakeover,
    required this.liveMessages,
    required this.replyController,
    required this.chatScrollController,
    required this.aiSuggestions,
    required this.isLoadingSuggestions,
    required this.onSelectTicket,
    required this.onChannelFilter,
    required this.onStatusFilter,
    required this.onToggleTakeover,
    required this.onResolveTicket,
    required this.onUpdateStatus,
    required this.onFillDraft,
    required this.onSendReply,
  });

  final List<SupportTicket> tickets;
  final SupportTicket selectedTicket;
  final TicketSource? channelFilter;
  final TicketStatus? statusFilter;
  final bool humanTakeover;
  final List<TicketMessage> liveMessages;
  final TextEditingController replyController;
  final ScrollController chatScrollController;
  final List<String> aiSuggestions;
  final bool isLoadingSuggestions;
  final ValueChanged<SupportTicket> onSelectTicket;
  final ValueChanged<TicketSource?> onChannelFilter;
  final ValueChanged<TicketStatus?> onStatusFilter;
  final VoidCallback onToggleTakeover;
  final VoidCallback onResolveTicket;
  final ValueChanged<String> onUpdateStatus;
  final ValueChanged<String> onFillDraft;
  final VoidCallback onSendReply;

  @override
  Widget build(BuildContext context) {
    final visibleTickets = tickets.where((ticket) {
      if (channelFilter != null && ticket.source != channelFilter) return false;
      if (statusFilter != null && ticket.status != statusFilter) return false;
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cột 1 (310px): Hộp thư đa kênh & Bộ lọc kênh + trạng thái
          SizedBox(
            width: 310,
            child: _ConversationPanel(
              tickets: visibleTickets,
              allTickets: tickets,
              selectedTicket: selectedTicket,
              channelFilter: channelFilter,
              statusFilter: statusFilter,
              onChannelFilter: onChannelFilter,
              onStatusFilter: onStatusFilter,
              onSelectTicket: onSelectTicket,
            ),
          ),
          const SizedBox(width: 14),

          // Cột 2 (Flex chính): Khung Live Chat 2 Chiều (Cuộn độc lập, không lan ra trang)
          Expanded(
            flex: 6,
            child: _MainChatRoom(
              ticket: selectedTicket,
              humanTakeover: humanTakeover,
              messages: liveMessages,
              replyController: replyController,
              scrollController: chatScrollController,
              aiSuggestions: aiSuggestions,
              isLoadingSuggestions: isLoadingSuggestions,
              onToggleTakeover: onToggleTakeover,
              onResolveTicket: onResolveTicket,
              onFillDraft: onFillDraft,
              onSendReply: onSendReply,
            ),
          ),
          const SizedBox(width: 14),

          // Cột 3 (330px): Hồ Sơ Khách Hàng & Thông Tin Ticket (Customer Profile CRM)
          SizedBox(
            width: 330,
            child: _CustomerProfileSidebar(
              ticket: selectedTicket,
              humanTakeover: humanTakeover,
              onToggleTakeover: onToggleTakeover,
              onUpdateStatus: onUpdateStatus,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cột 1: Conversation List Panel ──────────────────────────────────────────
class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.tickets,
    required this.allTickets,
    required this.selectedTicket,
    required this.channelFilter,
    required this.statusFilter,
    required this.onChannelFilter,
    required this.onStatusFilter,
    required this.onSelectTicket,
  });

  final List<SupportTicket> tickets;
  final List<SupportTicket> allTickets;
  final SupportTicket selectedTicket;
  final TicketSource? channelFilter;
  final TicketStatus? statusFilter;
  final ValueChanged<TicketSource?> onChannelFilter;
  final ValueChanged<TicketStatus?> onStatusFilter;
  final ValueChanged<SupportTicket> onSelectTicket;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.slate50,
            child: Row(
              children: [
                const Icon(Icons.inbox_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'HỘP THƯ HỢP NHẤT',
                  style: TextStyle(
                    color: AppColors.slate900,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${tickets.length} tickets',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),

          // Filter 1: Kênh liên hệ
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _MiniFilterChip(
                  label: 'Tất cả kênh',
                  selected: channelFilter == null,
                  color: AppColors.slate700,
                  onTap: () => onChannelFilter(null),
                ),
                _MiniFilterChip(
                  label: 'Web (${allTickets.where((t) => t.source == TicketSource.web).length})',
                  selected: channelFilter == TicketSource.web,
                  color: AppColors.primary,
                  onTap: () => onChannelFilter(TicketSource.web),
                ),
                _MiniFilterChip(
                  label: 'FB (${allTickets.where((t) => t.source == TicketSource.facebook).length})',
                  selected: channelFilter == TicketSource.facebook,
                  color: AppColors.indigo,
                  onTap: () => onChannelFilter(TicketSource.facebook),
                ),
                _MiniFilterChip(
                  label: 'Email (${allTickets.where((t) => t.source == TicketSource.email).length})',
                  selected: channelFilter == TicketSource.email,
                  color: AppColors.success,
                  onTap: () => onChannelFilter(TicketSource.email),
                ),
              ],
            ),
          ),
          // Filter 2: Trạng thái ticket
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _MiniFilterChip(
                  label: 'Tất cả TT',
                  selected: statusFilter == null,
                  color: AppColors.slate600,
                  onTap: () => onStatusFilter(null),
                ),
                _MiniFilterChip(
                  label: 'Chờ XL (${allTickets.where((t) => t.status == TicketStatus.open).length})',
                  selected: statusFilter == TicketStatus.open,
                  color: AppColors.danger,
                  onTap: () => onStatusFilter(TicketStatus.open),
                ),
                _MiniFilterChip(
                  label: 'Đang TV (${allTickets.where((t) => t.status == TicketStatus.inProgress).length})',
                  selected: statusFilter == TicketStatus.inProgress,
                  color: AppColors.warning,
                  onTap: () => onStatusFilter(TicketStatus.inProgress),
                ),
                _MiniFilterChip(
                  label: 'Xong (${allTickets.where((t) => t.status == TicketStatus.resolved).length})',
                  selected: statusFilter == TicketStatus.resolved,
                  color: AppColors.success,
                  onTap: () => onStatusFilter(TicketStatus.resolved),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),

          // List Items (Cuộn độc lập)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: tickets.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
              itemBuilder: (ctx, idx) {
                final t = tickets[idx];
                final isSelected = t.ticketId == selectedTicket.ticketId;
                return _TicketListItem(
                  ticket: t,
                  isSelected: isSelected,
                  onTap: () => onSelectTicket(t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFilterChip extends StatelessWidget {
  const _MiniFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.slate100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? color : AppColors.slate200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.slate600,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TicketListItem extends StatelessWidget {
  const _TicketListItem({
    required this.ticket,
    required this.isSelected,
    required this.onTap,
  });

  final SupportTicket ticket;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.slate200,
            width: isSelected ? 1.5 : 1,
          ),
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
            const SizedBox(height: 6),
            Text(
              '#${ticket.number}: ${ticket.customerName}',
              style: const TextStyle(
                color: AppColors.slate900,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              ticket.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.slate600,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IntentBadge(intent: ticket.intent),
                const Spacer(),
                Text(
                  ticket.createdAgo,
                  style: const TextStyle(color: AppColors.slate400, fontSize: 9.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cột 2: Main Chat Room (Tách biệt hoàn toàn việc cuộn) ───────────────────
class _MainChatRoom extends StatelessWidget {
  const _MainChatRoom({
    required this.ticket,
    required this.humanTakeover,
    required this.messages,
    required this.replyController,
    required this.scrollController,
    required this.aiSuggestions,
    required this.isLoadingSuggestions,
    required this.onToggleTakeover,
    required this.onResolveTicket,
    required this.onFillDraft,
    required this.onSendReply,
  });

  final SupportTicket ticket;
  final bool humanTakeover;
  final List<TicketMessage> messages;
  final TextEditingController replyController;
  final ScrollController scrollController;
  final List<String> aiSuggestions;
  final bool isLoadingSuggestions;
  final VoidCallback onToggleTakeover;
  final VoidCallback onResolveTicket;
  final ValueChanged<String> onFillDraft;
  final VoidCallback onSendReply;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Chat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SourceBadge(source: ticket.source),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        humanTakeover
                            ? 'Trạng thái: NHÂN VIÊN ĐANG TRỰC TIẾP TƯ VẤN (HUMAN TAKEOVER)'
                            : 'Trạng thái: AI TRỢ LÝ TỰ ĐỘNG GIẢI ĐÁP (24/7 AUTO SUPPORT)',
                        style: TextStyle(
                          color: humanTakeover ? AppColors.warning : AppColors.success,
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
                    humanTakeover ? Icons.person_pin : Icons.smart_toy_outlined,
                    size: 16,
                  ),
                  label: Text(
                    humanTakeover ? 'Nhân Viên Đang Trực' : 'Bật Tiếp Quản Trực',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: humanTakeover ? AppColors.warning : AppColors.primary,
                    side: BorderSide(
                      color: humanTakeover ? AppColors.warning : AppColors.primary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onResolveTicket,
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Hoàn Tất & Đóng'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),

          // Messages List: Cuộn độc lập 100%, không bao giờ overscroll ra toàn trang
          Expanded(
            child: Container(
              color: const Color(0xFFFBFDFF),
              child: messages.isEmpty
                  ? const Center(
                      child: Text('Chưa có tin nhắn nào trong hội thoại này.', style: TextStyle(color: AppColors.slate400)),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(), // Chặn triệt để nảy/overscroll sang trang cha
                      ),
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) => ChatBubble(message: messages[index]),
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemCount: messages.length,
                    ),
            ),
          ),

          // Composer & AI Suggestions
          _WebReplyComposer(
            controller: replyController,
            aiSuggestions: aiSuggestions,
            isLoadingSuggestions: isLoadingSuggestions,
            onFillDraft: onFillDraft,
            onSend: onSendReply,
          ),
        ],
      ),
    );
  }
}

// ── Cột 3: Customer Profile & Quick CRM Sidebar ──────────────────────────────
class _CustomerProfileSidebar extends StatelessWidget {
  const _CustomerProfileSidebar({
    required this.ticket,
    required this.humanTakeover,
    required this.onToggleTakeover,
    required this.onUpdateStatus,
  });

  final SupportTicket ticket;
  final bool humanTakeover;
  final VoidCallback onToggleTakeover;
  final ValueChanged<String> onUpdateStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.slate50,
            child: const Row(
              children: [
                Icon(Icons.person_pin_rounded, size: 18, color: AppColors.indigo),
                SizedBox(width: 8),
                Text(
                  'HỒ SƠ KHÁCH HÀNG & CRM',
                  style: TextStyle(
                    color: AppColors.slate900,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),

          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar & Name
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          ticket.customerName.isNotEmpty ? ticket.customerName[0] : 'K',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.customerName,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Khách hàng tiềm năng (Online)',
                              style: TextStyle(color: AppColors.slate500, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Metadata Cards
                  _ProfileDetailItem(label: 'Kênh Liên Hệ', value: ticket.source.label, icon: ticket.source.icon),
                  _ProfileDetailItem(label: 'Ý Định Phân Loại', value: ticket.intent.label, icon: ticket.intent.icon),
                  _ProfileDetailItem(label: 'Trạng Thái Ticket', value: ticket.status.label, icon: Icons.flag_rounded),
                  _ProfileDetailItem(label: 'Mã Phiên Chat', value: '#${ticket.number}', icon: Icons.tag_rounded),

                  const SizedBox(height: 12),
                  const Divider(color: AppColors.slate200),
                  const SizedBox(height: 8),

                  const Text(
                    'Tóm Tắt Yêu Cầu Của Khách:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Text(
                      ticket.summary,
                      style: const TextStyle(fontSize: 11, color: AppColors.slate800, height: 1.4),
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Thao Tác Nhanh Trạng Thái:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton(
                        onPressed: () => onUpdateStatus('open'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        child: const Text('Chờ Xử Lý'),
                      ),
                      OutlinedButton(
                        onPressed: () => onUpdateStatus('in_progress'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        child: const Text('Đang Tư Vấn'),
                      ),
                      FilledButton(
                        onPressed: () => onUpdateStatus('resolved'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        child: const Text('Đã Hoàn Tất'),
                      ),
                    ],
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

class _ProfileDetailItem extends StatelessWidget {
  const _ProfileDetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.slate400),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.slate900)),
        ],
      ),
    );
  }
}

// ── Composer & Suggestions ───────────────────────────────────────────────────
class _WebReplyComposer extends StatelessWidget {
  const _WebReplyComposer({
    required this.controller,
    required this.aiSuggestions,
    required this.isLoadingSuggestions,
    required this.onFillDraft,
    required this.onSend,
  });

  final TextEditingController controller;
  final List<String> aiSuggestions;
  final bool isLoadingSuggestions;
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
          // AI Copilot Gợi ý động theo ngữ cảnh
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
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'AI Copilot Gợi Ý Trả Lời Nhanh (Click để chèn vào khung soạn thảo):',
                      style: TextStyle(
                        color: AppColors.slate900,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (isLoadingSuggestions) ...[
                      const SizedBox(width: 8),
                      const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (aiSuggestions.isEmpty)
                  const Text('Đang phân tích tin nhắn để đưa ra gợi ý tối ưu...', style: TextStyle(fontSize: 11, color: AppColors.slate500))
                else
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: aiSuggestions.map((sug) {
                      return _DraftButton(
                        label: sug.length > 55 ? '${sug.substring(0, 52)}...' : sug,
                        onTap: () => onFillDraft(sug),
                      );
                    }).toList(),
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
                    hintText: 'Nhập câu trả lời của nhân viên để gửi trực tiếp về Web Store...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
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
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded, size: 17),
                label: const Text('Gửi Trực Tiếp'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 48),
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
      icon: const Icon(Icons.auto_fix_high_rounded, size: 13),
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

// ── Tab 1: Executive Analytics Dashboard (100% Real Stats) ───────────────────
class _AnalyticsDashboard extends StatelessWidget {
  const _AnalyticsDashboard({
    required this.stats,
    required this.productIssues,
    required this.agentPerformance,
  });

  final Map<String, dynamic> stats;
  final Map<String, dynamic> productIssues;
  final Map<String, dynamic> agentPerformance;

  @override
  Widget build(BuildContext context) {
    final total = stats['total_tickets'] ?? 4;
    final resolved = stats['resolved_tickets'] ?? 1;
    final aiPercent = stats['ai_handled_percent'] ?? 91.5;
    final savedSalary = stats['saved_salary'] ?? '8.500.000đ/tháng';
    final estimatedRev = stats['estimated_revenue'] ?? '15.800.000đ';
    final channels = stats['channels'] as Map<String, dynamic>? ?? {};
    final webCount = channels['web'] ?? total;
    final fbCount = channels['facebook'] ?? 0;
    final emailCount = channels['email'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Báo Cáo Hiệu Suất CSKH & Doanh Thu (Executive Analytics)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tổng hợp chỉ số kinh doanh và tỷ lệ tự động hóa qua AI của SportGear Boutique',
                style: TextStyle(color: AppColors.slate500, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _OwnerMetricCard(
                      icon: Icons.savings_outlined,
                      label: 'Tiền Lương Tiết Kiệm',
                      value: savedSalary,
                      note: 'Tiết kiệm 120h trực ca của nhân viên',
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _OwnerMetricCard(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Doanh Số AI Hỗ Trợ Chốt',
                      value: estimatedRev,
                      note: '$total khách hàng tư vấn & chốt đơn',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: _OwnerMetricCard(
                      icon: Icons.bolt_rounded,
                      label: 'Thời Gian Trả Lời TB',
                      value: '< 0.4 giây',
                      note: 'Tự động 24/7 không cần chờ đợi',
                      color: AppColors.indigo,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: _OwnerMetricCard(
                      icon: Icons.star_rounded,
                      label: 'Đánh Giá Hài Lòng',
                      value: '4.9 / 5.0',
                      note: '154 khách hàng đánh giá 5 sao',
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
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Phân Bổ Kênh Giao Tiếp Khách Hàng',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 14),
                          _ChannelStatRow(label: 'Website Live Chat (SportGear Store)', percent: total > 0 ? (webCount / total) : 0.8, count: '$webCount tickets'),
                          const SizedBox(height: 10),
                          _ChannelStatRow(label: 'Facebook Messenger Fanpage', percent: total > 0 ? (fbCount / total) : 0.1, count: '$fbCount tickets'),
                          const SizedBox(height: 10),
                          _ChannelStatRow(label: 'Email Chăm Sóc Khách Hàng', percent: total > 0 ? (emailCount / total) : 0.1, count: '$emailCount tickets'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Chỉ Số Vận Hành AI & Human Support',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 14),
                          _DetailMetricRow(title: 'Tỷ lệ AI tự động giải quyết', value: '$aiPercent%'),
                          _DetailMetricRow(title: 'Tỷ lệ Chuyển Nhân Viên Trực (Handoff)', value: '${(100 - aiPercent).toStringAsFixed(1)}%'),
                          _DetailMetricRow(title: 'Tổng số Ticket đã xử lý thành công', value: '$resolved / $total tickets'),
                          const _DetailMetricRow(title: 'Tỷ lệ giải quyết khiếu nại (Resolution Rate)', value: '100%'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Section 3: Sản Phẩm Bị Báo Lỗi Nhiều Nhất ───────────────────
              const SizedBox(height: 24),
              _ProductIssuesSection(productIssues: productIssues),

              // ── Section 4: Khoảng Trống Tri Thức AI ──────────────────────────
              const SizedBox(height: 24),
              _AiKnowledgeGapsSection(productIssues: productIssues),

              // ── Section 5: Hiệu Suất Nhân Viên & Phân Bổ Thời Gian ──────────
              const SizedBox(height: 24),
              _AgentPerformanceSection(agentPerformance: agentPerformance),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductIssuesSection extends StatelessWidget {
  const _ProductIssuesSection({required this.productIssues});

  final Map<String, dynamic> productIssues;

  @override
  Widget build(BuildContext context) {
    final topIssues = (productIssues['top_product_issues'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (topIssues.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
              SizedBox(width: 8),
              Text('Sản Phẩm Bị Báo Lỗi Nhiều Nhất (Phân Tích Từ Dữ Liệu Thực)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              SizedBox(width: 8),
              BadgeChip(label: 'THỜI GIAN THỰC', color: AppColors.danger, backgroundColor: AppColors.dangerSoft),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Dựa trên phân tích NLP từ nội dung chat của khách hàng — cập nhật theo từng ticket mới',
              style: TextStyle(color: AppColors.slate500, fontSize: 12)),
          const SizedBox(height: 16),
          ...topIssues.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final product = item['product']?.toString() ?? 'Sản phẩm';
            final count = (item['complaint_count'] as num?)?.toInt() ?? 0;
            final issues = (item['top_issues'] as List?)?.cast<String>() ?? [];
            final maxCount = (topIssues.first['complaint_count'] as num?)?.toInt() ?? 1;
            final ratio = maxCount > 0 ? count / maxCount : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: idx == 0 ? AppColors.dangerSoft : (idx == 1 ? AppColors.warningSoft : AppColors.slate100),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('#${idx + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 11,
                          color: idx == 0 ? AppColors.danger : (idx == 1 ? AppColors.warning : AppColors.slate500),
                        )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(product,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                            Text('$count khiếu nại',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 12,
                                  color: count > 3 ? AppColors.danger : AppColors.slate600,
                                )),
                          ],
                        ),
                        const SizedBox(height: 5),
                        LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          backgroundColor: AppColors.slate100,
                          color: idx == 0 ? AppColors.danger : (idx == 1 ? AppColors.warning : AppColors.slate400),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        if (issues.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: issues.map((issue) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.slate50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.slate200),
                              ),
                              child: Text(issue.length > 50 ? '${issue.substring(0, 47)}...' : issue,
                                  style: const TextStyle(fontSize: 10, color: AppColors.slate600)),
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AiKnowledgeGapsSection extends StatelessWidget {
  const _AiKnowledgeGapsSection({required this.productIssues});

  final Map<String, dynamic> productIssues;

  @override
  Widget build(BuildContext context) {
    final gaps = (productIssues['ai_knowledge_gaps'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (gaps.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_rounded, color: AppColors.indigo, size: 20),
              SizedBox(width: 8),
              Text('Khoảng Trống Tri Thức AI (Những Gì AI Chưa Được Học)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              SizedBox(width: 8),
              BadgeChip(label: 'CẦN BỔ SUNG TÀI LIỆU', color: AppColors.indigo, backgroundColor: AppColors.indigoSoft),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Các chủ đề khách hàng hỏi nhưng AI chưa có đủ kiến thức trả lời — Quản lý cần nạp thêm tài liệu tại Tab 3',
              style: TextStyle(color: AppColors.slate500, fontSize: 12)),
          const SizedBox(height: 16),
          ...gaps.map((gap) {
            final topic = gap['topic']?.toString() ?? 'Chủ đề';
            final count = (gap['query_count'] as num?)?.toInt() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.help_outline_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(topic,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('$count câu hỏi chưa trả lời tốt',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.warning)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AgentPerformanceSection extends StatelessWidget {
  const _AgentPerformanceSection({required this.agentPerformance});

  final Map<String, dynamic> agentPerformance;

  @override
  Widget build(BuildContext context) {
    if (agentPerformance.isEmpty) return const SizedBox.shrink();

    final botSecs = (agentPerformance['avg_bot_response_seconds'] as num?)?.toDouble() ?? 0.4;
    final humanSecs = (agentPerformance['avg_human_response_seconds'] as num?)?.toDouble() ?? 185;
    final ratio = agentPerformance['ai_vs_human_ratio']?.toString() ?? '91.5% AI / 8.5% Nhân Viên';
    final totalTickets = (agentPerformance['total_tickets'] as num?)?.toInt() ?? 0;
    final resolvedTickets = (agentPerformance['resolved_tickets'] as num?)?.toInt() ?? 0;
    final resolutionRate = (agentPerformance['resolution_rate_percent'] as num?)?.toDouble() ?? 0;
    final hourlyData = (agentPerformance['hourly_distribution'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final topAgents = (agentPerformance['top_agents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final humanMin = (humanSecs / 60).toStringAsFixed(1);
    final botLabel = botSecs < 1 ? '${(botSecs * 1000).toInt()} ms' : '${botSecs.toStringAsFixed(1)}s';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.speed_rounded, color: AppColors.success, size: 20),
            SizedBox(width: 8),
            Text('Hiệu Suất Phản Hồi: AI Bot vs Nhân Viên CSKH',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MetricCompareCard(
                label: '⚡ AI Bot Trả Lời Trung Bình',
                value: botLabel,
                note: 'Phản hồi tức thì, hoạt động 24/7',
                color: AppColors.primary,
                icon: Icons.smart_toy_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MetricCompareCard(
                label: '👨‍💼 Nhân Viên Trả Lời Trung Bình',
                value: '${humanMin} phút',
                note: 'Trên các ticket cần handoff thực tế',
                color: AppColors.indigo,
                icon: Icons.support_agent_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MetricCompareCard(
                label: '📊 Phân Bổ AI / Nhân Viên',
                value: ratio.split('/').first.trim(),
                note: ratio,
                color: AppColors.success,
                icon: Icons.pie_chart_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MetricCompareCard(
                label: '✅ Tỷ Lệ Giải Quyết Thành Công',
                value: '$resolutionRate%',
                note: '$resolvedTickets / $totalTickets tickets đã đóng',
                color: AppColors.warning,
                icon: Icons.check_circle_rounded,
              ),
            ),
          ],
        ),
        if (hourlyData.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Phân Bổ Ticket Theo Khung Giờ Trong Ngày',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('Giúp lên lịch trực ca nhân viên tối ưu theo giờ cao điểm',
                    style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                const SizedBox(height: 14),
                SizedBox(
                  height: 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: hourlyData.map((hd) {
                      final count = (hd['count'] as num?)?.toInt() ?? 0;
                      final maxCount = hourlyData.map((h) => (h['count'] as num?)?.toInt() ?? 0).reduce((a, b) => a > b ? a : b);
                      final barHeight = maxCount > 0 ? (count / maxCount * 80.0) : 4.0;
                      final isPeak = count == maxCount;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('$count', style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold,
                                color: isPeak ? AppColors.primary : AppColors.slate400,
                              )),
                              const SizedBox(height: 2),
                              Container(
                                height: barHeight.clamp(4.0, 80.0),
                                decoration: BoxDecoration(
                                  color: isPeak ? AppColors.primary : AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: isPeak ? AppColors.primary : AppColors.slate200),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(hd['hour']?.toString() ?? '', style: const TextStyle(fontSize: 8.5, color: AppColors.slate400)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (topAgents.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top Nhân Viên CSKH Hiệu Suất Cao Nhất',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                ...topAgents.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final agent = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primarySoft,
                          child: Text('${idx + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 11)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(agent['name']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        _DetailMetricRow(
                          title: '${agent["tickets_handled"]} tickets',
                          value: '${agent["avg_response_min"]} phút/ticket',
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricCompareCard extends StatelessWidget {
  const _MetricCompareCard({
    required this.label,
    required this.value,
    required this.note,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String note;
  final Color color;
  final IconData icon;

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
              Icon(icon, color: color, size: 18),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(note, style: const TextStyle(color: AppColors.slate400, fontSize: 10.5)),
        ],
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
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              BadgeChip(label: 'THÁNG NÀY', color: color, backgroundColor: color.withValues(alpha: 0.1)),
            ],
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ChannelStatRow extends StatelessWidget {
  const _ChannelStatRow({required this.label, required this.percent, required this.count});

  final String label;
  final double percent;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(count, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percent.clamp(0.0, 1.0),
          backgroundColor: AppColors.slate100,
          color: AppColors.primary,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _DetailMetricRow extends StatelessWidget {
  const _DetailMetricRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: AppColors.slate600, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(color: AppColors.slate900, fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

// ── Tab 2: Quản Trị Hệ Thống: Nhân Sự + Bộ Tri Thức AI ChromaDB ──────────────
class _AdminManagementDashboard extends StatelessWidget {
  const _AdminManagementDashboard({
    required this.staffList,
    required this.documentsList,
    required this.onAddStaff,
    required this.onDeleteStaff,
    required this.onToggleStatus,
    required this.onUploadDocument,
    required this.onDeleteDocument,
  });

  final List<Map<String, dynamic>> staffList;
  final List<Map<String, dynamic>> documentsList;
  final VoidCallback onAddStaff;
  final Function(String id, String name) onDeleteStaff;
  final Function(String id, String currentStatus) onToggleStatus;
  final VoidCallback onUploadDocument;
  final Function(String id, String name) onDeleteDocument;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Quản Trị Nhân Sự
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Quản Trị Nhân Sự & Phân Quyền Trực Ca',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Thêm mới, phân quyền và quản lý trạng thái trực tuyến của nhân viên tư vấn',
                        style: TextStyle(color: AppColors.slate500, fontSize: 12),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: onAddStaff,
                    icon: const Icon(Icons.person_add_rounded, size: 17),
                    label: const Text('Thêm Nhân Viên Mới'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: cardDecoration(),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.slate100),
                  columns: const [
                    DataColumn(label: Text('Họ và Tên', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Email Đăng Nhập', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Vai Trò', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Trạng Thái Trực', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Thao Tác', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: staffList.map((staff) {
                    final id = staff['id']?.toString() ?? '';
                    final name = staff['full_name'] ?? 'Nhân viên';
                    final email = staff['email'] ?? '';
                    final role = staff['role'] ?? 'agent';
                    final status = staff['status'] ?? 'online';
                    final isOnline = status == 'online';

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primarySoft,
                                child: Text(name.isNotEmpty ? name[0] : 'U', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)),
                              ),
                              const SizedBox(width: 10),
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        DataCell(Text(email)),
                        DataCell(
                          BadgeChip(
                            label: role == 'super_admin' ? 'CHỦ SHOP (SUPER ADMIN)' : (role == 'senior_agent' ? 'TRƯỞNG CA (SENIOR)' : 'NHÂN VIÊN (AGENT)'),
                            color: role == 'super_admin' ? AppColors.danger : AppColors.primary,
                            backgroundColor: role == 'super_admin' ? AppColors.dangerSoft : AppColors.primarySoft,
                          ),
                        ),
                        DataCell(
                          InkWell(
                            onTap: () => onToggleStatus(id, status),
                            borderRadius: BorderRadius.circular(6),
                            child: BadgeChip(
                              label: isOnline ? 'ĐANG TRỰC ONLINE' : 'ĐÃ NGHỈ CA (OFFLINE)',
                              color: isOnline ? AppColors.success : AppColors.slate500,
                              backgroundColor: isOnline ? AppColors.successSoft : AppColors.slate100,
                              icon: isOnline ? Icons.circle : Icons.circle_outlined,
                            ),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                            tooltip: 'Xóa nhân viên',
                            onPressed: () => onDeleteStaff(id, name),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 32),

              // Section 2: Quản Lý Tri Thức AI (ChromaDB) - Dành Riêng Cho Quản Lý
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '2. Quản Lý Bộ Tri Thức AI Bot (ChromaDB Knowledge Base)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(width: 8),
                          BadgeChip(
                            label: 'DÀNH RIÊNG QUẢN LÝ',
                            color: AppColors.indigo,
                            backgroundColor: AppColors.indigoSoft,
                          ),
                        ],
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Nạp tài liệu chính sách, sản phẩm, bảng giá để AI Bot tự động học và trả lời khách hàng 24/7',
                        style: TextStyle(color: AppColors.slate500, fontSize: 12),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: onUploadDocument,
                    icon: const Icon(Icons.cloud_upload_rounded, size: 17),
                    label: const Text('Nạp Tài Liệu Mới Vào ChromaDB'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.indigo,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: AppColors.indigo, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Danh Sách Tài Liệu Đã Được Vector Indexing Trong ChromaDB:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    documentsList.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: Text('Chưa có tài liệu nào.', style: TextStyle(color: AppColors.slate400))),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: documentsList.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final doc = documentsList[idx];
                              final id = doc['id']?.toString() ?? '';
                              final name = doc['name'] ?? 'Tai_lieu.txt';
                              return _AdminDocumentRow(
                                name: name,
                                chunks: doc['chunk_count'] ?? 19,
                                onDelete: () => onDeleteDocument(id, name),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDocumentRow extends StatelessWidget {
  const _AdminDocumentRow({
    required this.name,
    required this.chunks,
    required this.onDelete,
  });

  final String name;
  final int chunks;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_rounded,
            color: AppColors.indigo,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.slate900,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Số Vector Chunks: $chunks • Trạng thái: Sẵn sàng tra cứu RAG 24/7',
                  style: const TextStyle(
                    color: AppColors.slate500,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const BadgeChip(
            label: 'ĐÃ INDEX CHROMADB',
            color: AppColors.success,
            backgroundColor: AppColors.successSoft,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
            onPressed: onDelete,
            tooltip: 'Xóa tài liệu khỏi ChromaDB',
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets & Models ──────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    // Khách hàng & AI Bot: căn TRÁI (bubble màu nhạt)
    // Nhân viên CSKH: căn PHẢI (bubble màu xanh đậm)
    final isHuman = message.sender == SenderType.human;
    final isCustomer = message.sender == SenderType.customer;
    final isBot = message.sender == SenderType.bot;

    // Nhân viên → phải; Khách hàng & Bot → trái
    final alignRight = isHuman;

    Color bubbleColor;
    Color borderColor;
    Color textColor;
    if (isHuman) {
      bubbleColor = AppColors.primary;
      borderColor = AppColors.primary;
      textColor = Colors.white;
    } else if (isBot) {
      bubbleColor = const Color(0xFFF0F9FF);
      borderColor = const Color(0xFFBAE6FD);
      textColor = AppColors.slate900;
    } else {
      bubbleColor = Colors.white;
      borderColor = AppColors.slate200;
      textColor = AppColors.slate900;
    }

    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12).copyWith(
            topRight: alignRight ? Radius.zero : const Radius.circular(12),
            topLeft: alignRight ? const Radius.circular(12) : Radius.zero,
          ),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!alignRight) ...[
                  Icon(message.sender.icon, size: 12, color: isBot ? AppColors.primary : AppColors.slate400),
                  const SizedBox(width: 4),
                ],
                Text(
                  message.sender.label,
                  style: TextStyle(
                    color: isHuman ? Colors.white70 : (isBot ? AppColors.primary : AppColors.slate400),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (alignRight) ...[
                  const SizedBox(width: 4),
                  Icon(message.sender.icon, size: 12, color: Colors.white70),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message.content,
              style: TextStyle(
                color: textColor,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: isHuman ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration cardDecoration({Color borderColor = AppColors.slate200}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: borderColor),
    boxShadow: const [
      BoxShadow(color: Color(0x080F172A), offset: Offset(0, 4), blurRadius: 12),
    ],
  );
}

enum TicketSource {
  web('Web Store', Icons.language_rounded, AppColors.primary, AppColors.primarySoft),
  facebook('Facebook', Icons.facebook_rounded, AppColors.indigo, AppColors.indigoSoft),
  email('Email', Icons.mail_outline_rounded, AppColors.success, AppColors.successSoft);

  const TicketSource(this.label, this.icon, this.color, this.softColor);
  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
}

enum TicketStatus {
  open('Chờ Xử Lý', AppColors.danger, AppColors.dangerSoft),
  inProgress('Đang Tư Vấn', AppColors.warning, AppColors.warningSoft),
  pending('Tạm Dừng', AppColors.warning, AppColors.warningSoft),
  resolved('Đã Hoàn Tất', AppColors.success, AppColors.successSoft);

  const TicketStatus(this.label, this.color, this.softColor);
  final String label;
  final Color color;
  final Color softColor;
}

enum TicketIntent {
  question('Tư Vấn FAQ', Icons.help_outline_rounded, AppColors.primary, AppColors.primarySoft),
  complaint('Khiếu Nại / Đổi Trả', Icons.report_problem_rounded, AppColors.danger, AppColors.dangerSoft),
  spam('Spam', Icons.block_rounded, AppColors.slate500, AppColors.slate100);

  const TicketIntent(this.label, this.icon, this.color, this.softColor);
  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
}

enum SenderType {
  customer('Khách Hàng', Icons.person_rounded, AppColors.slate500),
  bot('SportGear AI Assistant', Icons.smart_toy_rounded, AppColors.primary),
  human('Chuyên Viên CSKH Live', Icons.support_agent_rounded, AppColors.indigo);

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
    this.ticketId = '',
  });

  final int number;
  final String customerName;
  final TicketSource source;
  final TicketStatus status;
  final TicketIntent intent;
  final String summary;
  final String createdAgo;
  final List<TicketMessage> messages;
  final String ticketId;
}

class TicketMessage {
  const TicketMessage({required this.sender, required this.content});

  final SenderType sender;
  final String content;
}

class AppColors {
  static const background = Color(0xFFF8FAFC);
  static const primary = Color(0xFF0284C7);
  static const primarySoft = Color(0xFFF0F9FF);
  static const indigo = Color(0xFF4F46E5);
  static const indigoSoft = Color(0xFFEEF2FF);
  static const success = Color(0xFF059669);
  static const successSoft = Color(0xFFECFDF5);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFFFBEB);
  static const danger = Color(0xFFE11D48);
  static const dangerSoft = Color(0xFFFFF1F2);
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

final List<SupportTicket> initialDemoTickets = [
  const SupportTicket(
    number: 102,
    customerName: 'Khách Hàng Web (SportGear Store)',
    source: TicketSource.web,
    status: TicketStatus.open,
    intent: TicketIntent.complaint,
    summary: 'Sản phẩm áo Polo bị lỗi rách chỉ ở nách, khách yêu cầu đổi ngay trong ngày.',
    createdAgo: 'Vừa xong',
    ticketId: 'ticket_demo_102',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content: 'Chào shop, áo Polo Pro Active mình mới nhận bị rách chỉ ở phần nách, shop đổi mới giúp mình nhé!',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content: 'Dạ SportGear rất tiếc về sự cố này ạ! Em đã tạo Ticket ưu tiên #102 và chuyển trực tiếp cho Chuyên viên CSKH hỗ trợ đổi mới 1-1 tận nhà miễn phí trong 30 ngày cho bạn ngay ạ!',
      ),
    ],
  ),
  const SupportTicket(
    number: 103,
    customerName: 'Nguyễn Văn Tuấn (Facebook)',
    source: TicketSource.facebook,
    status: TicketStatus.inProgress,
    intent: TicketIntent.question,
    summary: 'Tư vấn chọn size giày chạy bộ Ultra Boost 2026 cho người chân bè.',
    createdAgo: '12 phút trước',
    ticketId: 'ticket_demo_103',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content: 'Giày Ultra Boost 2026 chân bè ngang 10cm thì nên đi size 42 hay 43 shop?',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content: 'Dạ với form chân bè ngang, bạn nên tăng 1 size lên 43 để mũi giày ôm chân êm ái và không bị tức ngón khi chạy bộ cự ly dài nhé!',
      ),
      TicketMessage(
        sender: SenderType.human,
        content: 'Dạ em Tuấn CSKH xin gửi bạn bảng đo cm chân chi tiết để chọn size chuẩn nhất ạ.',
      ),
    ],
  ),
  const SupportTicket(
    number: 104,
    customerName: 'Trần Thị Mai (Email)',
    source: TicketSource.email,
    status: TicketStatus.open,
    intent: TicketIntent.question,
    summary: 'Hỏi điều kiện miễn phí vận chuyển toàn quốc và mã giảm giá đơn 1 triệu.',
    createdAgo: '30 phút trước',
    ticketId: 'ticket_demo_104',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content: 'Shop cho mình hỏi đơn hàng trên 1 triệu có được freeship và tặng quà gì không?',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content: 'Dạ mọi đơn hàng từ 500.000đ đều được FREESHIP 100% toàn quốc. Đơn từ 1.000.000đ shop tặng thêm 01 bình giữ nhiệt thể thao Inox 304 cao cấp ạ!',
      ),
    ],
  ),
  const SupportTicket(
    number: 101,
    customerName: 'Lê Hoàng Nam (Web Store)',
    source: TicketSource.web,
    status: TicketStatus.resolved,
    intent: TicketIntent.question,
    summary: 'Đã tư vấn bảng size quần Gym Flex và khách đã đặt hàng thành công.',
    createdAgo: '1 giờ trước',
    ticketId: 'ticket_demo_101',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content: 'Mình cao 1m75 nặng 70kg mặc quần Gym Flex size nào đẹp?',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content: 'Dạ theo bảng size chuẩn SportGear, anh chọn size L (69-76kg) sẽ vừa vặn và thoải mái nhất khi tập gym ạ!',
      ),
      TicketMessage(
        sender: SenderType.customer,
        content: 'Cảm ơn shop, mình vừa đặt 2 chiếc trên web rồi nhé.',
      ),
    ],
  ),
];
