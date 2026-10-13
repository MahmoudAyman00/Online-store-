import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/firestore_paths.dart';
import '../core/theme.dart';

class _TxView {
  const _TxView({
    required this.data,
    required this.username,
    required this.email,
  });
  final Map<String, dynamic> data;
  final String username;
  final String email;
}

class TransactionScreen extends StatefulWidget {
  @override
  _TransactionScreenState createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  Future<List<_TxView>> _fetchTransactions(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await FirebaseFirestore.instance
        .collection(FirestorePaths.transactions)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    final txs = snapshot.docs.map((doc) {
      final data = doc.data();
      // إضافة orderId باستخدام doc.id كـ orderId
      data['orderId'] = doc.id;
      return data;
    }).toList();

    // أحدث طلب أولاً
    txs.sort((a, b) {
      final ta = a['timestamp'];
      final tb = b['timestamp'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });

    // Batch-fetch buyers once
    final uids = txs
        .map((t) => (t['userId'] ?? '').toString())
        .where((u) => u.isNotEmpty)
        .toSet();
    final Map<String, Map<String, dynamic>> users = {};
    for (final uid in uids) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(FirestorePaths.users)
            .doc(uid)
            .get();
        users[uid] = doc.data() ?? {};
      } catch (_) {
        users[uid] = {};
      }
    }

    return txs.map((t) {
      final u = users[(t['userId'] ?? '').toString()] ?? {};
      final name = (u['username'] as String?)?.trim() ?? '';
      return _TxView(
        data: t,
        username: name.isNotEmpty ? name : 'Unknown user',
        email: (u['email'] as String?)?.trim().isNotEmpty == true
            ? (u['email'] as String).trim()
            : '—',
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transactions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Button to select a date
            Container(
              margin: EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton.icon(
                onPressed: () async {
                  DateTime? selectedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2101),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context)
                              .colorScheme
                              .copyWith(
                                  primary:
                                      Theme.of(context).colorScheme.primary),
                        ),
                        child: child!,
                      );
                    },
                  );

                  if (selectedDate != null) {
                    final transactions = await _fetchTransactions(selectedDate);
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          scrollable: true,
                          insetPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 24),
                          title: Text(
                            'Transactions on ${selectedDate.toLocal().toString().split(' ')[0]}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          content: SizedBox(
                            width: double.maxFinite,
                            child:
                          transactions.isEmpty
                              ? Text(
                                  'No transactions found for the selected date.',
                                  style: TextStyle(fontSize: 16, color: Colors.redAccent),
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    children: transactions.map((tx) {
                                      final transaction = tx.data;
                                      final items = transaction['items']
                                              as List<dynamic>? ??
                                          [];
                                      final total = (transaction['totalPrice']
                                              as num?)
                                          ?.toDouble();

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 8.0),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            10),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .primarySoft,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(12),
                                                    ),
                                                    child: const Icon(
                                                        Icons.person,
                                                        color: AppColors
                                                            .primary),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          tx.username,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold,
                                                            color: AppColors
                                                                .textDark,
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                        Text(
                                                          tx.email,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 13,
                                                            color: AppColors
                                                                .textMuted,
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.success
                                                          .withValues(
                                                              alpha: 0.12),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(20),
                                                    ),
                                                    child: Text(
                                                      total == null
                                                          ? '—'
                                                          : '\$${total.toStringAsFixed(0)}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: AppColors
                                                            .success,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Order: ${transaction['orderId'] ?? '—'}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .textMuted),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                              const Divider(height: 20),
                                              ...items.map<Widget>((item) {
                                                final price =
                                                    (item['price'] as num?)
                                                            ?.toDouble() ??
                                                        0;
                                                final qty =
                                                    (item['quantity'] as num?)
                                                            ?.toInt() ??
                                                        0;
                                                return Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 3),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '${item['name'] ?? 'Item'}  ×$qty',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      14),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '\$${(price * qty).toStringAsFixed(2)}',
                                                        style:
                                                            const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Close',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.date_range, size: 20),
                label: Text(
                  'Select Date',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            SizedBox(height: 20),
            // Placeholder for future content or status
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 60),
                    SizedBox(height: 10),
                    Text(
                      'Select a date to view transactions',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
