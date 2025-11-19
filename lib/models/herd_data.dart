import 'dart:math';


enum AnimalType { Cattle, Sheep, Goat, Yak, Horse }


class LivestockAnimal {
 final String id;
 final AnimalType type;
 int age; // In months for finer granularity? Or years? Let's do years for now.
 final bool isMale;
 double health; // 0.0 - 1.0


 LivestockAnimal({
   required this.id,
   required this.type,
   required this.age,
   required this.isMale,
   this.health = 1.0,
 });


 Map<String, dynamic> toJson() => {
       'id': id,
       'type': type.name,
       'age': age,
       'isMale': isMale,
       'health': health,
     };


 factory LivestockAnimal.fromJson(Map<String, dynamic> json) {
   return LivestockAnimal(
     id: json['id'],
     type: AnimalType.values.firstWhere((e) => e.name == json['type']),
     age: json['age'],
     isMale: json['isMale'],
     health: (json['health'] as num).toDouble(),
   );
 }
}


class Herd {
 final AnimalType type;
 List<LivestockAnimal> animals;
 int lastGrazedTurn;


 // Daily metrics
 double dailyMilkProduction;
 int dailyBirths;
 int dailyDeaths;


 Herd({
   required this.type,
   List<LivestockAnimal>? animals,
   this.lastGrazedTurn = -1,
   this.dailyMilkProduction = 0.0,
   this.dailyBirths = 0,
   this.dailyDeaths = 0,
 }) : this.animals = animals ?? [];


 int get totalPopulation => animals.length;
 int get adultMales => animals.where((a) => a.isMale && a.age >= 2).length;
 int get adultFemales => animals.where((a) => !a.isMale && a.age >= 2).length;
 int get young => animals.where((a) => a.age < 2).length;


 void resetDailyTracker() {
   dailyMilkProduction = 0.0;
   dailyBirths = 0;
   dailyDeaths = 0;
 }


 // Helper to initialize a generic herd
 static Herd createDefault(AnimalType type,
     {int males = 2, int females = 10, int young = 5}) {
   final herd = Herd(type: type);
   final r = Random();
   for (int i = 0; i < males; i++) {
     herd.animals.add(LivestockAnimal(
         id: '${type.name}_m_$i',
         type: type,
         age: 2 + r.nextInt(5),
         isMale: true));
   }
   for (int i = 0; i < females; i++) {
     herd.animals.add(LivestockAnimal(
         id: '${type.name}_f_$i',
         type: type,
         age: 2 + r.nextInt(8),
         isMale: false));
   }
   for (int i = 0; i < young; i++) {
     herd.animals.add(LivestockAnimal(
         id: '${type.name}_y_$i',
         type: type,
         age: 0 + r.nextInt(2),
         isMale: r.nextBool()));
   }
   return herd;
 }


 Map<String, dynamic> toJson() => {
       'type': type.name,
       'animals': animals.map((a) => a.toJson()).toList(),
       'lastGrazedTurn': lastGrazedTurn,
       'dailyMilkProduction': dailyMilkProduction,
       'dailyBirths': dailyBirths,
       'dailyDeaths': dailyDeaths,
     };


 factory Herd.fromJson(Map<String, dynamic> json) {
   return Herd(
     type: AnimalType.values.firstWhere((e) => e.name == json['type']),
     animals: (json['animals'] as List)
         .map((a) => LivestockAnimal.fromJson(a))
         .toList(),
     lastGrazedTurn: json['lastGrazedTurn'] ?? -1,
     dailyMilkProduction: (json['dailyMilkProduction'] ?? 0.0).toDouble(),
     dailyBirths: json['dailyBirths'] ?? 0,
     dailyDeaths: json['dailyDeaths'] ?? 0,
   );
 }


 void removeRandomAnimals(int count) {
   int removed = 0;
   while (removed < count && animals.isNotEmpty) {
     // Prioritize removing weakest/youngest first? Or pure random?
     // Let's do pure random for wolf attacks for now.
     animals.removeAt(Random().nextInt(animals.length));
     removed++;
   }
   dailyDeaths += removed;
 }
}

