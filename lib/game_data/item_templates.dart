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

// lib/game_data/item_templates.dart
import 'dart:math';
import 'package:aravt/models/inventory_item.dart';

// --- Base Template Class ---
// This holds the "blueprint" for an item.

abstract class BaseItemTemplate {
  final String templateId;
  final String defaultOrigin;
  final String name;
  final String description;
  final ItemType itemType;
  final ValueType valueType;
  final double baseValue; // The "Excellent" or "Good" quality value
  final double baseWeight;
  final String iconAssetPath;
  final int spriteIndex;
  final EquipmentSlot? equippableSlot;

  BaseItemTemplate({
    required this.templateId,
    required this.name,
    required this.description,
    required this.itemType,
    required this.valueType,
    required this.baseValue,
    required this.baseWeight,
    required this.iconAssetPath,
    this.spriteIndex = 0,
    this.equippableSlot,
    this.defaultOrigin = 'Unknown',
  });

  // Abstract method to be implemented by subclasses
  InventoryItem createInstance(
    String quality,
    double condition,
    double maxCondition,
    double finalValue, {
    String? origin,
  });
}

// --- Template Subclasses ---

class WeaponTemplate extends BaseItemTemplate {
  final double baseDamage;
  final double effectiveRange;
  final DamageType damageType;

  WeaponTemplate({
    required super.templateId,
    required super.name,
    required super.description,
    required super.itemType,
    required super.valueType,
    required super.baseValue,
    required super.baseWeight,
    required super.iconAssetPath,
    required super.equippableSlot,
    required this.baseDamage,
    required this.effectiveRange,
    required this.damageType,
    super.defaultOrigin,
  });

  @override
  Weapon createInstance(
    String quality,
    double condition,
    double maxCondition,
    double finalValue, {
    String? origin,
  }) {
    // Quality modifier for damage (example)
    double damageMultiplier = 1.0;
    if (quality == 'Excellent') damageMultiplier = 1.2;
    if (quality == 'Humble') damageMultiplier = 0.8;
    if (quality == 'Worn') damageMultiplier = 0.6;

    double finalDamage = (baseDamage * damageMultiplier).roundToDouble();

    return Weapon(
      id: '${templateId}_${DateTime.now().microsecondsSinceEpoch}',
      templateId: templateId,
      name: '$quality $name',
      description: description,
      itemType: itemType,
      valueType: valueType,
      baseValue: finalValue,
      weight: baseWeight,
      quality: quality,
      iconAssetPath: iconAssetPath,
      spriteIndex: spriteIndex,
      slot: equippableSlot!,
      condition: condition,
      maxCondition: maxCondition,
      damageType: damageType,
      baseDamage: finalDamage,
      effectiveRange: effectiveRange,
      origin: origin ?? defaultOrigin,
    );
  }
}

class ArmorTemplate extends BaseItemTemplate {
  final double baseDeflect;
  final double baseDamageReduction;

  ArmorTemplate({
    required super.templateId,
    required super.name,
    required super.description,
    required super.itemType,
    required super.valueType,
    required super.baseValue,
    required super.baseWeight,
    required super.iconAssetPath,
    required super.equippableSlot,
    required this.baseDeflect,
    required this.baseDamageReduction,
    super.defaultOrigin,
  });

  @override
  Armor createInstance(
    String quality,
    double condition,
    double maxCondition,
    double finalValue, {
    String? origin,
  }) {
    // Quality modifier for protection (example)
    double protectionMultiplier = 1.0;
    if (quality == 'Excellent') protectionMultiplier = 1.2;
    if (quality == 'Humble') protectionMultiplier = 0.8;
    if (quality == 'Worn') protectionMultiplier = 0.6;

    double finalDeflect = (baseDeflect * protectionMultiplier).roundToDouble();
    double finalReduction =
        (baseDamageReduction * protectionMultiplier).roundToDouble();

    return Armor(
      id: '${templateId}_${DateTime.now().microsecondsSinceEpoch}',
      templateId: templateId,
      name: '$quality $name',
      description: description,
      itemType: itemType,
      valueType: valueType,
      baseValue: finalValue,
      weight: (baseWeight * protectionMultiplier).clamp(0.1, 50.0),
      quality: quality,
      iconAssetPath: iconAssetPath,
      spriteIndex: spriteIndex,
      slot: equippableSlot!,
      condition: condition,
      maxCondition: maxCondition,
      deflectValue: finalDeflect,
      damageReductionValue: finalReduction,
      origin: origin ?? defaultOrigin,
    );
  }
}

