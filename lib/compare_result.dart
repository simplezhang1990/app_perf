import 'dart:async';
import 'dart:io';
// import 'dart:math';
import 'package:App_performance_monitor/Util/commonWidget.dart';
import 'package:flutter/src/painting/text_style.dart' as prefix;
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:charts_flutter/flutter.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'Util/PingData.dart';
import 'Util/util.dart';
import 'main copy.dart';

class CompareHistory extends StatefulWidget {
  @override
  _CompareHistoryState createState() => _CompareHistoryState();
}

class _CompareHistoryState extends State<CompareHistory> {
  List<MaterialColor> colorList = [
    Colors.blue,
    Colors.red,
    Colors.amber,
    Colors.deepOrange,
    Colors.deepPurple,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.blueGrey,
    Colors.brown,
    Colors.cyan,
    Colors.indigo,
  ];
  List<PingData> pingData = [];
  List<List<PingData>> histories = [];
  List<Map<String, dynamic>> memoAnalysisResult = [];
  List<Map<String, dynamic>> cpuAnalysisResult = [];
  StreamController<PingData> pingDataController = StreamController<PingData>();

  String duration = '';

  @override
  void initState() {
    super.initState();
  }

  String formatSecondsToTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;

    String hoursStr = (hours < 10) ? '0$hours' : '$hours';
    String minutesStr = (minutes < 10) ? '0$minutes' : '$minutes';
    String secondsStr =
        (remainingSeconds < 10) ? '0$remainingSeconds' : '$remainingSeconds';

