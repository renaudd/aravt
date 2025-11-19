// models/game_turn.dart


class GameTurn {
 int turnNumber;


 GameTurn({this.turnNumber = 1});


 Map<String, dynamic> toJson() => {
       'turnNumber': turnNumber,
     };


 factory GameTurn.fromJson(Map<String, dynamic> json) {
   return GameTurn(
     turnNumber: json['turnNumber'] ?? 1,
   );
 }


 /// The first 7 turns are the "tutorial" week.
 /// Kept for potential UI or logic checks, even if turn length is now constant.
 bool get isTutorialPeriod => turnNumber <= 7;


 /// Returns the duration this turn represents.
 String get turnDurationDescriptor => "1 Day";


 /// Returns the number of days to advance as an integer.
 int get daysToAdvance => 1;


 /// Advances the turn counter.
 void incrementTurn() {
   turnNumber++;
 }
}

