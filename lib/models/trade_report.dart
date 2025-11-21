// lib/models/trade_report.dart

import 'package:aravt/models/game_date.dart';

enum TradeOutcome {
  success,
  partialSuccess,
  rejected,
  cancelled,
}

class ItemExchange {
  final String itemTemplateId;
  final String itemName;
  final int quantity;
  final double value;

  ItemExchange({
    required this.itemTemplateId,
    required this.itemName,
    required this.quantity,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
        'itemTemplateId': itemTemplateId,
        'itemName': itemName,
        'quantity': quantity,
        'value': value,
      };

  factory ItemExchange.fromJson(Map<String, dynamic> json) {
    return ItemExchange(
      itemTemplateId: json['itemTemplateId'] as String,
      itemName: json['itemName'] as String,
      quantity: json['quantity'] as int,
      value: (json['value'] as num).toDouble(),
    );
  }
}

class TradeReport {
  final GameDate date;
  final String partnerName;
  final List<ItemExchange> itemsGiven;
  final List<ItemExchange> itemsReceived;
  final TradeOutcome outcome;
  final String notes;

  TradeReport({
    required this.date,
    required this.partnerName,
    required this.itemsGiven,
    required this.itemsReceived,
    required this.outcome,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'date': date.toJson(),
        'partnerName': partnerName,
        'itemsGiven': itemsGiven.map((e) => e.toJson()).toList(),
        'itemsReceived': itemsReceived.map((e) => e.toJson()).toList(),
        'outcome': outcome.name,
        'notes': notes,
      };

  factory TradeReport.fromJson(Map<String, dynamic> json) {
    return TradeReport(
      date: GameDate.fromJson(json['date'] as Map<String, dynamic>),
      partnerName: json['partnerName'] as String,
      itemsGiven: (json['itemsGiven'] as List)
          .map((e) => ItemExchange.fromJson(e as Map<String, dynamic>))
          .toList(),
      itemsReceived: (json['itemsReceived'] as List)
          .map((e) => ItemExchange.fromJson(e as Map<String, dynamic>))
          .toList(),
      outcome: TradeOutcome.values.firstWhere(
        (e) => e.name == json['outcome'],
        orElse: () => TradeOutcome.success,
      ),
      notes: json['notes'] as String? ?? '',
    );
  }
}
