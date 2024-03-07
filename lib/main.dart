import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:App_performance_monitor/Util/commonWidget.dart';
import 'package:flutter/src/painting/text_style.dart' as prefix;
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:charts_flutter/flutter.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:path_provider/path_provider.dart';
import 'Util/PingData.dart';
import 'Util/util.dart';
import 'compare_result.dart';
import 'package:cross_scroll/cross_scroll.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import "package:path/path.dart" show dirname,join;

void main() {
  // runApp(const HomeApp());
  runApp(const HomeApp());
}


class HomeApp extends StatefulWidget {
  const HomeApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<HomeApp> {
  List<PingData> pingData = [];
  List<Map<String, dynamic>> analysisResult = [];
  StreamController<PingData> pingDataController = StreamController<PingData>();
  final List<String> platformDropdownItems = ['Android', 'iOS'];
  List<String> appDropdownItems = [];
  String? selectedPlatform;
  String? selectedApp;
  late Timer _timer;
  var iOSProcessPID;
  final TextEditingController textEditingController = TextEditingController();
  String duration = '';
  var appListHint = 'Please select the platform first!!';

  @override
  void initState() {
    super.initState();
    // _startPing();
    
  }

  void _startRecord(String appName) {
    if (selectedPlatform == 'Android') {
      _timer = Timer.periodic(Duration(seconds: 1), (_) async {
        Map<String, double> latency = {};
        latency = await _getAndroidPerfData(appName);

        setState(() {
          final ping = PingData(DateTime.now(), latency);
          pingData.add(ping);
          pingDataController.add(ping);
          duration = formatSecondsToTime(pingData.length);
        });
      });
    } else {
      _getiOSPerfData(appName);
    }
  }

  _onBasicAlertPressed(context)  async {
    if (selectedPlatform == null) {
      Map<String, String> envVars = Platform.environment;
      var filePath = join(envVars['HOME']!,'perfConfig.json');
      File file=File(filePath);
      final data = await json.decode(await file.readAsString());
      print(data);
      print(data['adbPath']);
      customer_alert(
          context, data['adbPath'], AlertType.error);
    } else {
      customer_alert(context, 'The selected platform is $selectedPlatform',
          AlertType.info);
    }
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

  void _stopRecord() async {
    if (selectedPlatform == 'Android') {
      _timer.cancel();
    } else {
      print('tr to stop');
      print(iOSProcessPID);
      Process.killPid(iOSProcessPID);
      // var exitCode = await iOSProcess.exitCode;
    }
    saveToExcel(pingData, selectedPlatform!);
    setState(() {
      if (selectedPlatform == 'Android') {
        analysisResult = get_analysis_value(pingData, 'Total Pss', 'Total CPU');
      } else {
        analysisResult =
            get_analysis_value(pingData, 'memory', 'cpu', platform: 'iOS');
      }
    });
  }

  void _selectRecordAndLoad(context) async {
    if (selectedPlatform == null) {
      customer_alert(
          context, 'Please select the platform first!!!', AlertType.error);
      return;
    }
    var records = await pickAndLoadFile(selectedPlatform!, context);
    if (records.isEmpty) {
      return;
    }
    print(records);
    setState(() {
      pingData = records;

      if (selectedPlatform == 'Android') {
        analysisResult = get_analysis_value(pingData, 'Total Pss', 'Total CPU');
      } else {
        analysisResult =
            get_analysis_value(pingData, 'memory', 'cpu', platform: 'iOS');
      }
      duration = formatSecondsToTime(pingData.length);
    });
  }

  Future<Map<String, double>> _getAndroidPerfData(String appName) async {
    appName = appName.split(':')[1];
    final memoResponse =
        await executeCommand('adb shell dumpsys meminfo $appName',context);
    final CPUResponse =
        await executeCommand('adb shell dumpsys cpuinfo',context);
    var androidMemo = parseAndroidMemoResponseData(memoResponse);
    var androidCPU = parseAndroidCPUResponseData(CPUResponse);
    return {...androidMemo, ...androidCPU};
  }

  Future<void> _getiOSPerfData(String appName) async {
    executeCommandForIOS('tidevice', ['perf', '-B', appName, '--json']);
  }

  Future<void> executeCommandForIOS(
      String executable, List<String> arguments) async {
    var iOSProcess =
        await Process.start(executable, arguments, runInShell: true);
    iOSProcessPID = iOSProcess.pid;
    // print("result:"+result.outText);
    var list = {};
    iOSProcess.stdout.transform(utf8.decoder).forEach((test) {
      if (test.startsWith('cpu') || test.startsWith('memory')) {
        print('============ start ============');
        var responseList = test.split('\n');
        for (var line in responseList) {
          if (line.startsWith('cpu')) {
            var sourceValue =
                json.decode(line.substring('cpu'.length + 1, line.length));
            list['timestamp'] = sourceValue['timestamp'];
            list['cpu'] = sourceValue['value'];
          }
          if (line.startsWith('memory')) {
            var sourceValue =
                json.decode(line.substring('memory'.length + 1, line.length));
            list['memory'] = sourceValue['value'];
          }

          if (list.keys.length > 2) {
            print(list);
            setState(() {
              var time = DateTime.fromMillisecondsSinceEpoch(list['timestamp']);
              list.remove('timestamp');
              Map<String, double> latency = {};
              for (var key in list.keys) {
                latency[key] = list[key];
              }
              var ping = PingData(time, latency);

              print('=====print ping======');
              print(ping);
              pingData.add(ping);
              pingDataController.add(ping);
              duration = formatSecondsToTime(pingData.length);
            });
            list = {};
          }
        }

        print('************* end ************');
      }
    });
  }

  Future<void> getApplist(String platform,context) async {
    if (platform == 'Android') {
      final response = await executeCommand(
          'adb shell cmd package list packages -3', context);
      print('dsdsd**************');
      print(response.contains('no devices/emulators found'));

      setState(() {
        if (response.contains('no devices/emulators found')) {
          appListHint = 'No devices/emulators found';
          print(appListHint);
        } else {
          appListHint = 'Please select the testing app';
          appDropdownItems =
              response.split('\n'); // Split the response by newline
        }
      });
    } else {
      final response = await executeCommand('tidevice applist',context);
      print('**************');
      print(response);
      var appList = response.split('\n');
      for (int i = 0; i < appList.length; i++) {
        appList[i] = appList[i].split(' ')[0];
      }
      setState(() {
        if (response.contains('No local device')) {
          appListHint = 'No devices/emulators found';
          print(appListHint);
        } else {
          appListHint = 'Please select the testing app';
          appDropdownItems = appList;
        } // Split the response by newline
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
    List<Series<PingData, DateTime>> seriesListMemo = [];
    List<Series<PingData, DateTime>> seriesListCPU = [];
    Map<String, MaterialColor> lineListMemo = {};
    Map<String, MaterialColor> lineListCPU = {};

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

    var lineListiOSMemo = {'Memory': Colors.blue};

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

    List<Series<PingData, DateTime>> seriesListiOSMemo = [];
    seriesListiOSMemo.add(charts.Series<PingData, DateTime>(
      id: 'Memory',
      // colorFn: (_, __) => charts.ColorUtil.fromDartColor(entry.value),
      domainFn: (PingData data, _) => data.time,
      measureFn: (PingData data, _) => data.latency['memory'],
      data: pingData,
      // fillColorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
      // fillColorFn: (_, __) => charts.ColorUtil.fromDartColor(entry.value),
      radiusPxFn: (PingData data, _) => 5,
      labelAccessorFn: (PingData data, _) => 'labelAccessorFn',
      displayName: "displayName",
    ));

    List<Series<PingData, DateTime>> seriesListiOSCPU = [];
    seriesListiOSCPU.add(charts.Series<PingData, DateTime>(
      id: 'seriesListiOSCPU',
      // colorFn: (_, __) => charts.ColorUtil.fromDartColor(entry.value),
      domainFn: (PingData data, _) => data.time,
      measureFn: (PingData data, _) => data.latency['cpu'],
      data: pingData,
      // fillColorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
      // fillColorFn: (_, __) => charts.ColorUtil.fromDartColor(entry.value),
      radiusPxFn: (PingData data, _) => 5,
      labelAccessorFn: (PingData data, _) => 'labelAccessorFn',
      displayName: "displayName",
    ));

    var lineListAndroidCPU = {
      'User CPU': Colors.blue,
      'Total CPU': Colors.red,
    };

    var lineListiOSCPU = {
      'User CPU': Colors.blue,
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

    if (selectedPlatform == 'Android') {
      seriesListCPU = seriesListAndroidCPU;
      seriesListMemo = seriesListAndroidMemo;
      lineListMemo = lineListAndroidMemo;
      lineListCPU = lineListAndroidCPU;
    } else {
      seriesListCPU = seriesListiOSCPU;
      seriesListMemo = seriesListiOSMemo;
      lineListMemo = lineListiOSMemo;
      lineListCPU = lineListiOSCPU;
    }

    return MaterialApp(
      title: "App performance monitor",
      debugShowCheckedModeBanner: true,
      home: Scaffold(
        appBar: AppBar(title: Text('App Perfoamce Monitor')),
        body: CrossScroll(
          child: Column(
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
                    child: Builder(
                      builder: (context) {
                        return DropdownButtonHideUnderline(
                          child: GFDropdown(
                            padding: const EdgeInsets.all(5),
                            borderRadius: BorderRadius.circular(5),
                            border:
                                const BorderSide(color: Colors.black12, width: 1),
                            dropdownButtonColor: Colors.transparent,
                            value: selectedPlatform,
                            dropdownColor: Colors.tealAccent,
                            onChanged: (newValue) async {
                              setState(() {
                                if (newValue != null) {
                                  selectedPlatform = newValue;
                                }
                              });
                              if (newValue != null) {
                                try {
                                  getApplist(newValue,context);
                                } on Exception catch (e) {
                                  customer_alert(
                                      context,
                                      'Exception: $e',
                                      AlertType.error);
                                }
                              }
                            },
                            items: platformDropdownItems.map((String item) {
                              return DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              );
                            }).toList(),
                          ),
                        );
                      }
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
                          appListHint,
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
                            return (item.value
                                .toString()
                                .contains(searchValue));
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
                        overlayColor:
                            MaterialStateProperty.resolveWith((states) {
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
                        overlayColor:
                            MaterialStateProperty.resolveWith((states) {
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
                    child: Builder(builder: (context) {
                      return TextButton(
                        style: ButtonStyle(
                          overlayColor:
                              MaterialStateProperty.resolveWith((states) {
                            // If the button is pressed, return green, otherwise blue
                            if (states.contains(MaterialState.pressed)) {
                              return Colors.green;
                            }
                            return Colors.lime;
                          }),
                        ),
                        onPressed: () {
                          _selectRecordAndLoad(context);
                        },
                        child: Text('Load history'),
                      );
                    }),
                  ),
                  SizedBox(
                    height: 40, // Set the desired height
                    child: Builder(
                      builder: (context) => TextButton(
                        onPressed: () {
                          // Use the context provided by the Builder widget.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => CompareHistory()),
                          );
                        },
                        child: Text('Go to Second Page'),
                      ),
                    ),
                  ),
                  // SizedBox(
                  //   height: 40, // Set the desired height
                  //   child: Builder(
                  //     builder: (context) => TextButton(
                  //       onPressed: () {
                  //         // Use the context provided by the Builder widget.
                  //         _onBasicAlertPressed(context);
                  //       },
                  //       child: Text('Alert test'),
                  //     ),
                  //   ),
                  // ),
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
                                    seriesListMemo,
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
                                  children: lineListMemo.entries.map((entry) {
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
                                    seriesListCPU,
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
                                  children: lineListCPU.entries.map((entry) {
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
                          border:
                              TableBorder.all(color: Colors.lightGreenAccent),
                          columns: [
                            DataColumn(label: Text('Item')),
                            DataColumn(label: Text('Max')),
                            DataColumn(label: Text('Min')),
                            DataColumn(label: Text('Avg')),
                          ],
                          rows: analysisResult.map((item) {
                            return DataRow(cells: [
                              DataCell(Text(item.keys.elementAt(0))),
                              DataCell(Text(item.values
                                  .elementAt(0)['Max']
                                  .toStringAsFixed(2))),
                              DataCell(Text(item.values
                                  .elementAt(0)['Min']
                                  .toStringAsFixed(2))),
                              DataCell(Text(item.values
                                  .elementAt(0)['Average']
                                  .toStringAsFixed(2))),
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
      ),
    );
  }
}
