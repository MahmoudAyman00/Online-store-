import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/firestore_paths.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// The buyer's own orders, newest first. Read-only history
/// (rules already allow owners to read their Transactions).
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchOrders();
  }

  Future<List<Map<String, dynamic>>> _fetchOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snap = await FirebaseFirestore.instance
        .collection(FirestorePaths.transactions)
        .where('userId', isEqualTo: user.uid)
        .get();
    final orders = snap.docs.map((d) {
      final data = d.data();
      data['orderId'] = d.id;
      return data;
    }).toList();
    // ترتيب محلي (أحدث أولاً) لتجنب composite index
    orders.sort((a, b) {
      final ta = a['timestamp'];
      final tb = b['timestamp'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });
    return orders;
  }

  Future<void> _refresh() async {
    setState(() => _ordersFuture = _fetchOrders());
    await _ordersFuture;
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('yyyy-MM-dd – HH:mm').format(ts.toDate());
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoading();
            }
            if (snapshot.hasError) {
              return AppError(
                message: 'Failed to load orders.',
                onRetry: _refresh,
              );
            }
            final orders = snapshot.data ?? [];
            if (orders.isEmpty) {
              return const AppEmpty(
                message: 'No orders yet.',
                icon: Icons.receipt_long_outlined,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final items =
                    (order['items'] as List<dynamic>?) ?? [];
                final total =
                    (order['totalPrice'] as num?)?.toDouble() ?? 0;
                final status =
                    (order['status'] ?? 'completed').toString();
                return FadeIn(
                  index: index % 10,
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 6),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.softFill,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_long,
                            color: AppColors.primary),
                      ),
                      title: Text(
                        'Order #${(order['orderId'] as String? ?? '').length > 8 ? (order['orderId'] as String).substring(0, 8) : order['orderId'] ?? '—'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Text(
                        '${_formatDate(order['timestamp'])} · ${items.length} items',
                        style: TextStyle(
                            fontSize: 13,
                            color: context.muted),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.success,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        const Divider(height: 1),
                        ...items.map<Widget>((item) {
                          final price =
                              (item['price'] as num?)?.toDouble() ??
                                  0;
                          final qty =
                              (item['quantity'] as num?)?.toInt() ??
                                  0;
                          return ListTile(
                            dense: true,
                            title: Text(
                              '${item['name'] ?? 'Item'}  ×$qty',
                              style:
                                  const TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              '\$${(price * qty).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              16, 4, 16, 12),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Total: \$${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
