import 'package:flutter/material.dart';
import 'package:iot_ui_challenge/widgets/transparent_card.dart';

class SpeedWidget extends StatelessWidget {
  final double temp;
  final Function(double) changeTemp;

  const SpeedWidget({Key? key, required this.temp, required this.changeTemp})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TransparentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            const Text(
              "Fan Speed",
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(
              height: 5,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Low',
                  style: TextStyle(color: Colors.white),
                ),
                Expanded(
                  child: Slider(
                      min: 15,
                      max: 255,
                      value: temp,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white30,
                      onChanged: changeTemp),
                ),
                const Text(
                  'High',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(
              height: 12,
            ),
          ],
        ),
      ),
    );
  }
}
