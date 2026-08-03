/// SearchResultEntity — domain entity for Nominatim geocoding results.
library;

import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class SearchResultEntity extends Equatable {
  final String displayName;
  final double lat;
  final double lng;
  final String osmType;

  const SearchResultEntity({
    required this.displayName,
    required this.lat,
    required this.lng,
    required this.osmType,
  });

  /// Convenience getter for map operations.
  LatLng get latLng => LatLng(lat, lng);

  @override
  List<Object?> get props => [displayName, lat, lng, osmType];

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'lat': lat,
        'lng': lng,
        'osm_type': osmType,
      };

  /// Deserialize from Nominatim JSON response.
  /// Nominatim returns lat/lng as strings, so we parse.
  factory SearchResultEntity.fromJson(Map<String, dynamic> json) {
    return SearchResultEntity(
      displayName: json['display_name'] as String? ?? '',
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0,
      lng: double.tryParse(json['lng']?.toString() ?? '0') ?? 0,
      osmType: json['osm_type'] as String? ?? 'node',
    );
  }

  @override
  String toString() =>
      'SearchResultEntity(displayName: $displayName, lat: $lat, lng: $lng, osmType: $osmType)';
}
