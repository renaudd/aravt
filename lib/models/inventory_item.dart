import 'dart:convert';

// --- Core Item Model ---

class InventoryItem {
  final String id; // Unique instance ID (e.g., "sword_123xyz")
  final String
      templateId; // The template it came from (e.g., "wep_short_sword")
  final String name;
  final String description;
  final ItemType itemType;
  final ValueType valueType;
  final double baseValue;
  final double weight;
  final String? quality;
  final String iconAssetPath;
  final int spriteIndex;
  final EquipmentSlot? equippableSlot;
  final String
      origin; // [GEMINI-NEW] Origin of the item (e.g., "Mongol", "Chinese")

  InventoryItem({
    required this.id,
    required this.templateId,
    required this.name,
    this.description = '',
    required this.itemType,
    required this.valueType,
    required this.baseValue,
    this.weight = 0.0,
    this.quality,
    this.iconAssetPath = 'assets/images/items/unknown_item.png',
    this.spriteIndex = 0,
    this.equippableSlot,
    this.origin = 'Unknown', // [GEMINI-NEW] Default origin
  });

  Map<String, dynamic> toJson() => {
        '__type': runtimeType.toString(),
        'id': id,
        'templateId': templateId,
        'name': name,
        'description': description,
        'itemType': itemType.name,
        'valueType': valueType.name,
        'baseValue': baseValue,
        'weight': weight,
        'quality': quality,
        'iconAssetPath': iconAssetPath,
        'spriteIndex': spriteIndex,
        'equippableSlot': equippableSlot?.name,
        'origin': origin, // [GEMINI-NEW]
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final type = json['__type'];
    switch (type) {
      case 'Weapon':
        return Weapon.fromJson(json);
      case 'Armor':
        return Armor.fromJson(json);
      case 'Shield':
        return Shield.fromJson(json);
      case 'Relic':
        return Relic.fromJson(json);
      case 'Mount':
        return Mount.fromJson(json);
      case 'Consumable':
        return Consumable.fromJson(json);
      case 'Ammunition':
        return Ammunition.fromJson(json);
      case 'InventoryItem':
      default:
        return InventoryItem(
          id: json['id'],
          templateId: json['templateId'] ?? 'unknown',
          name: json['name'],
          description: json['description'] ?? '',
          itemType: _itemTypeFromName(json['itemType']),
          valueType: _valueTypeFromName(json['valueType']),
          baseValue: (json['baseValue'] as num).toDouble(),
          weight: (json['weight'] as num).toDouble(),
          quality: json['quality'],
          iconAssetPath: json['iconAssetPath'] ?? '',
          spriteIndex: json['spriteIndex'] ?? 0,
          equippableSlot: equipmentSlotFromName(json['equippableSlot']),
          origin: json['origin'] ?? 'Unknown', // [GEMINI-NEW]
        );
    }
  }
}

enum ItemType {
  sword,
  axe,
  mace,
  bow,
  spear,
  lance,
  throwingSpear,
  helmet,
  armor,
  gauntlets,
  boots,
  undergarments,
  shield,
  ring,
  necklace,
  mount,
  consumable,
  ammunition,
  relic,
  misc,
}

enum ValueType { Supply, Treasure }

ItemType _itemTypeFromName(String? name) {
  for (final val in ItemType.values) {
    if (val.name == name) return val;
  }
  return ItemType.misc;
}

ValueType _valueTypeFromName(String? name) {
  for (final val in ValueType.values) {
    if (val.name == name) return val;
  }
  return ValueType.Treasure;
}

enum DamageType { Piercing, Slashing, Blunt }

DamageType _damageTypeFromName(String? name) {
  for (final val in DamageType.values) {
    if (val.name == name) return val;
  }
  return DamageType.Blunt;
}

enum EquipmentSlot {
  helmet,
  necklace,
  armor,
  undergarments,
  gauntlets,
  boots,
  ring,
  melee,
  shield,
  spear,
  longBow,
  shortBow,
  mount,
  trophy,
}

EquipmentSlot? equipmentSlotFromName(String? name) {
  for (final val in EquipmentSlot.values) {
    if (val.name == name) return val;
  }
  return null;
}

