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
import 'compare_result.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<PingData> pingData = [];
  List<Map<String, dynamic>> analysisResult = [];
  StreamController<PingData> pingDataController = StreamController<PingData>();
  final List<String> platformDropdownItems = ['Android', 'iOS'];
  List<String> appDropdownItems = [];
  String? selectedPlatform;
  String? selectedApp;
  late Timer _timer;
  final TextEditingController textEditingController = TextEditingController();
  String duration = '';

  @override
  void initState() {
    super.initState();
    // _startPing();
  }

  void _startRecord(String appName) {
    _timer = Timer.periodic(Duration(seconds: 1), (_) async {
      Map<String, double> latency = await _getAndroidPerfData(appName);
      setState(() {
        final ping = PingData(DateTime.now(), latency);
        pingData.add(ping);
        pingDataController.add(ping);
        duration = formatSecondsToTime(pingData.length);
      });
    });
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

  void _stopRecord() {
    _timer.cancel();
    saveToExcel(pingData);
    setState(() {
      analysisResult = get_analysis_value(pingData);
    });
  }

  void _selectRecordAndLoad() async {
    var records = await pickAndLoadFile();
    print(records);
    setState(() {
      pingData = records;
      
      analysisResult = get_analysis_value(records);
      duration = formatSecondsToTime(pingData.length);
    });
  }

  Future<Map<String, double>> _getAndroidPerfData(String appName) async {
    appName = appName.split(':')[1];
    final memoResponse =
        await executeCommand('adb', ['shell', 'dumpsys', 'meminfo', appName]);
    final CPUResponse =
        await executeCommand('adb', ['shell', 'dumpsys', 'cpuinfo']);
    var androidMemo = parseAndroidMemoResponseData(memoResponse);
    var androidCPU = parseAndroidCPUResponseData(CPUResponse);
    return {...androidMemo, ...androidCPU};
  }

  Future<void> getApplist(String platform) async {
    if (platform == 'Android') {
      final response = await executeCommand(
          'adb', ['shell', 'cmd', 'package', 'list', 'packages', '-3']);
      setState(() {
        appDropdownItems =
            response.split('\n'); // Split the response by newline
      });
    }
  }

  @override
  void dispose() {
    pingDataController.close();
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var lineListAndroidMemo = {
      'Total Private Dirty': Colors.blue,
      'Native Private Dirty': Colors.red,
      'Dalvik Private Dirty': Colors.amber,
      'EGL Private Dirty': Colors.deepOrange,
      'GL Private Dirty': Colors.deepPurple,
      'Total Pss': Colors.green,
      'Native Pss': Colors.lightGreen,
      'Dalvik Pss': Colors.lime,
      'EGL Pss': Colors.blueGrey,
      'GL Pss': Colors.brown,
      'Native Heap Allocated Size': Colors.cyan,
      'Native Heap Size': Colors.indigo,
    };
    List<Series<PingData, DateTime>> seriesListAndroidMemo = [];
    for (var entry in lineListAndroidMemo.entries) {
      seriesListAndroidMemo.add(charts.Series<PingData, DateTime>(
        id: entry.key,
        colorFn: (_, __) => charts.ColorUtil.fromDartColor(entry.value),
        domainFn: (PingData data, _) => data.time,
        measureFn: (PingData data, _) => data.latency[entry.key],
        data: pingData,
        // fillColorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
        fillColorFn: (_, __) => charts.ColorUtil.fromDartColor(entry.value),
        radiusPxFn: (PingData data, _) => 5,
        labelAccessorFn: (PingData data, _) => 'labelAccessorFn',
        displayName: "displayName",
      ));
    }

    var lineListAndroidCPU = {
      'User CPU': Colors.blue,
      'Total CPU': Colors.red,
    };
    List<Series<PingData, DateTime>> seriesListAndroidCPU = [];
    


    for (var entry in lineListAndroidCPU.entries) {
      seriesListAndroidCPU.add(charts.Series<PingData, DateTime>(
        id: entry.key,
        colorFn: (_, __) => charts.ColorUtil.fromDartColor(entry.value),
        domainFn: (PingData data, _) => data.time,
        measureFn: (PingData data, _) => data.latency[entry.key],
        data: pingData,
        // fillColorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
        fillColorFn: (_, __) => charts.ColorUtil.fromDartColor(entry.value),
        radiusPxFn: (PingData data, _) => 5,
        labelAccessorFn: (PingData data, _) => 'labelAccessorFn',
        displayName: "displayName",
      ));
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
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.transparent,
                      width: 20.0,
                    ),
                  ),
                  child: Text(
                    'Platform:',
                    style: prefix.TextStyle(
                        fontSize: 36.0, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  // height: 50,
                  // width: MediaQuery.of(context).size.width / 2,
                  margin: EdgeInsets.all(5),
                  child: DropdownButtonHideUnderline(
                    child: GFDropdown(
                      padding: const EdgeInsets.all(5),
                      borderRadius: BorderRadius.circular(5),
                      border: const BorderSide(color: Colors.black12, width: 1),
                      dropdownButtonColor: Colors.transparent,
                      value: selectedPlatform,
                      dropdownColor: Colors.tealAccent,
                      onChanged: (newValue) {
                        setState(() {
                          if (newValue != null) {
                            selectedPlatform = newValue;
                          }
                        });
                        if (newValue != null) {
                          getApplist(newValue);
                        }
                      },
                      items: platformDropdownItems.map((String item) {
                        return DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Container(
                  // height: 50,
                  // width: MediaQuery.of(context).size.width / 2,
                  margin: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    // color: Colors.transparent,
                    border: Border.all(color: Colors.black12, width: 1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton2<String>(
                      isExpanded: true,
                      hint: Text(
                        'Please select the platform first!!',
                        style: prefix.TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          // color: Theme.of(context).hintColor,
                          color: Colors.blueGrey,
                        ),
                      ),
                      items: appDropdownItems
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  item,
                                  style: const prefix.TextStyle(
                                    fontSize: 14,
                                  ),
                                ),
                              ))
                          .toList(),
                      value: selectedApp,
                      onChanged: (value) {
                        setState(() {
                          selectedApp = value as String;
                        });
                      },
                      buttonStyleData: const ButtonStyleData(
                        height: 40,
                        width: 500,
                        // overlayColor:
                        //     MaterialStateProperty.all(Colors.green),
                      ),
                      dropdownStyleData: const DropdownStyleData(
                          // maxHeight: 200,
                          ),
                      menuItemStyleData: const MenuItemStyleData(
                        height: 40,
                      ),
                      dropdownSearchData: DropdownSearchData(
                        searchController: textEditingController,
                        searchInnerWidgetHeight: 50,
                        searchInnerWidget: Container(
                          height: 50,
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 4,
                            right: 8,
                            left: 8,
                          ),
                          child: TextFormField(
                            expands: true,
                            maxLines: null,
                            controller: textEditingController,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              hintText: 'Search for an item...',
                              hintStyle: const prefix.TextStyle(fontSize: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        searchMatchFn: (item, searchValue) {
                          return (item.value.toString().contains(searchValue));
                        },
                      ),
                      //This to clear the search value when you close the menu
                      onMenuStateChange: (isOpen) {
                        if (!isOpen) {
                          textEditingController.clear();
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: 40, // Set the desired height
                  child: TextButton(
                    style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.resolveWith((states) {
                        return Colors.blue[200];
                      }),
                      overlayColor: MaterialStateProperty.resolveWith((states) {
                        // If the button is pressed, return green, otherwise blue
                        if (states.contains(MaterialState.pressed)) {
                          return Colors.green;
                        }
                        return Colors.green[300];
                      }),
                    ),
                    onPressed: () {
                      print("selectd app is $selectedApp");
                      _startRecord(selectedApp!);
                    },
                    child: Text('Start Recordings'),
                  ),
                ),
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
                      _stopRecord();
                    },
                    child: Text('Stop Recordings'),
                  ),
                ),
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
                      _selectRecordAndLoad();
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CompareHistory()),
                        );
                      },
                      child: Text('Go to Second Page'),
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
                      DataTable(
                        border: TableBorder.all(color: Colors.lightGreenAccent),
                        columns: [
                          DataColumn(label: Text('Item')),
                          DataColumn(label: Text('Max')),
                          DataColumn(label: Text('Min')),
                          DataColumn(label: Text('Avg')),
                        ],
                        rows: analysisResult.map((item) {
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