class ShieldTemplate extends BaseItemTemplate {
  final double baseDeflect;
  final double baseBlockChance;

  ShieldTemplate({
    required super.templateId,
    required super.name,
    required super.description,
    required super.itemType,
    required super.valueType,
    required super.baseValue,
    required super.baseWeight,
    required super.iconAssetPath,
    required super.equippableSlot,
    required this.baseDeflect,
    required this.baseBlockChance,
    super.defaultOrigin,
  });

  @override
  Shield createInstance(
    String quality,
    double condition,
    double maxCondition,
    double finalValue, {
    String? origin,
  }) {
    double protectionMultiplier = 1.0;
    if (quality == 'Excellent') protectionMultiplier = 1.2;
    if (quality == 'Humble') protectionMultiplier = 0.8;
    if (quality == 'Worn') protectionMultiplier = 0.6;

    double finalDeflect = (baseDeflect * protectionMultiplier).roundToDouble();

    return Shield(
      id: '${templateId}_${DateTime.now().microsecondsSinceEpoch}',
      templateId: templateId,
      name: '$quality $name',
      description: description,
      itemType: itemType,
      valueType: valueType,
      baseValue: finalValue,
      weight: (baseWeight * protectionMultiplier).clamp(0.5, 20.0),
      quality: quality,
      iconAssetPath: iconAssetPath,
      spriteIndex: spriteIndex,
      slot: equippableSlot!,
      condition: condition,
      maxCondition: maxCondition,
      deflectValue: finalDeflect,
      blockChance: (baseBlockChance * protectionMultiplier).clamp(0.1, 0.9),
      origin: origin ?? defaultOrigin,
    );
  }
}

class RelicTemplate extends BaseItemTemplate {
  final String bonusDescription;

  RelicTemplate({
    required super.templateId,
    required super.name,
    required super.description,
    required super.itemType,
    required super.valueType,
    required super.baseValue,
    required super.baseWeight,
    required super.iconAssetPath,
    required super.equippableSlot,
    this.bonusDescription = '',
    super.defaultOrigin,
  });

  @override
  Relic createInstance(
    String quality,
    double condition,
    double maxCondition,
    double finalValue, {
    String? origin,
  }) {
    return Relic(
      id: '${templateId}_${DateTime.now().microsecondsSinceEpoch}',
      templateId: templateId,
      name: '$quality $name',
      description: description,
      itemType: itemType,
      valueType: valueType,
      baseValue: finalValue,
      weight: baseWeight,
      quality: quality,
      iconAssetPath: iconAssetPath,
      spriteIndex: spriteIndex,
      slot: equippableSlot!,
      condition: condition,
      maxCondition: maxCondition,
      bonusDescription: bonusDescription,
      origin: origin ?? defaultOrigin,
    );
  }
}

class MountTemplate extends BaseItemTemplate {
  final int baseHealth;
  final int baseSpeed;
  // ... other mount stats

  MountTemplate({
    required super.templateId,
    required super.name,
    required super.description,
    required super.itemType,
    required super.valueType,
    required super.baseValue,
    required super.baseWeight,
    required super.iconAssetPath,
    required super.equippableSlot,
    required this.baseHealth,
    required this.baseSpeed,
    super.defaultOrigin,
  });

