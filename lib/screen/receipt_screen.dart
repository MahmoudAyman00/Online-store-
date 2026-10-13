import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'home_screen.dart';
import '../core/theme.dart';
import '../core/ui.dart';

class ReceiptScreen extends StatefulWidget {
  final String orderId;
  final List<Map<String, dynamic>> cartItems;
  final double totalPrice;

  const ReceiptScreen({required this.orderId, required this.cartItems, required this.totalPrice});

  @override
  _ReceiptScreenState createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  int _rating = 0;
  String _comment = "";

  // Adding feedback to Firestore
  Future<void> _addFeedbackToFirestore(String orderId, int rating, String comment) async {
    // Get current user
    User? currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) return;

    try {
      final feedbacksRef = FirebaseFirestore.instance.collection('Feedbacks');

      final feedbackData = {
        'userId': currentUser.uid,
        'orderId': orderId,
        'rating': rating,
        'comment': comment,
        'timestamp': Timestamp.now(),
      };

      await feedbacksRef.add(feedbackData);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Feedback added successfully')));
    } catch (e) {
      debugPrint('Error adding feedback: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding feedback')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // منع الرجوع — الإيصال يغلق بزر الـ Home فقط
      child: Scaffold(
        appBar: AppBar(
          title: Text('Order Receipt',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: Icon(Icons.home),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomeScreen()),
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Summary
                Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.onSurface,
                  ),
                ),
                SizedBox(height: 20),
                Divider(color: context.line),
                SizedBox(height: 10),
                // Displaying Cart Items with images
                ...widget.cartItems.map((item) {
                  return FadeIn(
                    index: 0,
                    child: Card(
                    margin: EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(10),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: item['imageUrl'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: context.softFill,
                            child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) =>
                              Icon(Icons.image_not_supported,
                                  color: context.muted),
                        ),
                      ),
                      title: Text(
                        item['name'],
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Price: \$${(item['price'] as num).toDouble().toStringAsFixed(2)} x ${item['quantity']}',
                        style: TextStyle(color: context.muted),
                      ),
                    ),
                    ),
                  );
                }).toList(),
                SizedBox(height: 20),
                Divider(color: context.line),
                SizedBox(height: 10),
                Text(
                  'Total: \$${widget.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 30),
                // Rating section
                Text('Rate your experience:',
                    style:
                        TextStyle(fontSize: 16, color: context.onSurface)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < _rating ? Icons.star : Icons.star_border,
                        color: AppColors.accent,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          _rating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                SizedBox(height: 20),
                // Comment input field
                TextField(
                  onChanged: (value) {
                    _comment = value;
                  },
                  decoration: InputDecoration(
                    labelText: 'Leave a comment',
                    hintText: 'Enter your comment here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                  maxLines: 4,
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_rating == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Please provide a rating')));
                      } else if (_comment.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Please provide a comment')));
                      } else {
                        _addFeedbackToFirestore(
                            widget.orderId, _rating, _comment);
                      }
                    },
                    child: Text('Submit Feedback'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
