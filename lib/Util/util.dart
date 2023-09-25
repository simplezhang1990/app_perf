import 'dart:io';
import 'dart:math';
import 'package:App_performance_monitor/Util/HistoryData.dart';
import 'package:process_run/shell.dart';
import 'package:collection/collection.dart';
import 'PingData.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

List<String> rowList = [
  'Total Private Dirty',
  'Native Private Dirty',
  'Dalvik Private Dirty',
  'EGL Private Dirty',
  'GL Private Dirty',
  'Total Pss',
  'Native Pss',
  'Dalvik Pss',
  'EGL Pss',
  'GL Pss',
  'Native Heap Allocated Size',
  'Native Heap Size',
  'User CPU',
  'Total CPU'
];

void saveToExcel(List<PingData> list) async {
  var excelTmp = excel.Excel.createExcel();
  var sheetName = 'Sheet1';
  var sheet = excelTmp[sheetName];

  // Add headers
  sheet.appendRow(['Time'] + rowList);

  // Add data rows
  list.forEach((element) {
    List<dynamic> rowValues = [];
    rowValues.add(element.time.toString());
    rowList.forEach((item) {
      rowValues.add(element.latency[item]!);
    });

    sheet.appendRow(rowValues);
    // sheet.appendRow([
    //   element.time.toString(),
    //   rowValues,
    // ]);
  });
  // Get the temporary directory or application documents directory
  Directory? directory = await getApplicationDocumentsDirectory();

  String folderName = 'performance_data';
  String fileName =
      DateTime.now().toString().replaceAll(" ", '-').replaceAll(":", '-');
  String filePath = '${directory.path}/$folderName/$fileName.xlsx';

  // Create the folder if it doesn't exist
  Directory folder = Directory('${directory.path}/$folderName');
  if (!folder.existsSync()) {
    folder.createSync(recursive: true);
  }

  // Save the Excel file
  var file = File(filePath);
  await file.writeAsBytes(excelTmp.save()!);

  print('Excel file saved at: $filePath');
}

List<Map<String, dynamic>> get_analysis_value(List<PingData> list) {
  List<Map<String, dynamic>> analysis_list = [];
  var memo_average = list.map((m) => m.latency['Total Pss']!).average;
  var memo_max = list.map((m) => m.latency['Total Pss']!).max;
  var memo_min = list.map((m) => m.latency['Total Pss']!).min;
  var cpu_average = list.map((m) => m.latency['Total CPU']!).average;
  var cpu_max = list.map((m) => m.latency['Total CPU']!).max;
  var cpu_min = list.map((m) => m.latency['Total CPU']!).min;
  analysis_list.add({
    'Memo(Byte)': {'Max': memo_max, 'Min': memo_min, 'Average': memo_average}
  });
  analysis_list.add({
    'CPU(%)': {'Max': cpu_max, 'Min': cpu_min, 'Average': cpu_average}
  });
  return analysis_list;
}

List<Map<String, dynamic>> get_analysis_value_for_compare(List<PingData> list){
  List<Map<String, dynamic>> analysis_list = [];
  for(var key in list[0].latency.keys){
    var average = list.map((m) => m.latency[key]!).average;
    var max = list.map((m) => m.latency[key]!).max;
    var min = list.map((m) => m.latency[key]!).min;
    analysis_list.add({key:{'Max': max, 'Min': min, 'Average': average}});
  }
  return analysis_list;
}

Future<String> executeCommand(String executable, List<String> arguments) async {
  var result = await Process.run(executable, arguments);
  // print("result:"+result.outText);
  return result.outText;
}

Future<List<PingData>> pickAndLoadFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles();
  List<PingData> recordList = [];
  if (result != null) {
    File file = File(result.files.single.path!);

    // You can read and process the file here
    final bytes = await file.readAsBytes();
    final record = excel.Excel.decodeBytes(bytes);
    var sheetName = record.tables.keys.first;

    for (int row = 1; row < record.tables[sheetName]!.maxRows; row++) {
      var perfMap = Map<String, double>();
      for (int col = 1; col < record.tables[sheetName]!.maxCols; col++) {
        var cellValue = record.tables[sheetName]!
            .cell(excel.CellIndex.indexByColumnRow(
                columnIndex: col, rowIndex: row))
            .value;
        perfMap[rowList[col - 1]] = cellValue;
      }

      var dateTimeValue = record.tables[sheetName]!
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value;

      recordList
          .add(PingData(DateTime.parse(dateTimeValue.toString()), perfMap));
    }
  } else {
    // User canceled the file picker
    print('No file selected');
  }

  print(recordList);
  return recordList;
}

