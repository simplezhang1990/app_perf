import 'package:flutter/material.dart';

class myButton extends StatelessWidget {
  final VoidCallback pressFunc;
  final String buttonText;

  myButton({required this.pressFunc, required this.buttonText});

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return SizedBox(
      height: 40, // Set the desired height
      child: TextButton(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
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
          pressFunc;
        },
        child: Text(this.buttonText),
      ),
    );
  }
}