  @override
  Mount createInstance(
    String quality,
    double condition,
    double maxCondition,
    double finalValue, {
    String? origin,
  }) {
    double statMultiplier = 1.0;
    if (quality == 'Superior') statMultiplier = 1.2;
    if (quality == 'Subpar') statMultiplier = 0.8;

    return Mount(
      id: '${templateId}_${DateTime.now().microsecondsSinceEpoch}',
      templateId: templateId,
      name: ItemDatabase.getRandomHorseName(),
      description: 'A $quality steppe horse.',
      itemType: itemType,
      valueType: valueType,
      baseValue: finalValue,
      weight: baseWeight,
      quality: quality,
      iconAssetPath: iconAssetPath,
      spriteIndex: spriteIndex,
      slot: equippableSlot!,
      condition: condition,
      maxCondition: maxCondition,
      health: (baseHealth * statMultiplier).round(),
      temperament: 5,
      speed: (baseSpeed * statMultiplier).round(),
      might: 5,
      bonding: 0,
      exhaustion: 0,
      origin: origin ?? defaultOrigin,
    );
  }
}

class ConsumableTemplate extends BaseItemTemplate {
  final String effect;

  ConsumableTemplate({
    required super.templateId,
    required super.name,
    required super.description,
    required super.itemType,
    required super.valueType,
    required super.baseValue,
    required super.baseWeight,
    required super.iconAssetPath,
    required this.effect,
    super.defaultOrigin,
  }) : super(equippableSlot: null); // Consumables are not equippable

  @override
  Consumable createInstance(
    String quality,
    double condition,
    double maxCondition,
    double finalValue, {
    String? origin,
  }) {
    return Consumable(
      id: '${templateId}_${DateTime.now().microsecondsSinceEpoch}',
      templateId: templateId,
      name: name,
      description: description,
      itemType: itemType,
      valueType: valueType,
      baseValue: finalValue,
      weight: baseWeight,
      iconAssetPath: iconAssetPath,
      spriteIndex: spriteIndex,
      effect: effect,
      origin: origin ?? defaultOrigin,
    );
  }
}

// --- The Master Database ---

class ItemDatabase {
  static final Random _random = Random();
  static final Map<String, BaseItemTemplate> _templates = {};

  // Qualities for different item types
  static const List<String> _weaponArmorQualities = [
    'Humble',
    'Good',
    'Excellent',
    'Worn'
  ];
  static const List<String> _trophyQualities = ['Simple', 'Ornate', 'Gemmed'];
  static const List<String> _mountQualities = ['Subpar', 'Average', 'Superior'];
  static const List<String> _horseNames = [
    'Shonkhor',
    'Bura',
    'Zor',
    'Khatan',
    'Chuluun',
    'Naran',
    'Gerel',
    'Altan',
    'Batu',
    'Chinua',
    'Dorn',
    'Enkh',
    'Gansukh',
    'Hulan',
    'Ider',
    'Jargal',
    'Khasar',
    'Lkhagva',
    'Munkh',
    'Ochir',
    'Puren',
    'Qara',
    'Saran',
    'Temujin',
    'Ulan',
    'Vanchig',
    'Yul',
    'Arslan',
    'Bataar',
    'Bayar',
    'Bold',
    'Chimeg',
    'Delger',
    'Erdene',
    'Ganbaatar',
    'Khaliun',
    'Munkhbat',
    'Narangerel',
    'Odgerel',
    'Otgon',
    'Sukhbat',
    'Tsetseg',
    'Tuya',
    'Uranchimeg',
    'Zaya',
    'Zolboo',
    'Alagh',
    'Boro',
    'Khula',
    'Sharga',
    'Zeerd',
    'Tsagaan',
    'Khar',
    'Khongor',
    'Saaral'
  ];

  static String getRandomHorseName() {
    return _horseNames[_random.nextInt(_horseNames.length)];
  }