Future<Map<String, Map<String, List<dynamic>>>> pickHistoryAndLoadFiles(bool isAndroid) async {
  FilePickerResult? result =
      await FilePicker.platform.pickFiles(allowMultiple: true);
  // List<HistoryData> recordList = [];

  Map<String, Map<String, List<dynamic>>> records={};
  if (result != null) {
    List<File> files = result.paths.map((path) => File(path!)).toList();
    
    for (var file in files) {
      final bytes = await file.readAsBytes();
      final record = excel.Excel.decodeBytes(bytes);
      var sheetName = record.tables.keys.first;
      var table = record.tables[sheetName];
      int memoIndex = 0;
      int cpuIndex = 0;
      Map<String, List<dynamic>> item={};
      if (isAndroid)
        memoIndex = findTheColumnIndex(table, 'Total Pss');
      else
        memoIndex = findTheColumnIndex(table, 'Total Pss');
      cpuIndex = findTheColumnIndex(table, 'User CPU');

      List<double> memoList = [];
      List<double> cpuList = [];
      for (int row = 1; row < record.tables[sheetName]!.maxRows; row++) {
        
        memoList.add(table!
            .cell(excel.CellIndex.indexByColumnRow(
                columnIndex: memoIndex, rowIndex: row))
            .value);
        cpuList.add(table
            .cell(excel.CellIndex.indexByColumnRow(
                columnIndex: cpuIndex, rowIndex: row))
            .value);
      }

      item['Memo']=memoList;
      item['CPU']=cpuList;

      records[file.path.split("\\")[file.path.split("\\").length-1]]=item;
      // recordList.add(HistoryData(file.path.split("\\")[file.path.split("\\").length-1],item));
    }

    // You can read and process the file here
  } else {
    // User canceled the file picker
    print('No file selected');
  }

  return records;
}

int findTheColumnIndex(table, columnName) {
  for (int col = 1; col < table.maxCols; col++) {
    var cellValue = table
        .cell(excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
        .value;
    if (cellValue.toString() == columnName) {
      return col;
    }
  }
  return 0;
}

List<List<PingData>> parseTheHistoryData(Map<String, Map<String, List<dynamic>>> records){
  List<PingData> pingDataMemo = [];
  List<PingData> pingDataCPU = [];
  DateTime dateTime = DateTime.fromMicrosecondsSinceEpoch(0);
  int listLength = records[records.keys.first]!['Memo']!.length;
  for(var key in records.keys){
    if(records[key]!['Memo']!.length<listLength){
      listLength = records[key]!['Memo']!.length;
    }
  }


  for(int i=0;i<listLength;i++){
    Map<String,double> memos ={};
    Map<String,double> cpus ={};
    for(var key in records.keys){
      memos[key]=records[key]!['Memo']![i];
      cpus[key]=records[key]!['CPU']![i];
    }
    pingDataMemo.add(PingData(dateTime, memos));
    pingDataCPU.add(PingData(dateTime, cpus));
    dateTime = dateTime.add(Duration(seconds: 1));
  }
  return [pingDataMemo,pingDataCPU];
}

Map<String, double> parseAndroidMemoResponseData(String response) {
  var perfMap = Map<String, double>();
  var list = response.split('\n');
  //	nativeHeapAllocatedSize	nativeHeapSize
  perfMap['Total Private Dirty'] =
      double.parse(list[24].split(RegExp(r'\s+'))[3]);
  perfMap['Native Private Dirty'] =
      double.parse(list[7].split(RegExp(r'\s+'))[4]);
  perfMap['Dalvik Private Dirty'] =
      double.parse(list[8].split(RegExp(r'\s+'))[4]);
  perfMap['EGL Private Dirty'] =
      double.parse(list[21].split(RegExp(r'\s+'))[4]);
  perfMap['GL Private Dirty'] = double.parse(list[22].split(RegExp(r'\s+'))[4]);
  perfMap['Total Pss'] = double.parse(list[24].split(RegExp(r'\s+'))[2]);
  perfMap['Native Pss'] = double.parse(list[7].split(RegExp(r'\s+'))[3]);
  perfMap['Dalvik Pss'] = double.parse(list[8].split(RegExp(r'\s+'))[3]);
  perfMap['EGL Pss'] = double.parse(list[21].split(RegExp(r'\s+'))[3]);
  perfMap['GL Pss'] = double.parse(list[22].split(RegExp(r'\s+'))[3]);
  perfMap['Native Heap Allocated Size'] =
      double.parse(list[7].split(RegExp(r'\s+'))[9]);
  perfMap['Native Heap Size'] = double.parse(list[7].split(RegExp(r'\s+'))[8]);

  return perfMap;
}

Map<String, double> parseAndroidCPUResponseData(String response) {
  var perfMap = Map<String, double>();
  var line = response.split('\n')[response.split('\n').length - 1];
  final match = RegExp(r'(.+)%.TOTAL:(.+)% user.+').firstMatch(line);

  perfMap['User CPU'] = double.parse(match!.group(2)!);
  perfMap['Total CPU'] = double.parse(match!.group(1)!);
  return perfMap;
}
