class HistoryData {
  final String fileName;
  final Map<String, List<dynamic>> item;

  HistoryData(this.fileName, this.item);

  @override
  String toString() {
    return 'HistoryData{fileName: $fileName, item: $item}';
  }

}