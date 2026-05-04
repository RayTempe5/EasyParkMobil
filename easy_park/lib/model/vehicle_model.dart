class Vehicle {
  final int? id;
  final int? userId;
  final int? vehicleTypeId;
  final int? vehicleBrandId;
  final int? vehicleModelId;
  final String plateNumber;
  final String? color;
  final String? vehiclePhoto;   // 'vehicle_photo' sesuai Laravel
  final String? stnkPhoto;      // 'stnk_photo' sesuai Laravel
  final bool isParked;
  final bool isActive;

  // Dari relationship load('type', 'brand', 'model')
  final String? typeName;
  final String? brandName;
  final String? modelName;

  Vehicle({
    this.id,
    this.userId,
    this.vehicleTypeId,
    this.vehicleBrandId,
    this.vehicleModelId,
    required this.plateNumber,
    this.color,
    this.vehiclePhoto,
    this.stnkPhoto,
    this.isParked = false,
    this.isActive = true,
    this.typeName,
    this.brandName,
    this.modelName,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      userId: json['user_id'],
      vehicleTypeId: json['vehicle_type_id'],
      vehicleBrandId: json['vehicle_brand_id'],
      vehicleModelId: json['vehicle_model_id'],
      plateNumber: json['plate_number'] ?? '',
      color: json['color'],
      vehiclePhoto: json['vehicle_photo'],   // path dari storage
      stnkPhoto: json['stnk_photo'],         // path dari storage
      isParked: json['is_parked'] ?? false,
      isActive: json['is_active'] ?? true,

      // Ambil name dari relationship object
      typeName: json['type']?['name'],
      brandName: json['brand']?['name'],
      modelName: json['model']?['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_type_id': vehicleTypeId,
      'vehicle_brand_id': vehicleBrandId,
      'vehicle_model_id': vehicleModelId,
      'plate_number': plateNumber,
      'color': color,
    };
  }
}