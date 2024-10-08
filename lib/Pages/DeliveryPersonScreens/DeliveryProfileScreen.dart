import 'package:DoseDash/Pages/MapScreens/MapScreen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

// Define the ProfileScreen2 widget as a stateful widget to maintain state
class ProfileScreen2 extends StatefulWidget {
  const ProfileScreen2({super.key});

  @override
  State<ProfileScreen2> createState() => _ProfileScreen2State();
}

// Define the state for ProfileScreen2
class _ProfileScreen2State extends State<ProfileScreen2> {
  // Controllers for the text fields
  TextEditingController _fnameController = TextEditingController();
  TextEditingController _lnameController = TextEditingController();
  TextEditingController _phoneController = TextEditingController();
  TextEditingController _addressController = TextEditingController();

  String? _userId; // User ID fetched from shared preferences
  bool _isLoading = true; // Loading state to show progress indicator
  Map<String, dynamic>? _userData; // User data fetched from Firestore

  @override
  void initState() {
    super.initState();
    _fetchUserId(); // Fetch user ID when the screen is initialized
  }

  // Fetch user ID from shared preferences
  Future<void> _fetchUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _userId =
        prefs.getString('userid'); // Get the user ID from shared preferences
    if (_userId != null) {
      _fetchUserData(); // Fetch user data if user ID is available
    }
  }

  Future<void> _fetchUserData() async {
    if (_userId != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('DeliveryPersons')
          .doc(_userId)
          .get();

      if (mounted) {
        // Only call setState if the widget is still mounted
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>?;
          if (_userData != null) {
            _fnameController.text = _userData!['First Name'] ?? '';
            _lnameController.text = _userData!['Last Name'] ?? '';
            _phoneController.text = _userData!['phone Number'] ?? '';
            _addressController.text = _userData!['Address'] ?? '';
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateUserAddress(String newAddress) async {
    if (_userId != null) {
      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'address': newAddress,
      });

      if (mounted) {
        // Only show SnackBar if the widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Address updated successfully')),
        );
      }
    }
  }

  void _openMapScreen() async {
    final selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Mapscreen(userRole: 'patient'),
      ),
    );
    if (selectedLocation != null) {
      setState(() {
        _addressController.text = selectedLocation;
      });
      _updateUserAddress(selectedLocation); // Call method to update Firestore
    }
  }

  // Validate the input fields
  bool _validateInputs() {
    if (_fnameController.text.isEmpty ||
        _lnameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _addressController.text.isEmpty) {
      return false; // Return false if any field is empty
    }
    if (_phoneController.text.length != 10) {
      return false; // Return false if phone number is not 10 digits
    }
    return true; // Return true if all validations pass
  }

  // Update user data in Firestore
  Future<void> _updateUserData() async {
    if (_validateInputs()) {
      if (_userId != null) {
        // Update user document in Firestore
        await FirebaseFirestore.instance
            .collection('DeliveryPersons')
            .doc(_userId)
            .update({
          'First Name': _fnameController.text,
          'Last Name': _lnameController.text,
          'phone Number': _phoneController.text,
          'Address': _addressController.text,
        });

        // Show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );

        // Navigate to the home screen
        Navigator.pushNamed(context, '/');
      }
    } else {
      // Show an error message if validation fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Please fill all fields and ensure the phone number is 10 digits')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'), // Set the title of the app bar
        automaticallyImplyLeading: false, // Don't show the back button
        centerTitle: true, // Center the title
      ),
      body: _isLoading
          ? Center(
              child:
                  CircularProgressIndicator()) // Show loading indicator while fetching data
          : Padding(
              padding:
                  const EdgeInsets.all(16.0), // Add padding around the content
              child: ListView(
                children: [
                  SizedBox(height: 20), // Add space above the first text field
                  TextField(
                    controller: _fnameController, // Controller for first name
                    decoration: InputDecoration(
                        labelText: 'First Name',
                        border:
                            OutlineInputBorder()), // Decoration for first name field
                  ),
                  SizedBox(height: 20), // Add space below the first text field
                  TextField(
                    controller: _lnameController, // Controller for last name
                    decoration: InputDecoration(
                        labelText: 'Last Name',
                        border:
                            OutlineInputBorder()), // Decoration for last name field
                  ),
                  SizedBox(
                      height: 20), // Add space below the last name text field
                  TextField(
                    controller: _phoneController, // Controller for phone number
                    decoration: InputDecoration(
                        labelText: 'Phone',
                        border:
                            OutlineInputBorder()), // Decoration for phone field
                    keyboardType:
                        TextInputType.number, // Set input type to number
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly, // Allow only digits
                      LengthLimitingTextInputFormatter(
                          10), // Limit to 10 digits
                    ],
                  ),
                  SizedBox(height: 20), // Add space below the phone text field

                  GestureDetector(
                    onTap: _openMapScreen,
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Click to Find Address *',
                        border: OutlineInputBorder(),
                      ),
                      controller: _addressController,
                      enabled:
                          false, // Makes the field not editable directly by the user
                    ),
                  ),

                  SizedBox(
                      height: 20), // Add space below the address text field

                  // Email field (disabled)
                  TextField(
                    controller: TextEditingController(
                        text: _userData?['email']), // Set email value
                    decoration: InputDecoration(
                        labelText: 'Email',
                        border:
                            OutlineInputBorder()), // Decoration for email field
                    enabled: false, // Disable editing
                  ),
                  SizedBox(height: 20), // Add space below the email field

                  // Age range field (disabled)
                  TextField(
                    controller: TextEditingController(
                        text: _userData?['agerange']), // Set age range value
                    decoration: InputDecoration(
                        labelText: 'Age Range',
                        border:
                            OutlineInputBorder()), // Decoration for age range field
                    enabled: false, // Disable editing
                  ),
                  SizedBox(height: 20), // Add space below the age range field

                  // Update profile button
                  ElevatedButton(
                    onPressed: _updateUserData, // Call _updateUserData on press
                    child: Text('Update Profile'), // Button label
                  ),
                ],
              ),
            ),
    );
  }
}
