import 'package:fl_chart/fl_chart.dart';

void main() {
  final d = RadarChartData(dataSets: [], getTitle: (i, angle) => RadarChartTitle(text: 'hi'));
  print(d);
}
