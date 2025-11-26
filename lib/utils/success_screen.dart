import 'package:Ziepick/ui/theme/theme.dart';
import 'package:Ziepick/utils/extensions/extensions.dart';
import 'package:Ziepick/utils/ui_utils.dart';
import 'package:flutter/material.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle,color: Colors.green,size: 120,),
            SizedBox(height: 20,),
            Text("Order place Successfully",style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold),),
            SizedBox(height: 20,),
            _buildButton("Back To Home".translate(context), (){
              Navigator.pop(context);
              Navigator.pop(context);
            },null,null),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String title, VoidCallback onPressed, Color? buttonColor,
      Color? textColor) {
    return UiUtils.buildButton(
      context,
      onPressed: onPressed,
      radius: 10,
      height: 46,
      border: buttonColor != null
          ? BorderSide(color: context.color.territoryColor)
          : null,
      buttonColor: buttonColor,
      textColor: textColor,
      buttonTitle: title,
      width: 50,
    );
  }
}
