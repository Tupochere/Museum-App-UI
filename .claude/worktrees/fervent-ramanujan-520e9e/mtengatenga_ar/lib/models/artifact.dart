class Artifact {
  const Artifact({
    required this.id,
    required this.name,
    this.description,
    this.model3dUrl,
    this.qrCode,
    this.category,
    this.period,
  });

  final String id;
  final String name;
  final String? description;
  final String? model3dUrl;
  final String? qrCode;
  final String? category;
  final String? period;

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Artifact').toString(),
      description: _asNullableString(json['description']),
      model3dUrl:
          _asNullableString(json['model_3d_url']) ??
          _asNullableString(json['model3dUrl']),
      qrCode:
          _asNullableString(json['qr_code']) ??
          _asNullableString(json['qrCode']),
      category: _asNullableString(json['category']),
      period: _asNullableString(json['period']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'model_3d_url': model3dUrl,
      'qr_code': qrCode,
      'category': category,
      'period': period,
    };
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }
}