  // Call this once at game start-up
  static void initialize() {
    _templates.clear(); // Clear for hot reload

    // --- WEAPONS ---
    _templates['wep_short_bow'] = WeaponTemplate(
      templateId: 'wep_short_bow',
      name: 'Short Bow',
      description: 'A standard steppe short bow.',
      itemType: ItemType.bow,
      valueType: ValueType.Supply,
      baseValue: 40.0,
      baseWeight: 2.0,
      iconAssetPath: 'assets/images/items/bows_items.png',
      equippableSlot: EquipmentSlot.shortBow,
      baseDamage: 7.0,
      effectiveRange: 50.0,
      damageType: DamageType.Piercing,
    );
    _templates['wep_long_bow'] = WeaponTemplate(
      templateId: 'wep_long_bow',
      name: 'Long Bow',
      description: 'A powerful long bow.',
      itemType: ItemType.bow,
      valueType: ValueType.Supply,
      baseValue: 60.0,
      baseWeight: 3.0,
      iconAssetPath: 'assets/images/items/bows_items.png',
      equippableSlot: EquipmentSlot.longBow,
      baseDamage: 10.0,
      effectiveRange: 100.0,
      damageType: DamageType.Piercing,
    );
    _templates['wep_sword'] = WeaponTemplate(
      templateId: 'wep_sword',
      name: 'Sword',
      description: 'A single-edged steppe sword.',
      itemType: ItemType.sword,
      valueType: ValueType.Supply,
      baseValue: 50.0,
      baseWeight: 3.5,
      iconAssetPath: 'assets/images/items/swords_items.png',
      equippableSlot: EquipmentSlot.melee,
      baseDamage: 8.0,
      effectiveRange: 2.0,
      damageType: DamageType.Slashing,
    );
    _templates['wep_iron_sword'] = WeaponTemplate(
      templateId: 'wep_iron_sword',
      name: 'Iron Sword',
      description: 'A finely forged iron sword.',
      itemType: ItemType.sword,
      valueType: ValueType.Supply,
      baseValue: 80.0,
      baseWeight: 4.0,
      iconAssetPath: 'assets/images/items/swords_items.png',
      equippableSlot: EquipmentSlot.melee,
      baseDamage: 12.0,
      effectiveRange: 2.0,
      damageType: DamageType.Slashing,
    );
    _templates['wep_lance'] = WeaponTemplate(
      templateId: 'wep_lance',
      name: 'Lance Spear',
      description: 'A long spear for cavalry charges.',
      itemType: ItemType.spear,
      valueType: ValueType.Supply,
      baseValue: 55.0,
      baseWeight: 4.5,
      iconAssetPath: 'assets/images/items/spears_items.png',
      equippableSlot: EquipmentSlot.spear,
      baseDamage: 12.0,
      effectiveRange: 5.0,
      damageType: DamageType.Piercing,
    );
    _templates['wep_spear'] = WeaponTemplate(
      templateId: 'wep_spear',
      name: 'Spear',
      description: 'A standard spear.',
      itemType: ItemType.spear,
      valueType: ValueType.Supply,
      baseValue: 40.0,
      baseWeight: 3.0,
      iconAssetPath: 'assets/images/items/spears_items.png',
      equippableSlot: EquipmentSlot.spear,
      baseDamage: 8.0,
      effectiveRange: 4.0,
      damageType: DamageType.Piercing,
    );
    _templates['wep_throwing_spear'] = WeaponTemplate(
      templateId: 'wep_throwing_spear',
      name: 'Throwing Spear',
      description: 'A light spear for throwing.',
      itemType: ItemType.throwingSpear,
      valueType: ValueType.Supply,
      baseValue: 20.0,
      baseWeight: 1.5,
      iconAssetPath: 'assets/images/items/spears_items.png',
      equippableSlot: EquipmentSlot.spear,
      baseDamage: 5.0,
      effectiveRange: 15.0,
      damageType: DamageType.Piercing,
    );

    // --- ARMOR ---
    _templates['arm_leather_lamellar'] = ArmorTemplate(
      templateId: 'arm_leather_lamellar',
      name: 'Leather Lamellar',
      description: 'Armor made of leather scales.',
      itemType: ItemType.armor,
      valueType: ValueType.Supply,
      baseValue: 80.0,
      baseWeight: 12.0,
      iconAssetPath: 'assets/images/items/armors_items.png',
      equippableSlot: EquipmentSlot.armor,
      baseDeflect: 7.0,
      baseDamageReduction: 4.0,
    );
    _templates['arm_leather_lamellar'] = ArmorTemplate(
      templateId: 'arm_leather_lamellar',
      name: 'Leather Lamellar',
      description: 'Armor made of leather scales.',
      itemType: ItemType.armor,
      valueType: ValueType.Supply,
      baseValue: 80.0,
      baseWeight: 12.0,
      iconAssetPath: 'assets/images/items/armors_items.png',
      equippableSlot: EquipmentSlot.armor,
      baseDeflect: 7.0,
      baseDamageReduction: 4.0,
    );
    _templates['arm_undergarments'] = ArmorTemplate(
      templateId: 'arm_undergarments',
      name: 'Undergarments',
      description: 'Basic undergarments.',
      itemType: ItemType.undergarments,
      valueType: ValueType.Treasure, // As per our logic
      baseValue: 10.0,
      baseWeight: 0.5,
      iconAssetPath: 'assets/images/items/undergarments_items.png',
      equippableSlot: EquipmentSlot.undergarments,
      baseDeflect: 1.0,
      baseDamageReduction: 0.0,
    );
    _templates['arm_helmet'] = ArmorTemplate(
      templateId: 'arm_helmet',
      name: 'Helmet',
      description: 'A leather and iron helmet.',
      itemType: ItemType.helmet,
      valueType: ValueType.Supply,
      baseValue: 30.0,
      baseWeight: 3.0,
      iconAssetPath: 'assets/images/items/helmets_items.png',
      equippableSlot: EquipmentSlot.helmet,
      baseDeflect: 4.0,
      baseDamageReduction: 1.0,
    );
    _templates['arm_body'] = ArmorTemplate(
      templateId: 'arm_body',
      name: 'Body Armor',
      description: 'Lamellar or leather body armor.',
      itemType: ItemType.armor,
      valueType: ValueType.Supply,
      baseValue: 70.0,
      baseWeight: 10.0,
      iconAssetPath: 'assets/images/items/armors_items.png',
      equippableSlot: EquipmentSlot.armor,
      baseDeflect: 6.0,
      baseDamageReduction: 3.0,
    );
    _templates['arm_gauntlets'] = ArmorTemplate(
      templateId: 'arm_gauntlets',
      name: 'Gauntlets',
      description: 'Leather gauntlets.',
      itemType: ItemType.gauntlets,
      valueType: ValueType.Supply,
      baseValue: 25.0,
      baseWeight: 2.0,
      iconAssetPath: 'assets/images/items/gauntlets_items.png',
      equippableSlot: EquipmentSlot.gauntlets,
      baseDeflect: 2.0,
      baseDamageReduction: 1.0,
    );
    _templates['arm_boots'] = ArmorTemplate(
      templateId: 'arm_boots',
      name: 'Boots',
      description: 'Sturdy leather boots.',
      itemType: ItemType.boots,
      valueType: ValueType.Supply,
      baseValue: 30.0,
      baseWeight: 2.5,
      iconAssetPath: 'assets/images/items/boots_items.png',
      equippableSlot: EquipmentSlot.boots,
      baseDeflect: 2.0,
      baseDamageReduction: 1.0,
    );

    // --- SHIELD ---
    _templates['shd_round'] = ShieldTemplate(
      templateId: 'shd_round',
      name: 'Round Shield',
      description: 'A wooden round shield.',
      itemType: ItemType.shield,
      valueType: ValueType.Supply,
      baseValue: 45.0,
      baseWeight: 5.0,
      iconAssetPath: 'assets/images/items/shields_items.png',
      equippableSlot: EquipmentSlot.shield,
      baseDeflect: 5.0,
      baseBlockChance: 0.4,
    );

    // --- RELICS ---
    _templates['rel_necklace'] = RelicTemplate(
        templateId: 'rel_necklace',
        name: 'Necklace',
        description: 'A simple necklace.',
        itemType: ItemType.relic,
        valueType: ValueType.Treasure,
        baseValue: 100.0,
        baseWeight: 0.1,
        iconAssetPath: 'assets/images/items/necklaces_items.png',
        equippableSlot: EquipmentSlot.necklace,
        bonusDescription: '+1 Courage (mock)');
    _templates['rel_ring'] = RelicTemplate(
        templateId: 'rel_ring',
        name: 'Ring',
        description: 'A simple ring.',
        itemType: ItemType.ring,
        valueType: ValueType.Treasure,
        baseValue: 80.0,
        baseWeight: 0.1,
        iconAssetPath: 'assets/images/items/rings_items.png',
        equippableSlot: EquipmentSlot.ring,
        bonusDescription: '+1 Charisma (mock)');

    // --- MOUNTS ---
    _templates['mnt_horse'] = MountTemplate(
      templateId: 'mnt_horse',
      name: 'Steppe Horse', // This name will be overridden by random names
      description: 'A steppe horse.',
      itemType: ItemType.mount,
      valueType: ValueType.Supply,
      baseValue: 150.0,
      baseWeight: 400.0,
      iconAssetPath: 'assets/images/horses.png',
      equippableSlot: EquipmentSlot.mount,
      baseHealth: 7,
      baseSpeed: 5,
    );

    // --- CONSUMABLES ---
    _templates['con_dried_meat'] = ConsumableTemplate(
        templateId: 'con_dried_meat',
        name: 'Dried Meat',
        description: 'Salty and tough...',
        itemType: ItemType.consumable,
        valueType: ValueType.Supply,
        baseValue: 1.0,
        baseWeight: 0.2,
        iconAssetPath: 'assets/images/items/consumables_items.png',
        effect: 'Restores a small amount of stamina.');

    _templates['consumable_wine'] = ConsumableTemplate(
        templateId: 'consumable_wine',
        name: 'Wine Skin',
        description: 'A skin of fermented grape wine.',
        itemType: ItemType.consumable,
        valueType: ValueType.Treasure,
        baseValue: 10.0,
        baseWeight: 1.0,
        iconAssetPath:
            'assets/images/items/consumables_items.png', // Placeholder
        effect: 'Improves morale, but may have side effects.');

    _templates['con_arrows_short'] = ConsumableTemplate(
        templateId: 'con_arrows_short',
        name: 'Short Bow Arrows',
        description: 'A bundle of 20 short bow arrows.',
        itemType: ItemType.consumable,
        valueType: ValueType.Supply,
        baseValue: 4.0,
        baseWeight: 0.8,
        iconAssetPath: 'assets/images/items/consumables_items.png',
        effect: 'Ammunition for short bows.');
    _templates['con_arrows_long'] = ConsumableTemplate(
        templateId: 'con_arrows_long',
        name: 'Long Bow Arrows',
        description: 'A bundle of 20 long bow arrows.',
        itemType: ItemType.consumable,
        valueType: ValueType.Supply,
        baseValue: 6.0,
        baseWeight: 1.2,
        iconAssetPath: 'assets/images/items/consumables_items.png',
        effect: 'Ammunition for long bows.');
    _templates['con_rope'] = ConsumableTemplate(
        templateId: 'con_rope',
        name: 'Coil of Rope',
        description: 'A sturdy hempen rope.',
        itemType: ItemType.consumable,
        valueType: ValueType.Supply,
        baseValue: 2.0,
        baseWeight: 2.0,
        iconAssetPath:
            'assets/images/items/consumables_items.png', // Placeholder
        effect: 'Useful for various tasks.');
    _templates['con_water'] = ConsumableTemplate(
        templateId: 'con_water',
        name: 'Waterskin',
        description: 'A skin filled with fresh water.',
        itemType: ItemType.consumable,
        valueType: ValueType.Supply,
        baseValue: 0.5,
        baseWeight: 1.0,
        iconAssetPath:
            'assets/images/items/consumables_items.png', // Placeholder
        effect: 'Quenches thirst.');

    // Added missing templates
    _templates['relic_jade_figurine'] = RelicTemplate(
        templateId: 'relic_jade_figurine',
        name: 'Jade Figurine',
        description: 'A delicately carved jade figure.',
        itemType: ItemType.relic,
        valueType: ValueType.Treasure,
        baseValue: 200.0,
        baseWeight: 0.5,
        iconAssetPath: 'assets/images/items/relics_items.png',
        equippableSlot: EquipmentSlot.trophy,
        bonusDescription: '+2 Culture');
    _templates['trade_pelt'] = ConsumableTemplate(
        templateId: 'trade_pelt',
        name: 'Animal Pelt',
        description: 'A pelt for trade.',
        itemType: ItemType.consumable,
        valueType: ValueType.Supply,
        baseValue: 10.0,
        baseWeight: 2.0,
        iconAssetPath: 'assets/images/items/consumables_items.png',
        effect: 'Can be traded.');
  }

