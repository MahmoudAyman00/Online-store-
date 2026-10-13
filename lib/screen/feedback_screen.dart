import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/firestore_paths.dart';
import '../core/theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({Key? key}) : super(key: key);

  @override
  _FeedbackScreenState createState() => _FeedbackScreenState();
}

class _FeedbackView {
  const _FeedbackView({
    required this.feedback,
    required this.username,
    required this.email,
  });
  final Map<String, dynamic> feedback;
  final String username;
  final String email;
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  DateTimeRange? _selectedDateRange;

  Future<List<_FeedbackView>> _fetchFeedback(
      DateTimeRange? dateRange) async {
    Query query = FirebaseFirestore.instance
        .collection(FirestorePaths.feedbacks)
        .orderBy('timestamp', descending: true);

    // إذا تم اختيار تاريخ معين، نقوم بتصفية الاستعلام بناءً عليه
    if (dateRange != null) {
      query = query
          .where('timestamp', isGreaterThanOrEqualTo: dateRange.start)
          .where('timestamp', isLessThanOrEqualTo: dateRange.end);
    }

    final snapshot = await query.get();
    final feedbacks = snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    // ضمان الترتيب من الأحدث للأقدم حتى لو timestamp ناقص
    feedbacks.sort((a, b) {
      final ta = a['timestamp'];
      final tb = b['timestamp'];
      if (ta is Timestamp && tb is Timestamp) {
        return tb.compareTo(ta);
      }
      return 0;
    });

    // Batch-fetch authors once (was: raw uid shown per card)
    final uids = feedbacks
        .map((f) => (f['userId'] ?? '').toString())
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

    return feedbacks.map((f) {
      final u = users[(f['userId'] ?? '').toString()] ?? {};
      final name = (u['username'] as String?)?.trim() ?? '';
      return _FeedbackView(
        feedback: f,
        username: name.isNotEmpty ? name : 'Unknown user',
        email: (u['email'] as String?)?.trim().isNotEmpty == true
            ? (u['email'] as String).trim()
            : '—',
      );
    }).toList();
  }

  _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Feedbacks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
          )
        ],
      ),
      body: FutureBuilder<List<_FeedbackView>>(
        future: _fetchFeedback(_selectedDateRange),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No feedback found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final feedbackList = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: feedbackList.length,
              itemBuilder: (context, index) {
                final view = feedbackList[index];
                final feedback = view.feedback;
                final rating =
                    (feedback['rating'] as num?)?.toInt() ?? 0;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                view.username,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: context.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...List.generate(
                                    5,
                                    (i) => Icon(
                                          i < rating
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: AppColors.accent,
                                          size: 16,
                                        )),
                                const SizedBox(width: 4),
                                Text('$rating',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          view.email,
                          style: TextStyle(
                              fontSize: 14,
                              color: context.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Order: ${feedback['orderId'] ?? '—'}',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.muted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          feedback['comment'] ??
                              'No comment provided.',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            feedback['timestamp']?.toDate().toString() ??
                                'No date',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
