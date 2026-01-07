class SavedPlace {
  final String id;
  final String title;
  final String address;
  final double lat;
  final double lng;
  final String icon;

  SavedPlace({
    required this.id,
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
    required this.icon,
  });

  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    return SavedPlace(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      address: json['address'] ?? '',
      lat: double.tryParse(json['lat'].toString()) ?? 0.0,
      lng: double.tryParse(json['lng'].toString()) ?? 0.0,
      icon: json['icon'] ?? 'place',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'address': address,
      'lat': lat,
      'lng': lng,
      'icon': icon,
    };
  }
}
