import 'package:DoseDash/Pages/PatientScreens/OrderTrackingScreen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String userId;
  final String notificationId; // Pass the document ID as notificationId
  final Map<String, dynamic> notification;

  OrderDetailsScreen({
    required this.userId,
    required this.notificationId,
    required this.notification,
  });

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool isDeliveryPersonAssigned = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkDeliveryPersonStatus();
  }

  // Function to check if deliveryPersonIds is null or not
  Future<void> _checkDeliveryPersonStatus() async {
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(widget.notificationId) // Use document ID directly
        .snapshots()
        .listen((documentSnapshot) {
      if (documentSnapshot.exists) {
        var data = documentSnapshot.data();
        if (data != null) {
          setState(() {
            isDeliveryPersonAssigned = data['deliveryPersonIds'] != null;
            isLoading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double totalPrice = (widget.notification['totalPrice'] as num).toDouble();
    List<dynamic> orderItems = List.from(widget.notification['orderItems']);
    List<String> pharmacyNames = List<String>.from(widget.notification['pharmacy_name']);
    String patientName = widget.notification['patient_name'] ?? 'Unknown';
    String orderStatus = widget.notification['orderStatus'] ?? 'Unknown';
    Timestamp timestamp = widget.notification['timestamp'];

    String formattedDate = timestamp.toDate().toLocal().toString();

    Map<String, String> pharmacyDetails = {};
    for (var i = 0; i < pharmacyNames.length; i++) {
      pharmacyDetails[orderItems[i]['pharmacyId'] ?? 'Unknown'] = pharmacyNames[i];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Order Details'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card for Order ID
                  Card(
                    elevation: 4,
                    child: ListTile(
                      title: Text(
                        'Notification ID: ${widget.notificationId}', // Display document ID
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  // Card for Order Status and Date
                  Card(
                    elevation: 4,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            'Order Status: $orderStatus',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        ListTile(
                          title: Text(
                            'Date: $formattedDate',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  // Card for Patient Name
                  Card(
                    elevation: 4,
                    child: ListTile(
                      title: Text(
                        'Patient Name',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        patientName,
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  // Card for Total Price
                  Card(
                    elevation: 4,
                    child: ListTile(
                      title: Text(
                        'Total Price',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        '₨${totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 18, color: Colors.green),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  // Order Items Section
                  Text(
                    'Order Items:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: orderItems.length,
                      itemBuilder: (context, index) {
                        var item = orderItems[index];
                        if (item is Map<String, dynamic>) {
                          String pharmacyId = item['pharmacyId'] ?? 'Unknown';
                          String pharmacyName = pharmacyDetails[pharmacyId] ?? 'Unknown Pharmacy';

                          return Card(
                            elevation: 2,
                            child: ListTile(
                              title: Text(item['name'] ?? 'Unknown Item'),
                              subtitle: Text(
                                '${item['quantity'] ?? 0} x ₨${item['price']?.toStringAsFixed(2) ?? '0.00'}',
                              ),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₨${((item['quantity'] ?? 0) * (item['price']?.toDouble() ?? 0.0)).toStringAsFixed(2)}',
                                    style: TextStyle(color: Colors.green),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Pharmacy: $pharmacyName',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          return Container(); // Handle unexpected data
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Searching for Delivery Person Section
          Card(
            elevation: 4,
            margin: EdgeInsets.all(16),
            child: ListTile(
              title: Text(
                isDeliveryPersonAssigned
                    ? 'Delivery person assigned'
                    : 'Searching for Delivery person...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              trailing: isDeliveryPersonAssigned
                  ? Icon(Icons.check_circle, color: Colors.green)
                  : CircularProgressIndicator(),
            ),
          ),
          // Track Order Button
          // Track Order Button
Padding(
  padding: const EdgeInsets.all(40.0),
  child: Center(
    child: ElevatedButton(
      onPressed: isDeliveryPersonAssigned
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderTrackingScreen(
                    notificationId: widget.notificationId, // Use widget.notificationId directly
                    deliveryPersonIds: widget.notification['deliveryPersonIds'] ?? '', 
                    pharmacyAddress: widget.notification['pharmacy_address'] ?? [], 
                  ),
                ),
              );
            }
          : null, // Disable button if no delivery person assigned
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
      ),
      child: Text(
        'Track Order',
        style: TextStyle(fontSize: 18),
      ),
    ),
  ),
),
                
        ],
      ),
    );
  }
}
