import 'dart:math';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/services/combat_service.dart'; // For TerrainType


class Fish {
 final String id;
 final String name;
 final int rarityWeight; // Higher = more common
 // The skill best used to catch this fish (e.g., spearfishing vs netting/scooping with shield)
 final ItemType relevantSkillItem;
 final double minMeat;
 final double maxMeat;
 // [GEMINI-FIX] Added missing terrains field
 final List<TerrainType> terrains;


 const Fish({
   required this.id,
   required this.name,
   required this.rarityWeight,
   required this.relevantSkillItem,
   required this.minMeat,
   required this.maxMeat,
   required this.terrains,
 });
}


class FishDatabase {
 static const List<Fish> allFish = [
   Fish(
     id: 'omul',
     name: 'Omul',
     rarityWeight: 50, // Common
     relevantSkillItem: ItemType.shield, // Scooping/Netting
     minMeat: 0.5,
     maxMeat: 1.5,
     terrains: [TerrainType.waterDeep, TerrainType.waterShallow],
   ),
   Fish(
     id: 'lenok',
     name: 'Lenok',
     rarityWeight: 40, // Common
     relevantSkillItem: ItemType.sword, // Slashing/Stunning
     minMeat: 2.0,
     maxMeat: 4.0,
     terrains: [TerrainType.waterShallow], // Prefers rivers/shallows
   ),
   Fish(
     id: 'perch',
     name: 'Baikal Perch',
     rarityWeight: 50, // Common
     relevantSkillItem: ItemType.shield,
     minMeat: 0.3,
     maxMeat: 0.8,
     terrains: [TerrainType.waterShallow],
   ),
   Fish(
     id: 'grayling',
     name: 'Grayling',
     rarityWeight: 40, // Common
     relevantSkillItem: ItemType.spear, // Spearfishing
     minMeat: 0.5,
     maxMeat: 1.2,
     terrains: [TerrainType.waterShallow],
   ),
   Fish(
     id: 'pike',
     name: 'Northern Pike',
     rarityWeight: 15, // Rare
     relevantSkillItem: ItemType.shield,
     minMeat: 5.0,
     maxMeat: 12.0,
     terrains: [TerrainType.waterShallow], // Ambush predator in weeds/shallows
   ),
   Fish(
     id: 'sturgeon',
     name: 'Baikal Sturgeon',
     rarityWeight: 5, // Very Rare
     relevantSkillItem: ItemType.sword,
     minMeat: 15.0,
     maxMeat: 40.0,
     terrains: [TerrainType.waterDeep], // Deep water dweller
   ),
   Fish(
     id: 'taimen',
     name: 'Siberian Taimen',
     rarityWeight: 5, // Very Rare
     relevantSkillItem: ItemType.sword,
     minMeat: 20.0,
     maxMeat: 50.0,
     terrains: [TerrainType.waterDeep, TerrainType.waterShallow],
   ),
 ];


 static Fish getRandomFish() {
   int totalWeight = allFish.fold(0, (sum, f) => sum + f.rarityWeight);
   int roll = Random().nextInt(totalWeight);
   int currentWeight = 0;
   for (final fish in allFish) {
     currentWeight += fish.rarityWeight;
     if (roll < currentWeight) return fish;
   }
   return allFish.last;
 }
}

