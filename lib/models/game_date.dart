// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:convert';

class GameDate {
  int year;
  int month; // 1-12
  int day; // 1-31 (depending on month)
  int hour; // 0-23
  int minute; // 0-59
  int second; // 0-59

  static const List<int> _daysInMonth = [
    0,
    31,
    28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31
  ];
  static const int _gameStartYear = 1140;

  GameDate(this.year, this.month, this.day,
      {this.hour = 0, this.minute = 0, this.second = 0});

  Map<String, dynamic> toJson() => {
        'year': year,
        'month': month,
        'day': day,
        'hour': hour,
        'minute': minute,
        'second': second,
      };

  factory GameDate.fromJson(Map<String, dynamic> json) {
    return GameDate(
      json['year'],
      json['month'],
      json['day'],
      hour: json['hour'] ?? 0,
      minute: json['minute'] ?? 0,
      second: json['second'] ?? 0,
    );
  }

  DateTime toDateTime() {
    try {
      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      print("Error converting GameDate to DateTime: $e. Using fallback.");
      return DateTime.now();
    }
  }

  // Precise time advancement for combat rounds
  void advanceTime(
      {int seconds = 0, int minutes = 0, int hours = 0, int days = 0}) {
    second += seconds;
    while (second >= 60) {
      second -= 60;
      minute++;
    }

    minute += minutes;
    while (minute >= 60) {
      minute -= 60;
      hour++;
    }

    hour += hours;
    while (hour >= 24) {
      hour -= 24;
      day++;
    }

    // Handle day rollovers
    if (days > 0) {
      for (int i = 0; i < days; i++) nextDay();
    } else {
      // Handle natural rollover from hours
      while (day > _getDaysInMonth(year, month)) {
        day -= _getDaysInMonth(year, month);
        month++;
        if (month > 12) {
          month = 1;
          year++;
        }
      }
    }
  }

  void addHours(int hours) {
    advanceTime(hours: hours);
  }

  void nextDay() {
    day++;
    if (day > _getDaysInMonth(year, month)) {
      day = 1;
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
  }

  int _getDaysInMonth(int forYear, int forMonth) {
    if (forMonth == 2 &&
        (forYear % 4 == 0 && (forYear % 100 != 0 || forYear % 400 == 0))) {
      return 29;
    }
    return _daysInMonth[forMonth];
  }

  // --- COMPARISON & DISPLAY ---

  int compareTo(GameDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    if (day != other.day) return day.compareTo(other.day);
    if (hour != other.hour) return hour.compareTo(other.hour);
    if (minute != other.minute) return minute.compareTo(other.minute);
    return second.compareTo(other.second);
  }

  bool isBefore(GameDate other) => compareTo(other) < 0;

  bool isAfter(GameDate other) => compareTo(other) > 0;

  bool isAtSameMomentAs(GameDate other) => compareTo(other) == 0;

  int get totalDays {
    int days = 0;
    for (int y = _gameStartYear; y < year; y++) {
      days += 365;
      if (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) {
        days += 1; // Leap year
      }
    }
    for (int m = 1; m < month; m++) {
      days += _daysInMonth[m];
      if (m == 2 && (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))) {
        days += 1; // Leap day this year
      }
    }
    days += (day - 1);
    return days;
  }

  @override
  String toString() {
    const List<String> monthNames = [
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    // Added minute/second to default string for debugging
    final String timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
    return "${monthNames[month]} $day, $year at $timeStr";
  }

  String toDateString() {
    const List<String> monthNames = [
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return "${monthNames[month]} $day, $year";
  }

  String toShortString() {
    final String monthStr = month.toString().padLeft(2, '0');
    final String dayStr = day.toString().padLeft(2, '0');
    return "$monthStr/$dayStr/$year";
  }

  GameDate copy() {
    return GameDate(year, month, day,
        hour: hour, minute: minute, second: second);
  }
}
