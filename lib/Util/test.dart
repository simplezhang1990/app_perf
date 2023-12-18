import 'dart:io';
// import 'dart:convert';

// import 'PingData.dart';
// import 'package:excel/excel.dart' as excel;
// import 'package:path_provider/path_provider.dart';

import 'package:process_run/shell.dart';

// var pid;

Future<String> executeCommand(String executable, List<String> arguments) async {
  var result = await Process.run(executable, arguments);
  print("result:"+result.errText);
  print("result:"+result.outText);
  return result.outText;
}



Future<void> main()  async {
  final response = await executeCommand(
          'adb', ['shell', 'cmd', 'package', 'list', 'packages', '-3']);

  print(response);
  
  // print(response.toString());
  // String str='cpu {"timestamp": 1697465068663, "pid": 6641, "value": 0.0, "sys_value": 98.89586902722252, "count": 6}';
  // var test = str.substring('cpu'.length+1,str.length);
  // var test1 = json.decode(test);
  // print(test1['value']);
}
