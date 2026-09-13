import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OverpassService {
  // Overpass API kullanarak verilen konumun etrafındaki 'amenity=recycling' noktalarını getirir
  static Future<List<LatLng>> getNearbyRecyclingPoints(LatLng center, {double radius = 3000}) async {
    final query = '''
      [out:json][timeout:25];
      (
        node["amenity"="recycling"](around:$radius,${center.latitude},${center.longitude});
        way["amenity"="recycling"](around:$radius,${center.latitude},${center.longitude});
        relation["amenity"="recycling"](around:$radius,${center.latitude},${center.longitude});
        node["recycling_type"="container"](around:$radius,${center.latitude},${center.longitude});
      );
      out center;
    ''';

    final url = Uri.parse('https://overpass-api.de/api/interpreter');
    try {
      final response = await http.post(url, body: {'data': query});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<LatLng> points = [];

        for (var element in data['elements']) {
          if (element['type'] == 'node') {
            points.add(LatLng(element['lat'], element['lon']));
          } else if (element['center'] != null) {
            // way veya relation için center kullan
            points.add(LatLng(element['center']['lat'], element['center']['lon']));
          }
        }
        return points;
      } else {
        print('Overpass API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Overpass API error: $e');
      return [];
    }
  }
}
