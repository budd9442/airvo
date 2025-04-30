import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:animated_background/animated_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:iot_ui_challenge/pages/control_panel/widgets/option_widget.dart';
import 'package:iot_ui_challenge/pages/control_panel/options_enum.dart';
import 'package:iot_ui_challenge/pages/control_panel/widgets/power_widget.dart';
import 'package:iot_ui_challenge/pages/control_panel/widgets/slider/slider_widget.dart';
import 'package:iot_ui_challenge/pages/control_panel/widgets/motion_widget.dart';
import 'package:iot_ui_challenge/pages/control_panel/widgets/speed_widget.dart';
import 'package:iot_ui_challenge/utils/slider_utils.dart';
import 'package:iot_ui_challenge/widgets/custom_appbar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rainbow_color/rainbow_color.dart';

class ControlPanelPage extends StatefulWidget {
  final String tag;

  const ControlPanelPage({Key? key, required this.tag}) : super(key: key);
  @override
  _ControlPanelPageState createState() => _ControlPanelPageState();
}


class _ControlPanelPageState extends State<ControlPanelPage>
    with TickerProviderStateMixin {
  Options option = Options.cooling;
  bool isActive = false;
  bool motionEnabled = false;
  int speed = 1;
  double temp = 22.85;
  double progressVal = 0.49;
  double fanSpeed = 22;
  double temperature = 26;
  BluetoothConnection? _connection;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isDisconnecting = false;
  BluetoothDevice? _targetDevice;


  Future<void> requestBluetoothPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();

    if (statuses.values.any((status) => status.isDenied)) {
      debugPrint("One or more permissions were denied.");
    }
  }


  void _initBluetooth() async {
    requestBluetoothPermissions();
    // wait for bluetooth to turn on
    BluetoothState state = await FlutterBluetoothSerial.instance.state;
    if (state != BluetoothState.STATE_ON) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }

    // get bonded devices
    List<BluetoothDevice> bondedDevices =
    await FlutterBluetoothSerial.instance.getBondedDevices();

    // find your HC-06
    for (BluetoothDevice device in bondedDevices) {
      if (device.name == 'HC-06') {
        _targetDevice = device;
        break;
      }
    }

    if (_targetDevice != null) {
      _connectToDevice(_targetDevice!);
    } else {
      debugPrint("HC-06 not found. Make sure it's paired with the phone.");
    }
  }
  void _connectToDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      debugPrint('Connected to the device');

      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });

      _connection!.input?.listen((Uint8List rawdata) {
        debugPrint('Data received: ${ascii.decode(rawdata)}');
        var data = ascii.decode(rawdata);

        // example data: "h=55.4	 t=27.3"
        RegExp tRegex = RegExp(r't=([\d.]+)'); // capture the number after t=
        Match? match = tRegex.firstMatch(data);

        if (match != null) {
          String tString = match.group(1)!;
          double tValue = double.parse(tString);

          // now you have tValue as a double!
          print('Temperature: $tValue');
          setState(() {
            temperature = tValue;
            progressVal = mapTempToProgress(temp);
            if(option != Options.manual){
              fanSpeed = mapTemperatureToFanSpeed(temperature);
              sendDataToDevice("slider : $fanSpeed");
            }



          });


        }
      }).onDone(() {
        debugPrint('Disconnected by remote');
        setState(() => _isConnected = false);
      });
    } catch (e) {
      debugPrint('Cannot connect, exception occurred');
      debugPrint(e.toString());
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
    }
  }

  double mapTemperatureToFanSpeed(double temp) {
    double minTemp = 16.0;
    double maxTemp = 30.0;
    double minFanSpeed = 60; // or whatever your minimum fan speed should be
    double maxFanSpeed = 255; // or whatever your maximum fan speed should be

    if (temp <= minTemp) return minFanSpeed;
    if (temp >= maxTemp) return maxFanSpeed;

    return minFanSpeed + (temp - minTemp) * (maxFanSpeed - minFanSpeed) / (maxTemp - minTemp);
  }


  double mapTempToProgress(double temp) {
    double minTemp = 22.0;
    double maxTemp = 35.0;
    double minProgress = 0.7;
    double maxProgress = 1.0;

    if (temp <= minTemp) return minProgress;
    if (temp >= maxTemp) return maxProgress;

    double progress = minProgress + (temp - minTemp) * (maxProgress - minProgress) / (maxTemp - minTemp);
    return progress;
  }


  void sendDataToDevice(String data) {
    if (_isConnected && _connection != null) {
      _connection!.output.add(utf8.encode(data + '\r\n'));  // Send data in UTF-8 encoded format
      _connection!.output.allSent.then((_) {
        debugPrint('Data sent: $data');
      });
    } else {
      debugPrint('Not connected to a device');
    }
  }



  var activeColor = Rainbow(spectrum: [
    const Color(0xFF33C0BA),
    const Color(0xFF1086D4),
    const Color(0xFF6D04E2),
    const Color(0xFFC421A0),
    const Color(0xFFE4262F)
  ], rangeStart: 0.0, rangeEnd: 1.0);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    if (_isConnected && _connection != null) {
      _isDisconnecting = true;
      _connection!.dispose();
      _connection = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return  Scaffold(
      
          body: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white,
                    activeColor[progressVal].withOpacity(0.5),
                    activeColor[progressVal]
                  ]),
            ),
            child: AnimatedBackground(
              behaviour: RandomParticleBehaviour(
                  options: ParticleOptions(
                baseColor: const Color(0xFFFFFFFF),
                opacityChangeRate: 0.25,
                minOpacity: 0.1,
                maxOpacity: 0.3,
                spawnMinSpeed: speed * 60.0,
                spawnMaxSpeed: speed * 120,
                spawnMinRadius: 2.0,
                spawnMaxRadius: 5.0,
                particleCount: isActive ? speed * 150 : 0,
              )),
              vsync: this,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Airvo Remote",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isConnected ? Colors.green[100] : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: _isConnected || _isConnecting
                                ? null // Disable button while connected or connecting
                                : () {
                              requestBluetoothPermissions();
                              _initBluetooth();
                              setState(() {
                                _isConnecting = true;
                              });
                            },
                            icon: Icon(
                              _isConnected
                                  ? Icons.bluetooth_connected
                                  : _isConnecting
                                  ? Icons.bluetooth_searching
                                  : Icons.bluetooth,
                              size: 20,
                            ),
                            label: Text(
                              _isConnected
                                  ? "Connected"
                                  : _isConnecting
                                  ? "Connecting..."
                                  : "Connect",
                            ),
                          ),

                        ],
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            options(),
                            slider(),
                            controls(),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        
    );
  }

  Widget options() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        OptionWidget(
          icon: 'assets/svg/clock.svg',
          isSelected: option == Options.timer,
          onTap: () => setState(() {
            option = Options.timer;
          }),
          size: 32,
        ),
        OptionWidget(
          icon: 'assets/svg/snow.svg',
          isSelected: option == Options.cooling,
          onTap: () => setState(() {
            option = Options.cooling;
          }),
          size: 25,
        ),
        OptionWidget(
          icon: 'assets/svg/bright.svg',
          isSelected: option == Options.heat,
          onTap: () => setState(() {
            option = Options.heat;
          }),
          size: 35,
        ),
        OptionWidget(
          icon: 'assets/svg/air.svg',
          isSelected: option == Options.manual,
          onTap: () => setState(() {
            if(option == Options.manual) {
              option = Options.none;
            }else{
              option = Options.manual;
            }
          }),
          size: 28,
        ),
      ],
    );
  }

  Widget slider() {
    return SliderWidget(
      progressVal: progressVal,
      color: activeColor[progressVal],
      tmp: temperature
      // onChange: (value) {
      //
      //   setState(() {
      //     //sendDataToDevice("slider : ${value as String}");
      //     //temp = value;
      //     //progressVal = normalize(value, kMinDegree, kMaxDegree);
      //
      //   });
      //
      // },
    );
  }

  Widget controls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: PowerWidget(
                  isActive: isActive,
                  onChanged: (val) => setState(() {
                    sendDataToDevice("power ${val ? "on" : "off"}");
                    isActive = val;
                  })),
            ),
            const SizedBox(
              width: 15,
            ),
            Expanded(
              child: MotionWidget(
                  isActive: motionEnabled,
                  onChanged: (val) => setState(() {
                    sendDataToDevice("motion ${val ? "on" : "off"}");
                    motionEnabled = val;
                  })),


            ),
          ],
        ),
        const SizedBox(
          height: 15,
        ),
        SpeedWidget(
            speed: fanSpeed,
            changeSpeed: (val) => setState(() {
              option = Options.manual;
              fanSpeed = val;
                  sendDataToDevice("slider : $val");
                 // progressVal = normalize(val, kMinDegree, kMaxDegree);
                })),
        const SizedBox(
          height: 15,
        ),
      ],
    );
  }/////////////////////////////////////////////////////////////
}
