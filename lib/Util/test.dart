void main() {
  DateTime dateTimeFromMicroseconds = DateTime.fromMicrosecondsSinceEpoch(0);
  print(dateTimeFromMicroseconds);
  dateTimeFromMicroseconds = dateTimeFromMicroseconds.add(Duration(seconds: 1));
  print(dateTimeFromMicroseconds);
  dateTimeFromMicroseconds = dateTimeFromMicroseconds.add(Duration(seconds: 1));
  print(dateTimeFromMicroseconds);
  dateTimeFromMicroseconds = dateTimeFromMicroseconds.add(Duration(seconds: 1));
  print(dateTimeFromMicroseconds);
}