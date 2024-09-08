import 'dart:async';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String notificationId;
  final String deliveryPersonIds;
  final List pharmacyAddress;

  OrderTrackingScreen({
    required this.notificationId,
    required this.deliveryPersonIds,
    required this.pharmacyAddress,
  });

  @override
  _OrderTrackingScreenState createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  GoogleMapController? mapController;
  LatLng? patientLocation;
  LatLng? deliveryPersonLocation;
  List<LatLng> pharmacyLocations = [];
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _getInitialData();
  }

  Future<void> _getInitialData() async {
    try {
      DocumentSnapshot notificationDoc = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.notificationId)
          .get();

      if (notificationDoc.exists) {
        // Get patient address
        String? patientAddress = notificationDoc['patient_address'];
        if (patientAddress != null && patientAddress.isNotEmpty) {
          patientLocation = await _getLatLngFromAddress(patientAddress);
          setState(() {
            markers.add(
              Marker(
                markerId: MarkerId('patient_location'),
                position: patientLocation!,
                infoWindow: InfoWindow(title: 'Patient'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
              ),
            );
          });
        } else {
          print('Patient address is null or empty');
        }

        // Get pharmacy addresses and cast the list
        List<dynamic>? pharmacyAddressesDynamic =
            notificationDoc['pharmacy_address'];
        List<String>? pharmacyAddresses =
            pharmacyAddressesDynamic?.cast<String>();

        if (pharmacyAddresses != null && pharmacyAddresses.isNotEmpty) {
          for (String address in pharmacyAddresses) {
            LatLng? pharmacyLocation = await _getLatLngFromAddress(address);
            if (pharmacyLocation != null) {
              setState(() {
                markers.add(
                  Marker(
                    markerId: MarkerId('pharmacy_${address.hashCode}'),
                    position: pharmacyLocation,
                    infoWindow: InfoWindow(title: 'Pharmacy'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueBlue),
                  ),
                );
                pharmacyLocations.add(pharmacyLocation);
              });
            } else {
              print('No coordinates found for pharmacy address: $address');
            }
          }
        } else {
          print('Pharmacy addresses are null or empty');
        }

        // Get delivery person location
        String deliveryPersonId = widget.deliveryPersonIds;
        if (deliveryPersonId.isNotEmpty) {
          await _fetchDeliveryPersonLocation(deliveryPersonId);
        } else {
          print('Delivery person ID is null or empty');
        }

        // Draw polylines
        _drawPolylines();

        // Update the map camera to show the markers
        if (mapController != null) {
          _updateMapCamera();
        }

        // Set data loaded to true
        setState(() {
          _isDataLoaded = true;
        });
      } else {
        print('Notification document does not exist.');
      }
    } catch (e, stacktrace) {
      print('Error fetching initial data: $e');
      print(stacktrace);
    }
  }

  Future<void> _fetchDeliveryPersonLocation(String deliveryPersonId) async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('DeliveryPersons')
          .doc(deliveryPersonId)
          .get();

      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('geolocation')) {
          String geoString = data['geolocation'] as String;
          List<String> geoParts = geoString.split(',');

          if (geoParts.length == 2) {
            double latitude = double.parse(geoParts[0]);
            double longitude = double.parse(geoParts[1]);
            deliveryPersonLocation = LatLng(latitude, longitude);

            setState(() {
              markers.add(
                Marker(
                  markerId:
                      MarkerId('delivery_person_location_$deliveryPersonId'),
                  position: deliveryPersonLocation!,
                  infoWindow: InfoWindow(title: 'Delivery Person'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen),
                ),
              );
            });

            _drawPolylines(); // Ensure polylines are redrawn with the new delivery person location

            _updateMapCamera();
          } else {
            print('Invalid geolocation format for delivery person');
          }
        } else {
          print('No geolocation data found for delivery person');
        }
      } else {
        print('Delivery person document does not exist');
      }
    } catch (e, stacktrace) {
      print('Error fetching delivery person location: $e');
      print(stacktrace);
    }
  }

  Future<LatLng> _getLatLngFromAddress(String address) async {
    try {
      // Perform geocoding to get coordinates from address
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        Location location = locations.first;
        return LatLng(location.latitude, location.longitude);
      } else {
        print('No coordinates found for the address: $address');
        return LatLng(0.0, 0.0); // Return a default or error location
      }
    } catch (e, stacktrace) {
      print('Geocoding error: $e');
      print(stacktrace);
      return LatLng(0.0, 0.0); // Return a default or error location
    }
  }

  void _drawPolylines() {
    if (deliveryPersonLocation != null && patientLocation != null) {
      List<LatLng> path = [deliveryPersonLocation!];
      path.addAll(pharmacyLocations);
      path.add(patientLocation!);

      setState(() {
        polylines.clear(); // Clear existing polylines if needed
        polylines.add(
          Polyline(
            polylineId: PolylineId('route'),
            points: path,
            color: Colors.blue,
            width: 5,
          ),
        );
      });
    }
  }

  void _updateMapCamera() {
    try {
      if (mapController != null && markers.isNotEmpty) {
        LatLngBounds bounds = _calculateBounds();
        mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50),
        );
      }
    } catch (e, stacktrace) {
      print('Error updating map camera: $e');
      print(stacktrace);
    }
  }

  LatLngBounds _calculateBounds() {
    double? minLat;
    double? maxLat;
    double? minLng;
    double? maxLng;

    for (var marker in markers) {
      double lat = marker.position.latitude;
      double lng = marker.position.longitude;

      if (minLat == null || lat < minLat) minLat = lat;
      if (maxLat == null || lat > maxLat) maxLat = lat;
      if (minLng == null || lng < minLng) minLng = lng;
      if (maxLng == null || lng > maxLng) maxLng = lng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track Order'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _isDataLoaded
          ? GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                    37.7749, -122.4194), // Default to San Francisco for testing
                zoom: 12,
              ),
              markers: markers,
              polylines: polylines,
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateMapCamera();
                });
              },
            )
          : Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
