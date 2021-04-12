
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart';

class BackgroundCollectedPage extends StatefulWidget {
  final BluetoothDevice server;
  const BackgroundCollectedPage({this.server});

  @override
  _BackgroundCollectedPage createState() => new _BackgroundCollectedPage();
  }


  class _BackgroundCollectedPage extends State<BackgroundCollectedPage> {

    static final clientID = 0;
    BluetoothConnection connection;
    String _messageBuffer = '';
    bool isConnecting = true;


    bool get isConnected => connection != null && connection.isConnected;
    bool isDisconnecting = false;
    int _count = 0;


    @override
    void initState() {
      super.initState();

      BluetoothConnection.toAddress(widget.server.address).then((_connection) {
        print('Connected to the device');
        connection = _connection;
        setState(() {
          isConnecting = false;
          isDisconnecting = false;
        });

        connection.input.listen((Uint8List data) {
          // Example: Detect which side closed the connection
          // There should be `isDisconnecting` flag to show are we are (locally)
          // in middle of disconnecting process, should be set before calling
          // `dispose`, `finish` or `close`, which all causes to disconnect.
          // If we except the disconnection, `onDone` should be fired as result.
          // If we didn't except this (no flag set), it means closing by remote.
          if (isDisconnecting) {
            print('Disconnecting locally!');
          } else {
            print('Disconnected remotely!');
          }
          if (this.mounted) {
            setState(() {});
          }
        });
      }).catchError((error) {
        print('Cannot connect, exception occured');
        print(error);
      });
    }

    @override
    void dispose() {
      // Avoid memory leak (`setState` after dispose) and disconnect
      if (isConnected) {
        isDisconnecting = true;
        connection.dispose();
        connection = null;
      }

      super.dispose();
    }

    void _onDataReceived(Uint8List data) {
      // Allocate buffer for parsed data
      int backspacesCounter = 0;
      data.forEach((byte) {
        if (byte == 8 || byte == 127) {
          backspacesCounter++;
        }
      });
      Uint8List buffer = Uint8List(data.length - backspacesCounter);
      int bufferIndex = buffer.length;

      // Apply backspace control character
      backspacesCounter = 0;
      for (int i = data.length - 1; i >= 0; i--) {
        if (data[i] == 8 || data[i] == 127) {
          backspacesCounter++;
        } else {
          if (backspacesCounter > 0) {
            backspacesCounter--;
          } else {
            buffer[--bufferIndex] = data[i];
          }
        }
      }
    }

    void _sendMessage(String text) async {
      if (text.length > 0) {
        try {
          connection.output.add(utf8.encode(text));
          await connection.output.allSent;
        } catch (e) {
          // Ignore error, but notify state
          setState(() {});
        }
      }
    }

    dynamic getColumnData(StreamSubscription data) {
      List<int> _buffer = List<int>();

      _buffer += data;

      while (true) {
        int index = _buffer.indexOf("0".codeUnitAt(0));
        if (index >= 0 && _buffer.length - index > 10) {
          final accData dataSample = accData(
              X: _buffer.sublist(index + 1, index + 3),
              Y: _buffer.sublist(index + 4, index + 6),
              Z: _buffer.getRange(index + 8, index + 10),
              time: _buffer.sublist(index + 10)
          );
          _buffer.removeRange(0, index + 10);

          print(dataSample);
          return dataSample;
        }
      }

    }

    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
            title: (isConnecting
                ? Text('Connecting to ' + widget.server.name + '...')
                : isConnected
                ? Text('Live plot with ' + widget.server.name)
                : Text('plot log with ' + widget.server.name))
        ),
        body: Center(
                   child: Column(
                    children: [
                      Container(
                        child: SfCartesianChart(
                        isTransposed: true,
                        primaryXAxis: CategoryAxis(),
                        series: <ChartSeries>[
                         SplineSeries<accData,int>(
                             dataSource: getColumnData(data),
                             xValueMapper: (accData dataSample, _) => dataSample.X[0],
                             yValueMapper: (accData dataSample, _) => dataSample.time[0],
                         )
                       ]
                      )
                      ),
                      Container(
                        child: SfCartesianChart(
                          primaryXAxis: CategoryAxis(
                          ),
                          /*
                                series:
                                dataSource:
                                xValueMapper:
                                yValueMapper:
                          */
                        ),


                      ),

                     Container(
                       child: SfCartesianChart(
                         primaryXAxis: CategoryAxis(
                         ),
                         /*
                                series:
                                dataSource:
                                xValueMapper:
                                yValueMapper:
                          */
                       ),


                     ),
                    ],
                  ),

              )
        );


    }
    /*
    List<String> dataList = data.split(':');
      for(String s in datalist){
        int a=int.parse(s);
        print(a);
      }
     */


  }

  class accData{
    Uint8List X;
    Uint8List Y;
    Uint8List Z;
    Uint8List time;

    accData({this.X,this.Y,this.Z,this.time});


  }
