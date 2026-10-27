import 'package:intl/intl.dart';

/// Net decimals follow the current interface language, including negative nets.
String formatExamNet(double net, String locale) =>
    NumberFormat('0.00', locale).format(net);