  // --- The new Universal Item Creator ---
  static InventoryItem? createItemInstance(String templateId,
      {String? forcedQuality, String? origin}) {
    final template = _templates[templateId];
    if (template == null) {
      print('Error: No item template found for ID $templateId');
      return null;
    }

    // 1. Determine Quality
    String quality;
    if (forcedQuality != null) {
      quality = forcedQuality;
    } else {
      // Determine quality list based on type
      List<String> qualityList = _weaponArmorQualities; // Default
      if (template.itemType == ItemType.relic) {
        qualityList = _trophyQualities;
      } else if (template.itemType == ItemType.mount) {
        qualityList = _mountQualities;
      } else if (template.itemType == ItemType.consumable) {
        // Consumables have no quality, just create and return
        return (template as ConsumableTemplate).createInstance(
            'Standard', 1, 1, template.baseValue,
            origin: origin);
      }
      quality = qualityList[_random.nextInt(qualityList.length)];
    }

    // 2. Determine Value, Condition based on Quality
    double valueMultiplier = 1.0;
    double conditionMultiplier = 1.0;
    double maxCondition = 100.0;

    // Check for weapon/armor qualities
    if (_weaponArmorQualities.contains(quality)) {
      maxCondition = (60.0 + _random.nextInt(61)); // Base 60-120
      switch (quality) {
        case 'Excellent':
          valueMultiplier = 1.5;
          conditionMultiplier = 1.2;
          break;
        case 'Good':
          // Base, no change
          break;
        case 'Humble':
          valueMultiplier = 0.7;
          conditionMultiplier = 0.8;
          break;
        case 'Worn':
          valueMultiplier = 0.5;
          conditionMultiplier = 0.6;
          break;
      }
    }
    // Check for relic qualities
    else if (_trophyQualities.contains(quality)) {
      maxCondition = 100.0; // Relics don't degrade
      switch (quality) {
        case 'Gemmed':
          valueMultiplier = 5.0;
          break;
        case 'Ornate':
          valueMultiplier = 2.0;
          break;
        case 'Simple':
          // Base, no change
          break;
      }
    }
    // Check for mount qualities
    else if (_mountQualities.contains(quality)) {
      maxCondition = (template as MountTemplate).baseHealth * 10.0;
      switch (quality) {
        case 'Superior':
          valueMultiplier = 1.5;
          conditionMultiplier = 1.2;
          break;
        case 'Average':
          // Base, no change
          break;
        case 'Subpar':
          valueMultiplier = 0.7;
          conditionMultiplier = 0.8;
          break;
      }
    }

    double finalMaxCondition =
        (maxCondition * conditionMultiplier).roundToDouble();
    double currentCondition =
        (finalMaxCondition * (0.6 + _random.nextDouble() * 0.4))
            .clamp(0.1, finalMaxCondition); // 60-100%
    double finalValue = (template.baseValue * valueMultiplier).roundToDouble();

    // 3. Create the instance using the template's factory method
    return template.createInstance(
      quality,
      currentCondition,
      finalMaxCondition,
      finalValue,
      origin: origin,
    );
  }
}
