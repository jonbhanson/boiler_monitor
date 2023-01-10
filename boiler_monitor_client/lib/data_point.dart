class DataPoint implements Comparable {
  DateTime dateTime;
  int? temperature;
  bool? isTemporary;

  DataPoint({required this.dateTime, required this.temperature, this.isTemporary});

  @override
  int compareTo(other) {
    if (other is DataPoint) {
      return dateTime.compareTo(other.dateTime);
    }
    return 0;
  }

  DataPoint copyWith({DateTime? dateTime, bool? isTemporary, int? temperature}) {
    return DataPoint(
      dateTime: dateTime ?? this.dateTime,
      temperature: temperature ?? this.temperature,
      isTemporary: isTemporary ?? this.isTemporary,
    );
  }
}

class StatePoint implements Comparable {
  DateTime dateTime;
  String type;

  StatePoint({
    required this.dateTime,
    required this.type,
  });

  @override
  int compareTo(other) => (other is StatePoint) ? dateTime.compareTo(other.dateTime) : 0;
}
