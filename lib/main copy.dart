import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:charts_flutter/flutter.dart';
import 'package:charts_flutter/src/text_element.dart' as element;
import 'package:charts_flutter/src/text_element.dart' as chartsTextElement;
import 'package:charts_flutter/src/text_style.dart' as style;
import 'package:flutter/src/painting/text_style.dart' as prefix;
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import 'package:process_run/shell.dart';

void main() {
  runApp(MyApp());
}

Future<String> executeCommand(String executable, List<String> arguments) async {
  var result = await Process.run(executable, arguments);
  // print("result:"+result.outText);
  return result.outText;
}

class PingData {
  final DateTime time;
  final Map<String, int> latency;

  PingData(this.time, this.latency);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

typedef GetText = String Function();

class TextSymbolRenderer extends CircleSymbolRenderer {
  TextSymbolRenderer(this.getText,
      {this.marginBottom = 8, this.padding = const EdgeInsets.all(8)});

  final GetText getText;
  final double marginBottom;
  final EdgeInsets padding;

  @override
  void paint(ChartCanvas canvas, Rectangle<num> bounds,
      {List<int>? dashPattern,
      Color? fillColor,
      FillPatternType? fillPattern,
      Color? strokeColor,
      double? strokeWidthPx}) {
    super.paint(canvas, bounds,
        dashPattern: dashPattern,
        fillColor: fillColor,
        fillPattern: fillPattern,
        strokeColor: strokeColor,
        strokeWidthPx: strokeWidthPx);

    style.TextStyle textStyle = style.TextStyle();
    textStyle.color = Color.black;
    textStyle.fontSize = 15;

    element.TextElement textElement =
        element.TextElement(getText.call(), style: textStyle);
    double width = textElement.measurement.horizontalSliceWidth;
    double height = textElement.measurement.verticalSliceWidth;

    double centerX = bounds.left + bounds.width / 2;
    double centerY = bounds.top +
        bounds.height / 2 -
        marginBottom -
        (padding.top + padding.bottom);

    canvas.drawRRect(
      Rectangle(
        centerX - (width / 2) - padding.left,
        centerY - (height / 2) - padding.top,
        width + (padding.left + padding.right),
        height + (padding.top + padding.bottom),
      ),
      fill: Color.white,
      radius: 16,
      roundTopLeft: true,
      roundTopRight: true,
      roundBottomRight: true,
      roundBottomLeft: true,
    );
    canvas.drawText(
      textElement,
      (centerX - (width / 2)).round(),
      (centerY - (height / 2)).round(),
    );
  }
}

class CustomCircleSymbolRenderer extends charts.CircleSymbolRenderer {
  @override
  void paint(charts.ChartCanvas canvas, Rectangle<num> bounds,
      {List<int>? dashPattern,
      charts.Color? fillColor,
      FillPatternType? fillPattern,
      charts.Color? strokeColor,
      double? strokeWidthPx}) {
    super.paint(canvas, bounds,
        dashPattern: dashPattern,
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidthPx: strokeWidthPx);

    final pointRadius = 5.0;
    final center =
        Point(bounds.left + bounds.width / 2, bounds.top + bounds.height / 2);

    canvas.drawPoint(
      radius: pointRadius,
      fill: fillColor!,
      stroke: strokeColor!,
      strokeWidthPx: strokeWidthPx!,
      point: center,
    );

    final textStyle = style.TextStyle();
    textStyle.color = charts.Color.black;
    textStyle.fontSize = 12;

    final label =
        '(${bounds.left.toStringAsFixed(2)}, ${bounds.top.toStringAsFixed(2)})';
    canvas.drawText(
      chartsTextElement.TextElement(label, style: textStyle),
      (center.x).round(),
      (center.y - pointRadius - 4).round(),
    );
  }
}

Map<String, int> parseAndroidResponseData(String response) {
  var perfMap = Map<String, int>();
  var list = response.split('\n');
  perfMap['Total Native Heap'] = int.parse(list[7].split(RegExp(r'\s+'))[3]);
  perfMap['Total Dalvik Heap'] = int.parse(list[8].split(RegExp(r'\s+'))[3]);
  perfMap['Total'] = int.parse(list[24].split(RegExp(r'\s+'))[2]);
  return perfMap;
}

class _MyAppState extends State<MyApp> {
  List<PingData> pingData = [];
  StreamController<PingData> pingDataController = StreamController<PingData>();
  final List<String> platformDropdownItems = ['Android', 'iOS'];
  List<String> appDropdownItems = ['Please select the platform first!'];
  String? selectedPlatform;
  String? selectedApp;
  late Timer _timer;
  final TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // _startPing();
  }

  void _startRecord(String appName) {
    _timer = Timer.periodic(Duration(seconds: 1), (_) async {
      Map<String, int> latency = await _getPerfData(appName);
      setState(() {
        // final ping = PingData(DateTime.now(), Random().nextDouble() * 100.0);
        final ping = PingData(DateTime.now(), latency);
        // print("pingData:"+ping.latency.toString());
        pingData.add(ping);
        pingDataController.add(ping);
      });
    });
  }

  void _stopRecord(){
    _timer.cancel();
    print('pingData: '+pingData.toString());
  }

  Future<Map<String, int>> _getPerfData(String appName) async {
    appName = appName.split(':')[1];
    final response =
        await executeCommand('adb', ['shell', 'dumpsys', 'meminfo', appName]);
    return parseAndroidResponseData(response);
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
    final seriesList = [
      charts.Series<PingData, DateTime>(
        id: 'Total Native Heap',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (PingData data, _) => data.time,
        measureFn: (PingData data, _) => data.latency['Total Native Heap'],
        data: pingData,
        fillColorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
        radiusPxFn: (PingData data, _) => 5,
      ),
      charts.Series<PingData, DateTime>(
        id: 'Total Dalvik Heap',
        colorFn: (_, __) => charts.MaterialPalette.pink.shadeDefault,
        domainFn: (PingData data, _) => data.time,
        measureFn: (PingData data, _) => data.latency['Total Dalvik Heap'],
        data: pingData,
        fillColorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
        radiusPxFn: (PingData data, _) => 5,
      ),
      charts.Series<PingData, DateTime>(
        id: 'Total',
        colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
        domainFn: (PingData data, _) => data.time,
        measureFn: (PingData data, _) => data.latency['Total'],
        data: pingData,
        fillColorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
        radiusPxFn: (PingData data, _) => 5,
      ),
    ];

    return MaterialApp(
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
                        'Select Item',
                        style: prefix.TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).hintColor,
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
                      overlayColor: MaterialStateProperty.resolveWith((states) {
                        // If the button is pressed, return green, otherwise blue
                        if (states.contains(MaterialState.pressed)) {
                          return Colors.green;
                        }
                        return Colors.lime;
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
              ],
            ),
            Expanded(
              child: charts.TimeSeriesChart(
                seriesList,
                animate: true,
                // defaultRenderer:
                //           new charts.LineRendererConfig(layoutPaintOrder: LayoutViewPaintOrder.domainAxis),

                behaviors: [
                  charts.ChartTitle('Time',
                      behaviorPosition: charts.BehaviorPosition.bottom),
                  charts.ChartTitle('Value',
                      behaviorPosition: charts.BehaviorPosition.start),
                ],
              ),
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
