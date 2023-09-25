class PingData {
  final DateTime time;
  final Map<String, double> latency;

  PingData(this.time, this.latency);

  @override
  String toString() {
    // TODO: implement toString
    return 'PingData{DateTime: $time, latency: $latency}';
  }

}