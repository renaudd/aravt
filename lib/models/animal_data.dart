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

import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/services/combat_service.dart'; // For TerrainType

enum AnimalSize { small, large, bird, fish }

enum MeatType { generic, venison, mutton, pork, bird, fish }

class Animal {
  final String id;
  final String name;
  final AnimalSize size;
  final MeatType meatType;
  final List<TerrainType> terrains;
  final int rarityWeight; // Higher = more common
  final List<ItemType> validWeapons;
  final double minMeat;
  final double maxMeat;
  final int peltCount; // usually 1, but maybe 0 for some birds?

  const Animal({
    required this.id,
    required this.name,
    required this.size,
    required this.meatType,
    required this.terrains,
    required this.rarityWeight,
    required this.validWeapons,
    required this.minMeat,
    required this.maxMeat,
    this.peltCount = 1,
  });
}

class AnimalDatabase {
  static const List<Animal> allAnimals = [
    // --- GRASSLAND SMALL GAME ---
    Animal(
      id: 'marmot',
      name: 'Marmot',
      size: AnimalSize.small,
      meatType: MeatType.generic,
      terrains: [TerrainType.plains],
      rarityWeight: 50, // Common
      validWeapons: [ItemType.bow], // Shortbow (using generic bow type for now)
      minMeat: 3.0,
      maxMeat: 5.0,
    ),
    Animal(
      id: 'tolai_hare',
      name: 'Tolai Hare',
      size: AnimalSize.small,
      meatType: MeatType.generic,
      terrains: [TerrainType.plains],
      rarityWeight: 50, // Common
      validWeapons: [ItemType.bow],
      minMeat: 1.5,
      maxMeat: 3.0,
    ),
    Animal(
      id: 'corsac_fox',
      name: 'Corsac Fox',
      size: AnimalSize.small,
      meatType: MeatType.generic,
      terrains: [TerrainType.plains, TerrainType.trees],
      rarityWeight: 10, // Very Rare
      validWeapons: [ItemType.bow],
      minMeat: 2.0,
      maxMeat: 4.0,
    ),
    Animal(
      id: 'red_fox',
      name: 'Red Fox',
      size: AnimalSize.small,
      meatType: MeatType.generic,
      terrains: [TerrainType.plains, TerrainType.trees],
      rarityWeight: 10, // Very Rare
      validWeapons: [ItemType.bow],
      minMeat: 3.0,
      maxMeat: 6.0,
    ),

    // --- BIRDS (Plains & Woods) ---
    Animal(
      id: 'daurian_partridge',
      name: 'Daurian Partridge',
      size: AnimalSize.bird,
      meatType: MeatType.bird,
      terrains: [TerrainType.plains, TerrainType.trees],
      rarityWeight: 40, // Common
      validWeapons: [ItemType.bow],
      minMeat: 0.5,
      maxMeat: 1.0,
    ),
    Animal(
      id: 'swan_goose',
      name: 'Swan Goose',
      size: AnimalSize.bird,
      meatType: MeatType.bird,
      terrains: [TerrainType.plains, TerrainType.waterShallow],
      rarityWeight: 40, // Common
      validWeapons: [ItemType.bow],
      minMeat: 3.0,
      maxMeat: 5.0,
    ),
    Animal(
      id: 'whooper_swan',
      name: 'Whooper Swan',
      size: AnimalSize.bird,
      meatType: MeatType.bird,
      terrains: [TerrainType.waterShallow, TerrainType.waterDeep],
      rarityWeight: 10, // Rare
      validWeapons: [ItemType.bow],
      minMeat: 8.0,
      maxMeat: 12.0,
    ),
    // ... (Add other birds similarly: grouse, capercaillie as rare in trees)

    // --- LARGE GAME ---
    Animal(
      id: 'mongolian_gazelle',
      name: 'Mongolian Gazelle',
      size: AnimalSize.large,
      meatType: MeatType.venison,
      terrains: [TerrainType.plains],
      rarityWeight: 40, // Common
      validWeapons: [ItemType.spear, ItemType.bow],
      minMeat: 25.0,
      maxMeat: 40.0,
    ),
    Animal(
      id: 'argali',
      name: 'Argali Sheep',
      size: AnimalSize.large,
      meatType: MeatType.mutton,
      terrains: [TerrainType.plains, TerrainType.hills],
      rarityWeight: 30, // Common
      validWeapons: [ItemType.spear, ItemType.bow],
      minMeat: 60.0,
      maxMeat: 100.0,
    ),
    Animal(
      id: 'ibex',
      name: 'Siberian Ibex',
      size: AnimalSize.large,
      meatType: MeatType.mutton,
      terrains: [TerrainType.hills, TerrainType.rocks],
      rarityWeight: 15, // Rare
      validWeapons: [ItemType.spear, ItemType.bow],
      minMeat: 50.0,
      maxMeat: 90.0,
    ),
    Animal(
      id: 'siberian_roe_deer',
      name: 'Siberian Roe Deer',
      size: AnimalSize.large,
      meatType: MeatType.venison,
      terrains: [TerrainType.trees],
      rarityWeight: 40, // Common in woods
      validWeapons: [ItemType.spear, ItemType.bow],
      minMeat: 20.0,
      maxMeat: 35.0,
    ),
    Animal(
      id: 'wild_boar',
      name: 'Wild Boar',
      size: AnimalSize.large,
      meatType: MeatType.pork,
      terrains: [TerrainType.trees, TerrainType.hills],
      rarityWeight: 30, // Common
      validWeapons: [ItemType.spear], // Boar spears!
      minMeat: 50.0,
      maxMeat: 90.0,
    ),

    // --- FISH ---
    Animal(
      id: 'omul',
      name: 'Omul',
      size: AnimalSize.fish,
      meatType: MeatType.fish,
      terrains: [TerrainType.waterDeep, TerrainType.waterShallow],
      rarityWeight: 50,
      validWeapons: [ItemType.shield], // Representing nets/traps
      minMeat: 1.0,
      maxMeat: 2.0,
      peltCount: 0,
    ),
    Animal(
      id: 'lenok',
      name: 'Lenok',
      size: AnimalSize.fish,
      meatType: MeatType.fish,
      terrains: [TerrainType.waterShallow],
      rarityWeight: 40,
      validWeapons: [ItemType.sword], // Spearfishing/slashing
      minMeat: 2.0,
      maxMeat: 5.0,
      peltCount: 0,
    ),
    Animal(
      id: 'grayling',
      name: 'Grayling',
      size: AnimalSize.fish,
      meatType: MeatType.fish,
      terrains: [TerrainType.waterShallow],
      rarityWeight: 40,
      validWeapons: [ItemType.spear],
      minMeat: 0.5,
      maxMeat: 1.5,
      peltCount: 0,
    ),
    Animal(
      id: 'sturgeon',
      name: 'Baikal Sturgeon',
      size: AnimalSize.fish,
      meatType: MeatType.fish,
      terrains: [TerrainType.waterDeep],
      rarityWeight: 5, // Very Rare
      validWeapons: [ItemType.sword, ItemType.spear],
      minMeat: 20.0,
      maxMeat: 50.0,
      peltCount: 0,
    ),
  ];

  static List<Animal> getAnimalsForTerrain(TerrainType terrain) {
    return allAnimals.where((a) => a.terrains.contains(terrain)).toList();
  }
}