    return '$hoursStr:$minutesStr:$secondsStr';
  }

  void _selectRecordsAndLoad() async {
    var records = await pickHistoryAndLoadFiles(true);
    setState(() {
      histories = parseTheHistoryData(records);
      memoAnalysisResult = get_analysis_value_for_compare(histories[0]);
      cpuAnalysisResult = get_analysis_value_for_compare(histories[1]);
      duration = formatSecondsToTime(histories[0].length);
    });
  }

  @override
  void dispose() {
    pingDataController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var lineListAndroidMemo = {};
    List<Series<PingData, DateTime>> seriesListAndroidMemo = [];
    List<PingData> MemoData = [];
    int colorIndex = 0;
    if (histories.length > 0) {
      MemoData = histories[0];
      print('=============================');
      print(MemoData);
      for (var key in MemoData[0].latency.keys) {
        lineListAndroidMemo[key] = colorList[colorIndex++];
      }
      for (var entry in lineListAndroidMemo.entries) {
        seriesListAndroidMemo.add(charts.Series<PingData, DateTime>(
          id: entry.key,
          colorFn: (_, __) => charts.ColorUtil.fromDartColor(entry.value),
          domainFn: (PingData data, _) => data.time,
          measureFn: (PingData data, _) => data.latency[entry.key],
          data: MemoData,
          // fillColorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
          fillColorFn: (_, __) => charts.ColorUtil.fromDartColor(entry.value),
          radiusPxFn: (PingData data, _) => 5,
          labelAccessorFn: (PingData data, _) => 'labelAccessorFn',
          displayName: "displayName",
        ));
      }
    }

    var lineListAndroidCPU = {};
    List<Series<PingData, DateTime>> seriesListAndroidCPU = [];
    List<PingData> CPUData = [];
    colorIndex = 0;
    if (histories.length > 0) {
      CPUData = histories[1];
      for (var key in CPUData[0].latency.keys) {
        lineListAndroidCPU[key] = colorList[colorIndex++];
      }

      for (var entry in lineListAndroidCPU.entries) {
        seriesListAndroidCPU.add(charts.Series<PingData, DateTime>(
          id: entry.key,
          colorFn: (_, __) => charts.ColorUtil.fromDartColor(entry.value),
          domainFn: (PingData data, _) => data.time,
          measureFn: (PingData data, _) => data.latency[entry.key],
          data: CPUData,
          // fillColorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
          fillColorFn: (_, __) => charts.ColorUtil.fromDartColor(entry.value),
          radiusPxFn: (PingData data, _) => 5,
          labelAccessorFn: (PingData data, _) => 'labelAccessorFn',
          displayName: "displayName",
        ));
      }
    }

    return MaterialApp(
      title: "App performance monitor",
      debugShowCheckedModeBanner: true,
      home: Scaffold(
        appBar: AppBar(title: Text('App Perfoamce Monitor')),
        body: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  height: 40, // Set the desired height
                  child: TextButton(
                    style: ButtonStyle(
                      overlayColor: MaterialStateProperty.resolveWith((states) {
                        // If the button is pressed, return green, otherwise blue
                        if (states.contains(MaterialState.pressed)) {
                          return Colors.green;
                        }
                        return Colors.lime;
                      }),
                    ),
                    onPressed: () {
                      _selectRecordsAndLoad();
                    },
                    child: Text('Load history'),
                  ),
                ),
                SizedBox(
                  height: 40, // Set the desired height
                  child: Builder(
                    builder: (context) => TextButton(
                      onPressed: () {
                        // Use the context provided by the Builder widget.
                        Navigator.pop(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CompareHistory()),
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => MyApp()),
                        );
                      },
                      child: Text('Back to first page'),
                    ),
                  ),
                ),
              ],
            ),
            Divider(
              color: Colors.blueAccent, //color of divider
              height: 5, //height spacing of divider
              thickness: 3, //thickness of divier line
              indent: 5, //spacing at the start of divider
              endIndent: 5, //spacing at the end of divider
            ),
            IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        margin: EdgeInsets.all(30.0),
                        child: SizedBox(
                          width: 1000,
                          height: 250,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: charts.TimeSeriesChart(
                                  seriesListAndroidMemo,
                                  animate: true,
                                  behaviors: [
                                    charts.ChartTitle('Time($duration)',
                                        behaviorPosition:
                                            charts.BehaviorPosition.bottom),
                                    charts.ChartTitle(
                                        'Memory Information (Byte)',
                                        behaviorPosition:
                                            charts.BehaviorPosition.start),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:
                                    lineListAndroidMemo.entries.map((entry) {
                                  String key = entry.key;
                                  MaterialColor color = entry.value;
                                  return Row(
                                    children: [
                                      Container(
                                        color: color,
                                        height: 10,
                                        width: 10,
                                      ),
                                      Text(key),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.all(30.0),
                        child: SizedBox(
                          width: 1000,
                          height: 250,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: charts.TimeSeriesChart(
                                  seriesListAndroidCPU,
                                  animate: true,
                                  behaviors: [
                                    charts.ChartTitle('Time($duration)',
                                        behaviorPosition:
                                            charts.BehaviorPosition.bottom),
                                    charts.ChartTitle('CPU Information (%)',
                                        behaviorPosition:
                                            charts.BehaviorPosition.start),
                                  ],
                                  // domainAxis: new charts.EndPointsTimeAxisSpec(),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:
                                    lineListAndroidCPU.entries.map((entry) {
                                  String key = entry.key;
                                  MaterialColor color = entry.value;
                                  return Row(
                                    children: [
                                      Container(
                                        color: color,
                                        height: 10,
                                        width: 10,
                                      ),
                                      Text(key),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const VerticalDivider(
                    width: 20,
                    thickness: 3.0,
                    indent: 5,
                    endIndent: 5,
                    color: Colors.blueAccent,
                  ),
                  Column(
                    children: [
                      Text(
                        'Result analysis',
                        style: prefix.TextStyle(
                            fontSize: 36.0, fontWeight: FontWeight.bold),
                      ),
                      Divider(
                        color: Colors.blueAccent, //color of divider
                        height: 5, //height spacing of divider
                        thickness: 3, //thickness of divier line
                        indent: 5, //spacing at the start of divider
                        endIndent: 5, //spacing at the end of divider
                      ),
                      Text(
                        'Memory',
                        style: prefix.TextStyle(
                            fontSize: 25.0, fontWeight: FontWeight.bold),
                      ),
                      Divider(
                        color: Colors.blueAccent, //color of divider
                        height: 5, //height spacing of divider
                        thickness: 3, //thickness of divier line
                        indent: 5, //spacing at the start of divider
                        endIndent: 5, //spacing at the end of divider
                      ),
                      DataTable(
                        border: TableBorder.all(color: Colors.lightGreenAccent),
                        columns: [
                          DataColumn(label: Text('Item')),
                          DataColumn(label: Text('Max')),
                          DataColumn(label: Text('Min')),
                          DataColumn(label: Text('Avg')),
                        ],
                        rows: memoAnalysisResult.map((item) {
                          return DataRow(cells: [
                            DataCell(Text(item.keys.elementAt(0))),
                            DataCell(Text(
                                item.values.elementAt(0)['Max'].toString())),
                            DataCell(Text(
                                item.values.elementAt(0)['Min'].toString())),
                            DataCell(Text(item.values
                                .elementAt(0)['Average']
                                .toStringAsFixed(1))),
                            // Add more DataCell widgets as per your API response
                          ]);
                        }).toList(),
                      ),
                      Divider(),
                      Text(
                        'CPU',
                        style: prefix.TextStyle(
                            fontSize: 25.0, fontWeight: FontWeight.bold),
                      ),
                      Divider(
                        color: Colors.blueAccent, //color of divider
                        height: 5, //height spacing of divider
                        thickness: 3, //thickness of divier line
                        indent: 5, //spacing at the start of divider
                        endIndent: 5, //spacing at the end of divider
                      ),
                      DataTable(
                        border: TableBorder.all(color: Colors.lightGreenAccent),
                        columns: [
                          DataColumn(label: Text('Item')),
                          DataColumn(label: Text('Max')),
                          DataColumn(label: Text('Min')),
                          DataColumn(label: Text('Avg')),
                        ],
                        rows: cpuAnalysisResult.map((item) {
                          return DataRow(cells: [
                            DataCell(Text(item.keys.elementAt(0))),
                            DataCell(Text(
                                item.values.elementAt(0)['Max'].toString())),
                            DataCell(Text(
                                item.values.elementAt(0)['Min'].toString())),
                            DataCell(Text(item.values
                                .elementAt(0)['Average']
                                .toStringAsFixed(1))),
                            // Add more DataCell widgets as per your API response
                          ]);
                        }).toList(),
                      ),
                      Divider(),
                    ],
                  ),
                ],
              ),
            ),
            // StreamBuilder<PingData>(
            //   stream: pingDataController.stream,
            //   builder: (context, snapshot) {
            //     if (snapshot.hasData) {
            //       return Text(
            //           'Latest : ${snapshot.data!.latency.toString()} byte');
            //     } else {
            //       return Text('No data');
            //     }
            //   },
            // ),
            Divider(
              color: Colors.blueAccent, //color of divider
              height: 5, //height spacing of divider
              thickness: 3, //thickness of divier line
              indent: 5, //spacing at the start of divider
              endIndent: 5, //spacing at the end of divider
            ),
            StreamBuilder<PingData>(
              stream: pingDataController.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                      'Latest : ${snapshot.data!.latency.toString()} byte');
                } else {
                  return Text('No data');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
