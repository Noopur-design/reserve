import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/address_form.dart';
import '../widgets/auth_gate.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';
import 'order_tracking_screen.dart';

/// Support chat with a scripted virtual assistant.
class ChatScreen extends StatefulWidget {
  final String? initialTopic;
  const ChatScreen({super.key, this.initialTopic});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _orderCtrl = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _msgs = [];
  bool _typing = false;

  static const quick = [
    (Icons.inventory_2_outlined, 'Track My Order', 'Get real-time updates'),
    (Icons.history, 'Returns & Refunds', 'Start a return request'),
    (Icons.credit_card, 'Payment Issues', 'Fix payment problems'),
    (Icons.local_shipping_outlined, 'Delivery Help', 'Shipping & delivery info'),
    (Icons.view_in_ar_outlined, 'Product Information', 'Details & availability'),
    (Icons.person_outline, 'Account Help', 'Login, profile & security'),
  ];

  @override
  void initState() {
    super.initState();
    _msgs.add(ChatMessage(
        'Hello! 👋\nI\'m your virtual assistant. Please select a topic above or type your question below.',
        false,
        DateTime.now()));
    if (widget.initialTopic != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send('I need help with ${widget.initialTopic}'));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _orderCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() {
      _msgs.add(ChatMessage(text, true, DateTime.now()));
      _typing = true;
    });
    _scrollDown();
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final t = text.toLowerCase();
    ChatMessage reply;
    if (t.contains('track') || t.contains('order')) {
      reply = ChatMessage('Sure! Please share your order number so I can help you track it.', false, DateTime.now(),
          askOrderNumber: true);
    } else if (t.contains('return') || t.contains('refund')) {
      reply = ChatMessage(
          'Sealed products can be returned within 48 hours if damaged or incorrect. Refunds reach your original payment method in 5–7 working days.',
          false,
          DateTime.now());
    } else if (t.contains('payment')) {
      reply = ChatMessage(
          'Sorry about that! If money was debited but the order failed, it will be auto-refunded within 3 working days. You can also manage cards from Profile → Payment Methods.',
          false,
          DateTime.now());
    } else if (t.contains('deliver') || t.contains('shipping')) {
      reply = ChatMessage(
          'Standard delivery takes 3–5 working days. A valid government ID is required at delivery as per local laws.',
          false,
          DateTime.now());
    } else if (t.contains('product')) {
      reply = ChatMessage('All products are sourced from licensed retailers. Availability depends on your city — try searching for a product to check.',
          false, DateTime.now());
    } else if (t.contains('account') || t.contains('login') || t.contains('password')) {
      reply = ChatMessage('You can reset your password from the Sign In screen using "Forgot Password?". Your name and photo can be changed from Profile → Edit Profile (tap your photo or the gear icon), where you can also delete your account.',
          false, DateTime.now());
    } else {
      reply = ChatMessage('Thanks for reaching out! A support specialist will join this chat shortly. Meanwhile, is there anything else I can help with?',
          false, DateTime.now());
    }
    setState(() {
      _typing = false;
      _msgs.add(reply);
    });
    _scrollDown();
  }

  void _lookupOrder() {
    final state = context.read<AppState>();
    final q = _orderCtrl.text.replaceAll('#', '').trim();
    if (q.isEmpty) {
      showToast(context, 'Enter your order number');
      return;
    }
    // Orders belong to an account; guests are asked to sign in first.
    if (state.isGuest) {
      requireAccount(context, 'look up your orders');
      return;
    }
    final match = state.orders.where((o) => o.id.replaceAll('#', '') == q).toList();
    _orderCtrl.clear();
    FocusScope.of(context).unfocus();
    setState(() => _msgs.add(ChatMessage('#$q', true, DateTime.now())));
    if (match.isEmpty) {
      setState(() => _msgs.add(ChatMessage(
          'I couldn\'t find order #$q. Please double-check the number — you can find it under My Orders.',
          false,
          DateTime.now())));
    } else {
      final o = match.first;
      setState(() => _msgs.add(ChatMessage(
          'Found it! Order ${o.id} (${o.itemsLabel}, ${rupees(o.total)}) is currently: ${_statusText(o.status)}. Opening the details for you…',
          false,
          DateTime.now())));
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        final done = o.status == OrderStatus.delivered || o.status == OrderStatus.cancelled;
        push(context, done ? OrderDetailScreen(order: o) : OrderTrackingScreen(order: o));
      });
    }
    _scrollDown();
  }

  String _statusText(OrderStatus s) => switch (s) {
        OrderStatus.processing => 'Processing',
        OrderStatus.packed => 'Packed',
        OrderStatus.shipped => 'Shipped',
        OrderStatus.outForDelivery => 'Out for delivery',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const PageHeader(title: 'Chat with Us', titleSize: 32),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFF2EA043), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('Our support team is online', style: T.sans(16, color: AppColors.grey)),
          ]),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                IllustratedCard(
                  image: '${img}illus_chat.jpg',
                  minHeight: 150,
                  builder: (context, width) => Row(children: [
                    IconBubble(
                        icon: Icons.headset_mic_outlined, size: (width * 0.3).clamp(52.0, 76.0), bg: AppColors.maroonSoft),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('Hi there! 👋',
                              maxLines: 1, style: T.serif(26, color: AppColors.maroon, weight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 4),
                        Text('Welcome to our support. How can we help you today?',
                            style: T.sans(14.5, color: AppColors.grey, height: 1.4)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                SectionTitle('Quick Help', size: 25, action: 'View All', actionColor: AppColors.grey,
                    onAction: () => _send('Show me all help topics')),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: quick.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.9),
                  itemBuilder: (_, i) {
                    final (icon, t, s) = quick[i];
                    return AppCard(
                      onTap: () => _send(i == 0 ? 'I want to track my order' : t),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        IconBubble(icon: icon, size: 50, bg: const Color(0xFFF3E6E2)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                            FittedBox(
                                fit: BoxFit.scaleDown, child: Text(t, style: T.sans(15, weight: FontWeight.w600))),
                            FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(s, style: T.sans(12.5, color: AppColors.grey))),
                          ]),
                        ),
                      ]),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(20)),
                    child: Text('Today', style: T.sans(15)),
                  ),
                ),
                const SizedBox(height: 14),
                ..._msgs.map((m) => FadeIn(dy: 10, child: _bubble(m, w))),
                if (_typing)
                  Padding(
                    padding: const EdgeInsets.only(left: 74, bottom: 12),
                    child: Row(children: [
                      Text('Assistant is typing', style: T.sans(13, color: AppColors.grey)),
                      const SizedBox(width: 6),
                      const SizedBox(
                          width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.maroon)),
                    ]),
                  ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.creamLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
            child: Row(children: [
              IconButton(
                onPressed: () => showToast(context, 'Attachments are not available in the demo'),
                icon: const Icon(Icons.attach_file, size: 28, color: AppColors.grey),
              ),
              Expanded(
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _input,
                    onSubmitted: _send,
                    textInputAction: TextInputAction.send,
                    style: T.sans(16),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type your message...',
                      hintStyle: T.sans(16, color: AppColors.greyLight),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Pressable(
                scale: 0.88,
                onTap: () => _send(_input.text),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(color: AppColors.maroon, shape: BoxShape.circle),
                  child: const Icon(Icons.send_outlined, color: Colors.white, size: 26),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bubble(ChatMessage m, double w) {
    final time = fmtTime(m.time).replaceFirst(RegExp(r'^0'), '');
    if (m.fromUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            constraints: BoxConstraints(maxWidth: w * 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            decoration: BoxDecoration(color: AppColors.maroon, borderRadius: BorderRadius.circular(24)),
            child: Text(m.text, style: T.sans(16.5, color: Colors.white)),
          ),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(time, style: T.sans(13.5, color: AppColors.grey)),
            const SizedBox(width: 6),
            const Icon(Icons.done_all, size: 18, color: AppColors.maroon),
          ]),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const IconBubble(icon: Icons.headset_mic_outlined, size: 58, bg: AppColors.maroonSoft),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.creamLight,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(m.text, style: T.sans(16.5, height: 1.45)),
            ),
            const SizedBox(height: 6),
            Text(time, style: T.sans(13.5, color: AppColors.grey)),
            if (m.askOrderNumber) ...[
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Order Number', style: T.sans(16.5)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _orderCtrl,
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _lookupOrder(),
                        style: T.sans(16),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.view_in_ar_outlined, color: AppColors.grey),
                          hintText: 'Enter your order number',
                          hintStyle: T.sans(15, color: AppColors.greyLight),
                          filled: true,
                          fillColor: AppColors.cream,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.maroon)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Pressable(
                      onTap: _lookupOrder,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: AppColors.maroon, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_forward, color: Colors.white),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text('Try 8124092817. You can find your order number in My Orders.',
                      style: T.sans(13, color: AppColors.grey)),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
