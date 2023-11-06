import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class LocationSearchWidget extends StatefulWidget {
  @override
  _LocationSearchWidgetState createState() => _LocationSearchWidgetState();
}

class _LocationSearchWidgetState extends State<LocationSearchWidget> {
  final TextEditingController _searchController = TextEditingController();

  final MapController mapController = MapController();
  List<Marker> _markers = [];
  List<LatLng> routePoints = [];
  LatLng? currentLocation;

  @override
  void initState() {
    super.initState();
    getCurrentLocation().then((_) {
      fetchRoute();
    });
  }

  Future<void> fetchRoute() async {
    String url = 'http://router.project-osrm.org';
    String origin = currentLocation != null
        ? '${currentLocation!.longitude},${currentLocation!.latitude}'
        : '38.7500,9.0000'; // Origin latitude and longitude
    String destination = '38.8101,8.9831'; // Destination latitude and longitude

    Uri uri =
        Uri.parse('$url/route/v1/driving/$origin;$destination?overview=full');

    final response = await http.get(uri);
    print("hi there");
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      int distance = (data['routes'][0]['distance']).toInt();
      int duration = (data['routes'][0]['duration']).toInt();

      // Print the distance and duration
      print('Distance: $distance meters');
      print('Duration: $duration seconds');

      List<PointLatLng> polylinePoints =
          PolylinePoints().decodePolyline(data['routes'][0]['geometry']);

      // Convert polyline points to LatLng objects
      routePoints = polylinePoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
      print(routePoints);
      setState(() {});
    } else {
      throw Exception('Failed to fetch route');
    }
  }

  Future<void> getCurrentLocation() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });
    } else {
      // Handle permission denied or restricted
      // You can show a dialog or display an error message
    }

    print(currentLocation);
  }

  // get builder => null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Location Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TypeAheadFormField(
              textFieldConfiguration: TextFieldConfiguration(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search',
                  border: OutlineInputBorder(),
                ),
              ),
              suggestionsCallback: (pattern) async {
                String url =
                    'https://nominatim.openstreetmap.org/search?q={$pattern}&format=json&limit=5';

                final response = await http.get(Uri.parse(url));

                if (response.statusCode == 200) {
                  List<dynamic> suggestions = json.decode(response.body);
                  return suggestions
                      .map((suggestion) => suggestion['display_name'])
                      .toList();
                } else {
                  return [];
                }
              },
              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(suggestion),
                );
              },
              onSuggestionSelected: (suggestion) {
                _searchController.text = suggestion;
                searchLocation(suggestion);
              },
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: currentLocation ?? LatLng(9.005401, 38.763611),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: Colors.blue,
                      strokeWidth: 6.0,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    if (currentLocation != null)
                      Marker(
                        width: 40.0,
                        height: 40.0,
                        point: currentLocation!,
                        child: Container(
                          child: Icon(Icons.location_on, color: Colors.blue),
                        ),
                      ),
                    Marker(
                      width: 40.0,
                      height: 40.0,
                      point: LatLng(8.9831, 38.8101),
                      child: Container(
                        child: Icon(Icons.location_on, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

//to handle destination location

  void searchLocation(String suggestion) async {
    if (suggestion.isNotEmpty) {
      String url =
          'https://nominatim.openstreetmap.org/search?q={$suggestion}&format=json&limit=1';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty) {
          double lat = double.parse(data[0]['lat']);
          double lon = double.parse(data[0]['lon']);

          setState(() {
            _markers = [
              Marker(
                width: 80.0,
                height: 80.0,
                point: LatLng(lat, lon),
                child: Container(
                    child: Icon(
                  Icons.location_on,
                  color: Colors.red,
                )),
              ),
            ];
          });
        }
      }
    }
  }
}