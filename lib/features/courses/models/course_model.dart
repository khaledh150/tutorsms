class HourPackage {
  final int hours;
  final int price;

  const HourPackage({required this.hours, required this.price});

  factory HourPackage.fromJson(Map<String, dynamic> json) => HourPackage(
        hours: (json['hours'] as num?)?.toInt() ?? 0,
        price: (json['price'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'hours': hours, 'price': price};
}

class Course {
  final String id;
  final String name;
  final List<String> weekdays;
  final Map<String, List<String>> times;
  final int? capacity;
  final String? start;
  final String? end;
  final List<HourPackage> hourPackages;
  final int bookPrice;
  final String? createdAt;

  const Course({
    required this.id,
    required this.name,
    this.weekdays = const [],
    this.times = const {},
    this.capacity,
    this.start,
    this.end,
    this.hourPackages = const [],
    this.bookPrice = 0,
    this.createdAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    final rawTimes = json['times'];
    final Map<String, List<String>> parsedTimes = {};
    if (rawTimes is Map) {
      for (final entry in rawTimes.entries) {
        final key = entry.key as String;
        final value = entry.value;
        if (value is List) {
          parsedTimes[key] = value.cast<String>();
        }
      }
    }

    final rawPackages = json['hour_packages'];
    final List<HourPackage> packages = [];
    if (rawPackages is List) {
      for (final p in rawPackages) {
        if (p is Map<String, dynamic>) {
          packages.add(HourPackage.fromJson(p));
        }
      }
    }

    return Course(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      weekdays: (json['weekdays'] as List?)?.cast<String>() ?? [],
      times: parsedTimes,
      capacity: json['capacity'] as int?,
      start: json['start'] as String?,
      end: json['end'] as String?,
      hourPackages: packages,
      bookPrice: (json['book_price'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'weekdays': weekdays,
        'times': times.map((k, v) => MapEntry(k, v)),
        'capacity': capacity,
        'hour_packages': hourPackages.map((p) => p.toJson()).toList(),
        'book_price': bookPrice,
      };

  Course copyWith({
    String? id,
    String? name,
    List<String>? weekdays,
    Map<String, List<String>>? times,
    int? capacity,
    List<HourPackage>? hourPackages,
    int? bookPrice,
  }) =>
      Course(
        id: id ?? this.id,
        name: name ?? this.name,
        weekdays: weekdays ?? this.weekdays,
        times: times ?? this.times,
        capacity: capacity ?? this.capacity,
        start: start,
        end: end,
        hourPackages: hourPackages ?? this.hourPackages,
        bookPrice: bookPrice ?? this.bookPrice,
        createdAt: createdAt,
      );
}
