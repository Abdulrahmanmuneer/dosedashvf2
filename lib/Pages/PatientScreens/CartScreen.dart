import 'package:DoseDash/Algorithms/GetUserLocation.dart';
import 'package:DoseDash/Services/stripe_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:DoseDash/Pages/PatientScreens/PatientHomeScreen.dart';

class CartScreen extends StatefulWidget {
  final List<Medicine> globalCart;

  CartScreen({required this.globalCart});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double _totalPrice = 0.0;
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isDisposed = false; // Track whether the widget is disposed

  @override
  void initState() {
    super.initState();
    _calculateTotalPrice();
    _fetchUserData();
  }

  @override
  void dispose() {
    // Mark the widget as disposed to avoid calling setState on it
    _isDisposed = true;
    super.dispose();
  }

  void _calculateTotalPrice() {
    _totalPrice = widget.globalCart
        .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  Future<void> _fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString('auth_token');
    String? userId = prefs.getString('userid');

    if (authToken != null) {
      _user = FirebaseAuth.instance.currentUser;

      if (_user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (!_isDisposed && mounted) {
          // Check if the widget is still mounted and not disposed
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>?;

            if (_userData != null) {
              _userData!['firstname'] ??= '';
              _userData!['lastname'] ??= '';
              _userData!['phone'] ??= '';
            }
          });
        }
      }
    } else {
      print("Auth token is not available.");
    }
  }

  Future<void> _handlePayment() async {
    try {
      // Convert total price to cents (Stripe expects amounts in cents)
      int amount = (_totalPrice * 100).toInt();

      // Initialize and present the payment sheet
      bool paymentSuccessful = await StripeService.initPaymentSheet(
          context, amount.toString(), 'LKR');

      if (paymentSuccessful) {
        // Payment was successful, place the order
        _placeOrder();
      } else {
        // Handle unsuccessful payment
        print('Payment failed');
        if (!_isDisposed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment failed')),
          );
        }
      }
    } catch (e) {
      print('Error during payment process: $e');
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during payment process: $e')),
        );
      }
    }
  }

  void _showOrderSummary() {
    if (_isDisposed || !mounted)
      return; // Prevent opening the dialog if the widget is disposed
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Order Summary'),
          content: SizedBox(
            width:
                double.maxFinite, // Make the content width as wide as possible
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...widget.globalCart.map((item) {
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                          '${item.brand}\n\රු${item.price.toStringAsFixed(2)} x ${item.quantity} = \රු${(item.price * item.quantity).toStringAsFixed(2)}'),
                    );
                  }).toList(),
                  SizedBox(height: 20),
                  Text(
                    'Total: \රු${_totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _cancelOrder();
              },
              child: Text('Cancel Order'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _handlePayment();
              },
              child: Text('Proceed to Payment'),
            ),
          ],
        );
      },
    );
  }

  // Cancel the order and clear the cart
  void _cancelOrder() {
    if (!_isDisposed && mounted) {
      setState(() {
        widget.globalCart.clear();
        _totalPrice = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order canceled')),
      );
    }
  }

  void _placeOrder() async {
    // Retrieve user ID from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userid');

    // Check if user ID is available
    if (userId != null) {
      // Fetch user data if not already available
      if (_userData == null) {
        await _fetchUserData();
      }

      // Proceed if user data is available
      if (_userData != null) {
        // Get the user's current location
        LocationService locationService = LocationService();
        LatLng? userLocation = await locationService.getUserLocation();

        // Proceed if user location is successfully retrieved
        if (userLocation != null) {
          // Fetch delivery persons within a 15 km radius of the user's location
          List<String> nearbyDeliveryPersons =
              await locationService.getNearbyDeliveryPersons(userLocation);

          // Group the order items by pharmacy and fetch the pharmacy details
          Map<String, List<Map<String, dynamic>>> groupedOrderItems = {};
          Map<String, Map<String, dynamic>> pharmacyDetails = {};

          for (var medicine in widget.globalCart) {
            var orderItem = {
              'medicineId': medicine.id,
              'name': medicine.name,
              'brand': medicine.brand,
              'price': medicine.price,
              'quantity': medicine.quantity,
              'pharmacyId': medicine.pharmacyId,
            };

            // Add order item to the corresponding pharmacy's list
            if (!groupedOrderItems.containsKey(medicine.pharmacyId)) {
              groupedOrderItems[medicine.pharmacyId] = [];
            }
            groupedOrderItems[medicine.pharmacyId]!.add(orderItem);

            // Fetch pharmacy details if not already fetched
            if (!pharmacyDetails.containsKey(medicine.pharmacyId)) {
              DocumentSnapshot pharmacyDoc = await FirebaseFirestore.instance
                  .collection('pharmacies')
                  .doc(medicine.pharmacyId)
                  .get();

              if (pharmacyDoc.exists) {
                pharmacyDetails[medicine.pharmacyId] = {
                  'address': pharmacyDoc['address'],
                  'name': pharmacyDoc['pharmacyName'],
                };
              } else {
                print('Pharmacy not found for ID: ${medicine.pharmacyId}');
              }
            }
          }

          // Prepare the lists for pharmacy names and addresses
          List<String> pharmacyNames = pharmacyDetails.values
              .map((details) => details['name'] as String)
              .toList();
          List<String> pharmacyAddresses = pharmacyDetails.values
              .map((details) => details['address'] as String)
              .toList();

          // Add the order to Firestore and get the order ID
          String? orderId;
          for (var entry in groupedOrderItems.entries) {
            String pharmacyId = entry.key;
            List<Map<String, dynamic>> orderItems = entry.value;

            // Add the order to Firestore and retrieve the orderId
            DocumentReference orderRef =
                await FirebaseFirestore.instance.collection('orders').add({
              'userId': userId,
              'pharmacyId': pharmacyId,
              'user_name':
                  '${_userData!['firstname']} ${_userData!['lastname']}',
              'user_address': '${_userData!['address']}', // User address
              'phone_number': _userData!['phone'] ?? '',
              'orderItems': orderItems,
              'orderStatus': 'on progress',
              'timestamp': FieldValue.serverTimestamp(),
            });

            // Get the order ID
            orderId = orderRef.id;
          }

          // Notify delivery persons within the 15 km radius with a single document
          try {
            await FirebaseFirestore.instance.collection('notifications').add({
              'orderId': orderId, // Add the orderId here
              'deliveryPersonIds': null, // List of delivery person IDs
              'userId': userId,
              'orderItems':
                  groupedOrderItems.values.expand((items) => items).toList(),
              'orderStatus': 'pending',
              'timestamp': FieldValue.serverTimestamp(),
              'notificationType': 'order',
              'patient_name':
                  '${_userData!['firstname']} ${_userData!['lastname']}',
              'patient_address': '${_userData!['address']}', // User address
              'pharmacy_name': pharmacyNames, // List of pharmacy names
              'pharmacy_address':
                  pharmacyAddresses, // List of pharmacy addresses
              'totalPrice': _totalPrice, // Add total price here
            });

            if (!_isDisposed && mounted) {
              // Show a success message and clear the cart
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Order placed successfully')),
              );

              setState(() {
                widget.globalCart.clear();
                _totalPrice = 0.0;
              });
            }
          } catch (e) {
            print('Error while notifying delivery persons: $e');
          }
        } else {
          print('Unable to get user location.');
        }
      } else {
        print('User data not available. Cannot place order.');
      }
    } else {
      print('User ID not available. Cannot place order.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Cart'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.globalCart.length,
              itemBuilder: (context, index) {
                var medicine = widget.globalCart[index];
                return ListTile(
                  title: Text(medicine.name),
                  subtitle: Text(
                      '${medicine.brand} - \රු${medicine.price.toStringAsFixed(2)} x ${medicine.quantity}'),
                  trailing: IconButton(
                    icon: Icon(Icons.remove_circle),
                    onPressed: () {
                      if (!_isDisposed && mounted) {
                        setState(() {
                          widget.globalCart.removeAt(index);
                          _calculateTotalPrice();
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(
                  'Total Price: \රු${_totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _showOrderSummary,
                  child: Text('Place Order'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
