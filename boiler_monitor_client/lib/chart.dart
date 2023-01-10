import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'controller.dart';
import 'data_point.dart';

class Chart extends StatelessWidget {
  const Chart({Key? key, required this.controller}) : super(key: key);
  final Controller controller;
  static const opacity = 0.1;

  List<PlotBand> _buildPlotBands({required BuildContext context, required DateTime startTime}) {
    List<PlotBand> statePlotBands = [];

    addBands(
      statePlotBands: statePlotBands,
      context: context,
      startTime: startTime,
      bandStartString: "FUEL",
      bandEndString: "FUEL-RESOLVE",
      plotBand: fuelPlotBand,
    );

    addBands(
      statePlotBands: statePlotBands,
      context: context,
      startTime: startTime,
      bandStartString: "OVERTEMP",
      bandEndString: "OVERTEMP-RESOLVE",
      plotBand: overtempPlotBand,
    );

    addBands(
        statePlotBands: statePlotBands,
        context: context,
        startTime: startTime,
        bandStartString: "DISENGAGED",
        bandEndString: "ENGAGED",
        plotBand: overtempPlotBand);

    return statePlotBands;
  }

  PlotBand fuelPlotBand({required BuildContext context, required DateTime start, required DateTime end}) {
    return PlotBand(start: start, end: end, color: Colors.black, opacity: isDarkMode(context) ? 0.5 : 0.15);
  }

  PlotBand overtempPlotBand({required BuildContext context, required DateTime start, required DateTime end}) {
    return PlotBand(start: start, end: end, color: Colors.red, opacity: .25);
  }

  void addBands({
    required List<PlotBand> statePlotBands,
    required BuildContext context,
    required DateTime startTime,
    required String bandStartString,
    required String bandEndString,
    required Function plotBand,
  }) {
    var filteredStates = controller.states.where((element) => element.type == bandStartString || element.type == bandEndString).toList();
    if (filteredStates.isNotEmpty) {
      String lastState = filteredStates.first.type == bandStartString ? bandEndString : bandStartString;
      DateTime lastTime = startTime;
      while (filteredStates.isNotEmpty) {
        if (lastState == bandStartString) {
          statePlotBands.add(plotBand(start: lastTime, end: filteredStates.first.dateTime, context: context));
        }
        lastState = filteredStates.first.type;
        lastTime = filteredStates.first.dateTime;
        filteredStates.removeAt(0);
      }
      if (lastState == bandStartString) statePlotBands.add(plotBand(start: lastTime, end: DateTime.now(), context: context));
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime twelveHoursAgo = now.subtract(const Duration(hours: 12));
    List<PlotBand> statePlotBands = _buildPlotBands(startTime: twelveHoursAgo, context: context);
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SfCartesianChart(
            title: ChartTitle(text: "Temperature over time"),
            primaryXAxis: DateTimeAxis(minimum: twelveHoursAgo, maximum: now, plotBands: statePlotBands),
            primaryYAxis: NumericAxis(
              minimum: 120,
              maximum: 210,
              plotBands: [
                PlotBand(start: 185, end: 210, color: Colors.deepOrange, opacity: opacity),
                PlotBand(start: 181, end: 185, color: Colors.orange, opacity: opacity),
                PlotBand(start: 144, end: 185, color: Colors.green, opacity: opacity),
                PlotBand(start: 140, end: 144, color: Colors.teal, opacity: opacity),
                PlotBand(start: 0, end: 144, color: Colors.blue, opacity: opacity),
              ],
            ),
            zoomPanBehavior: ZoomPanBehavior(
              enableMouseWheelZooming: true,
              enablePinching: true,
              zoomMode: ZoomMode.x,
              enablePanning: true,
            ),
            series: <LineSeries<DataPoint, DateTime>>[
              LineSeries<DataPoint, DateTime>(
                emptyPointSettings: EmptyPointSettings(mode: EmptyPointMode.gap),
                //markerSettings: const MarkerSettings(isVisible: true, height: 2, width: 2),
                color: isDarkMode(context) ? Colors.white : Colors.black,
                animationDuration: 0,
                dataSource: controller.temps,
                xValueMapper: (DataPoint dataPoint, _) => dataPoint.dateTime,
                yValueMapper: (DataPoint dataPoint, _) => dataPoint.temperature?.toDouble(),
              )
            ],
          ),
        ),
        Positioned(
          right: 15,
          bottom: 32.5,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: controller.reSubscribeListeners,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.refresh),
            ),
          ),
        ),
      ],
    );
  }

  bool isDarkMode(BuildContext context) => (MediaQuery.of(context).platformBrightness == Brightness.dark || Platform.isMacOS);
}