class Equipment extends InventoryItem {
  double condition;
  final double maxCondition;

  Equipment({
    required super.id,
    required super.templateId,
    required super.name,
    required super.description,
    required super.itemType,
    required super.valueType,
    required super.baseValue,
    required super.weight,
    required super.quality,
    required super.iconAssetPath,
    required super.spriteIndex,
    required EquipmentSlot slot,
    super.origin = 'Unknown', // [GEMINI-NEW]
    this.condition = 100.0,
    this.maxCondition = 100.0,
  }) : super(equippableSlot: slot);

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'condition': condition,
      'maxCondition': maxCondition,
    });
    return json;
  }
  // Removed generic Equipment.fromJson factory as it's better handled by specific types
  // or the base InventoryItem factory if needed.
}

class Weapon extends Equipment {
  final double baseDamage;
  final double effectiveRange;
  final DamageType damageType;

  Weapon({
    required super.id,
    required super.templateId,
    required super.name,
    required super.description,
    required super.itemType,
    required super.valueType,
    required super.baseValue,
    required super.weight,
    required super.quality,
    required super.iconAssetPath,
    required super.spriteIndex,
    required super.slot,
    required super.condition,
    required super.maxCondition,
    super.origin = 'Unknown', // [GEMINI-NEW]
    required this.damageType,
    this.baseDamage = 0.0,
    this.effectiveRange = 0.0,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'baseDamage': baseDamage,
      'effectiveRange': effectiveRange,
      'damageType': damageType.name,
    });
    return json;
  }

  factory Weapon.fromJson(Map<String, dynamic> json) {
    return Weapon(
      id: json['id'],
      templateId: json['templateId'] ?? 'unknown_weapon',
      name: json['name'],
      description: json['description'] ?? '',
      itemType: _itemTypeFromName(json['itemType']),
      valueType: _valueTypeFromName(json['valueType']),
      baseValue: (json['baseValue'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      quality: json['quality'],
      iconAssetPath: json['iconAssetPath'] ?? '',
      spriteIndex: json['spriteIndex'] ?? 0,
      slot: equipmentSlotFromName(json['equippableSlot'])!,
      condition: (json['condition'] as num).toDouble(),
      maxCondition: (json['maxCondition'] as num).toDouble(),
      damageType: _damageTypeFromName(json['damageType']),
      baseDamage: (json['baseDamage'] as num).toDouble(),

      effectiveRange: (json['effectiveRange'] as num).toDouble(),
      origin: json['origin'] ?? 'Unknown', // [GEMINI-NEW]
    );
  }
}

class Armor extends Equipment {
  final double deflectValue;
  final double damageReductionValue;

  Armor({
    required super.id,
    required super.templateId,
    required super.name,
    required super.description,
    required super.itemType,
    required super.valueType,
    required super.baseValue,
    required super.weight,
    required super.quality,
    required super.iconAssetPath,
    required super.spriteIndex,
    required super.slot,
    required super.condition,
    required super.maxCondition,
    super.origin = 'Unknown', // [GEMINI-NEW]
    this.deflectValue = 0.0,
    this.damageReductionValue = 0.0,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'deflectValue': deflectValue,
      'damageReductionValue': damageReductionValue,
    });
    return json;
  }

  factory Armor.fromJson(Map<String, dynamic> json) {
    return Armor(
      id: json['id'],
      templateId: json['templateId'] ?? 'unknown_armor',
      name: json['name'],
      description: json['description'] ?? '',
      itemType: _itemTypeFromName(json['itemType']),
      valueType: _valueTypeFromName(json['valueType']),
      baseValue: (json['baseValue'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      quality: json['quality'],
      iconAssetPath: json['iconAssetPath'] ?? '',
      spriteIndex: json['spriteIndex'] ?? 0,
      slot: equipmentSlotFromName(json['equippableSlot'])!,
      condition: (json['condition'] as num).toDouble(),
      maxCondition: (json['maxCondition'] as num).toDouble(),
      deflectValue: (json['deflectValue'] as num).toDouble(),

      damageReductionValue: (json['damageReductionValue'] as num).toDouble(),
      origin: json['origin'] ?? 'Unknown', // [GEMINI-NEW]
    );
  }
}

class Shield extends Equipment {
  final double deflectValue;
  final double blockChance;

  Shield({
    required super.id,
    required super.templateId,
    required super.name,
    required super.description,
    super.itemType = ItemType.shield,
    required super.valueType,
    required super.baseValue,
    required super.weight,
    required super.quality,
    required super.iconAssetPath,
    required super.spriteIndex,
    super.slot = EquipmentSlot.shield,
    required super.condition,
    required super.maxCondition,
    super.origin = 'Unknown', // [GEMINI-NEW]
    this.deflectValue = 0.0,
    this.blockChance = 0.0,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'deflectValue': deflectValue,
      'blockChance': blockChance,
    });
    return json;
  }

  factory Shield.fromJson(Map<String, dynamic> json) {
    return Shield(
      id: json['id'],
      templateId: json['templateId'] ?? 'unknown_shield',
      name: json['name'],
      description: json['description'] ?? '',
      // Use default itemType if missing in JSON for older saves
      itemType: json.containsKey('itemType')
          ? _itemTypeFromName(json['itemType'])
          : ItemType.shield,
      valueType: _valueTypeFromName(json['valueType']),
      baseValue: (json['baseValue'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      quality: json['quality'],
      iconAssetPath: json['iconAssetPath'] ?? '',
      spriteIndex: json['spriteIndex'] ?? 0,
      slot:
          equipmentSlotFromName(json['equippableSlot']) ?? EquipmentSlot.shield,
      condition: (json['condition'] as num).toDouble(),
      maxCondition: (json['maxCondition'] as num).toDouble(),
      deflectValue: (json['deflectValue'] as num).toDouble(),

      blockChance: (json['blockChance'] as num).toDouble(),
      origin: json['origin'] ?? 'Unknown', // [GEMINI-NEW]
    );
  }
}

class Relic extends Equipment {
  final String bonusDescription;

  Relic({
    required super.id,
    required super.templateId,
    required super.name,
    required super.description,
    super.itemType = ItemType.relic,
    required super.valueType,
    required super.baseValue,
    required super.weight,
    required super.quality,
    required super.iconAssetPath,
    required super.spriteIndex,
    required super.slot,
    required super.condition,
    required super.maxCondition,
    super.origin = 'Unknown', // [GEMINI-NEW]
    this.bonusDescription = '',
  }) : assert(slot == EquipmentSlot.ring || slot == EquipmentSlot.necklace);

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'bonusDescription': bonusDescription,
    });
    return json;
  }

  factory Relic.fromJson(Map<String, dynamic> json) {
    return Relic(
      id: json['id'],
      templateId: json['templateId'] ?? 'unknown_relic',
      name: json['name'],
      description: json['description'] ?? '',
      itemType: _itemTypeFromName(json['itemType']),
      valueType: _valueTypeFromName(json['valueType']),
      baseValue: (json['baseValue'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      quality: json['quality'],
      iconAssetPath: json['iconAssetPath'] ?? '',
      spriteIndex: json['spriteIndex'] ?? 0,
      slot: equipmentSlotFromName(json['equippableSlot'])!,
      condition: (json['condition'] as num).toDouble(),
      maxCondition: (json['maxCondition'] as num).toDouble(),

      bonusDescription: json['bonusDescription'] ?? '',
      origin: json['origin'] ?? 'Unknown', // [GEMINI-NEW]
    );
  }
}

class Mount extends Equipment {
  final int health;
  final int temperament;
  final int speed;
  final int might;
  final int bonding;
  final int exhaustion;

  Mount({
    required super.id,
    required super.templateId,
    required super.name,
    required super.description,
    super.itemType = ItemType.mount,
    required super.valueType,
    required super.baseValue,
    required super.weight,
    required super.quality,
    required super.iconAssetPath,
    required super.spriteIndex,
    super.slot = EquipmentSlot.mount,
    required super.condition,
    required super.maxCondition,
    super.origin = 'Unknown', // [GEMINI-NEW]
    this.health = 7,
    this.temperament = 5,
    this.speed = 5,
    this.might = 5,
    this.bonding = 0,
    this.exhaustion = 0,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'health': health,
      'temperament': temperament,
      'speed': speed,
      'might': might,
      'bonding': bonding,
      'exhaustion': exhaustion,
    });
    return json;
  }

  factory Mount.fromJson(Map<String, dynamic> json) {
    return Mount(
      id: json['id'],
      templateId: json['templateId'] ?? 'mnt_horse', // Default if missing
      name: json['name'],
      description: json['description'] ?? '',
      itemType: _itemTypeFromName(json['itemType']),
      valueType: _valueTypeFromName(json['valueType']),
      baseValue: (json['baseValue'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      quality: json['quality'],
      iconAssetPath: json['iconAssetPath'] ?? '',
      spriteIndex: json['spriteIndex'] ?? 0,
      slot:
          equipmentSlotFromName(json['equippableSlot']) ?? EquipmentSlot.mount,
      condition: (json['condition'] as num).toDouble(),
      maxCondition: (json['maxCondition'] as num).toDouble(),
      health: json['health'] ?? 7,
      temperament: json['temperament'] ?? 5,
      speed: json['speed'] ?? 5,
      might: json['might'] ?? 5,
      bonding: json['bonding'] ?? 0,

      exhaustion: json['exhaustion'] ?? 0,
      origin: json['origin'] ?? 'Unknown', // [GEMINI-NEW]
    );
  }
}

class Consumable extends InventoryItem {
  final String effect;

  Consumable({
    required super.id,
    required super.templateId,
    required super.name,
    required super.description,
    super.itemType = ItemType.consumable,
    required super.valueType,
    required super.baseValue,
    required super.weight,
    required super.iconAssetPath,
    required super.spriteIndex,
    super.origin = 'Unknown', // [GEMINI-NEW]
    this.effect = '',
  }) : super(equippableSlot: null);

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'effect': effect,
    });
    return json;
  }

  factory Consumable.fromJson(Map<String, dynamic> json) {
    return Consumable(
      id: json['id'],
      templateId: json['templateId'] ?? 'unknown_consumable',
      name: json['name'],
      description: json['description'] ?? '',
      itemType: _itemTypeFromName(json['itemType']),
      valueType: _valueTypeFromName(json['valueType']),
      baseValue: (json['baseValue'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      iconAssetPath: json['iconAssetPath'] ?? '',
      spriteIndex: json['spriteIndex'] ?? 0,
      effect: json['effect'] ?? '',
      origin: json['origin'] ?? 'Unknown', // [GEMINI-NEW]
    );
  }
}

class Ammunition extends InventoryItem {
  final double damageBonus;
  final String specialEffect;

  Ammunition({
    required super.id,
    required super.templateId,
    required super.name,
    required super.description,
    super.itemType = ItemType.ammunition,
    required super.valueType,
    required super.baseValue,
    required super.weight,
    required super.quality,
    required super.iconAssetPath,
    required super.spriteIndex,
    super.origin = 'Unknown', // [GEMINI-NEW]
    this.damageBonus = 0.0,
    this.specialEffect = '',
  }) : super(equippableSlot: null);

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'damageBonus': damageBonus,
      'specialEffect': specialEffect,
    });
    return json;
  }

  factory Ammunition.fromJson(Map<String, dynamic> json) {
    return Ammunition(
      id: json['id'],
      templateId: json['templateId'] ?? 'unknown_ammo',
      name: json['name'],
      description: json['description'] ?? '',
      itemType: _itemTypeFromName(json['itemType']),
      valueType: _valueTypeFromName(json['valueType']),
      baseValue: (json['baseValue'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      quality: json['quality'],
      iconAssetPath: json['iconAssetPath'] ?? '',
      spriteIndex: json['spriteIndex'] ?? 0,
      damageBonus: (json['damageBonus'] as num).toDouble(),

      specialEffect: json['specialEffect'] ?? '',
      origin: json['origin'] ?? 'Unknown', // [GEMINI-NEW]
    );
  }
}
