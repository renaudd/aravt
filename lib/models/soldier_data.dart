// lib/models/soldier_data.dart

import 'dart:math';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/models/aravt_models.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:flutter/material.dart'; // For Color
import 'package:aravt/game_data/item_templates.dart';

class RelationshipValues {
  double admiration;
  double respect;
  double fear;
  double loyalty;

  RelationshipValues({
    this.admiration = 2.5,
    this.respect = 2.5,
    this.fear = 2.0,
    this.loyalty = 2.5,
  });

  Map<String, dynamic> toJson() => {
        'admiration': admiration,
        'respect': respect,
        'fear': fear,
        'loyalty': loyalty,
      };

  factory RelationshipValues.fromJson(Map<String, dynamic> json) {
    return RelationshipValues(
      admiration: (json['admiration'] as num?)?.toDouble() ?? 2.5,
      respect: (json['respect'] as num?)?.toDouble() ?? 2.5,
      fear: (json['fear'] as num?)?.toDouble() ?? 2.0,
      loyalty: (json['loyalty'] as num?)?.toDouble() ?? 2.5,
    );
  }

  void updateAdmiration(double amount) {
    admiration = (admiration + amount).clamp(0.0, 5.0);
  }

  void updateRespect(double amount) {
    respect = (respect + amount).clamp(0.0, 5.0);
  }

  void updateFear(double amount) {
    fear = (fear + amount).clamp(0.0, 5.0);
  }

  void updateLoyalty(double amount) {
    loyalty = (loyalty + amount).clamp(0.0, 5.0);
  }
}

enum SoldierRole { soldier, aravtCaptain, hordeLeader }

enum ReligionType {
  none,
  christian,
  zoroastrian,
  muslim,
  hindu,
  buddhist,
  tengri
}

enum ReligionIntensity { atheist, fervent, agnostic, syncretic, normal }

enum Zodiac {
  rat,
  ox,
  tiger,
  rabbit,
  dragon,
  snake,
  horse,
  goat,
  monkey,
  rooster,
  dog,
  pig
}

enum GiftOriginPreference {
  allAppreciative,
  unappreciative,
  fromHome,
  fromRival,
  muslim,
  buddhist,
  christian,
  hindu,
  zoroastrian,
  tengri,
  chinese,
  russian,
  european,
  arab,
  indian
}

enum GiftTypePreference {
  horse,
  jewelry,
  helmet,
  armor,
  gauntlets,
  boots,
  sword,
  spear,
  bow,
  supplies,
  treasure
}

enum SpecialSkill { falconer, surgeon, tracker }

enum SoldierAttribute {
  wanderlust,
  peacemaker,
  bully,
  mentor,
  superstitious,
  gambler,
  poet,
  conservative,
  glorySeeker,
  forgiving,
  grudgeHolder,
  gossip,
  skeptic,
  surgeonAttribute,
  horseWhisperer,
  shepherd,
  talentScout,
  survivalist,
  prophet,
  curmudgeon,
  gregarious,
  coldResistant,
  storyTeller,
  artist,
  murderer,
  inept
}

enum StartingInjuryType {
  none,
  oldScarLeftArm,
  limpRightLeg,
  damagedEyeLeft,
  fingersMissingRightHand,
  chronicBackPain
}

SoldierRole _soldierRoleFromName(String? name) {
  for (final value in SoldierRole.values) {
    if (value.name == name) return value;
  }
  return SoldierRole.soldier;
}

ReligionType _religionTypeFromName(String? name) {
  for (final value in ReligionType.values) {
    if (value.name == name) return value;
  }
  return ReligionType.none;
}

ReligionIntensity _religionIntensityFromName(String? name) {
  for (final value in ReligionIntensity.values) {
    if (value.name == name) return value;
  }
  return ReligionIntensity.normal;
}

Zodiac _zodiacFromName(String? name) {
  for (final value in Zodiac.values) {
    if (value.name == name) return value;
  }
  return Zodiac.rat;
}

GiftOriginPreference _giftOriginPreferenceFromName(String? name) {
  for (final value in GiftOriginPreference.values) {
    if (value.name == name) return value;
  }
  return GiftOriginPreference.allAppreciative;
}

GiftTypePreference _giftTypePreferenceFromName(String? name) {
  for (final value in GiftTypePreference.values) {
    if (value.name == name) return value;
  }
  return GiftTypePreference.supplies;
}

List<SpecialSkill> _specialSkillListFromJson(List<dynamic>? jsonList) {
  if (jsonList == null) return [];
  return jsonList
      .map((name) {
        for (final value in SpecialSkill.values) {
          if (value.name == name) return value;
        }
        return null;
      })
      .whereType<SpecialSkill>()
      .toList();
}

List<SoldierAttribute> _soldierAttributeListFromJson(List<dynamic>? jsonList) {
  if (jsonList == null) return [];
  return jsonList
      .map((name) {
        for (final value in SoldierAttribute.values) {
          if (value.name == name) return value;
        }
        return null;
      })
      .whereType<SoldierAttribute>()
      .toList();
}

StartingInjuryType _startingInjuryTypeFromName(String? name) {
  for (final value in StartingInjuryType.values) {
    if (value.name == name) return value;
  }
  return StartingInjuryType.none;
}

class PlaceOrTribeOfOrigin {
  String name;
  String type;
  PlaceOrTribeOfOrigin({required this.name, required this.type});

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
      };

  factory PlaceOrTribeOfOrigin.fromJson(Map<String, dynamic> json) {
    return PlaceOrTribeOfOrigin(
      name: json['name'],
      type: json['type'],
    );
  }
}

class Religion {
  ReligionType type;
  ReligionIntensity intensity;
  Religion({required this.type, required this.intensity});

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'intensity': intensity.name,
      };

  factory Religion.fromJson(Map<String, dynamic> json) {
    return Religion(
      type: _religionTypeFromName(json['type']),
      intensity: _religionIntensityFromName(json['intensity']),
    );
  }
}

class Soldier {
  final int id;
  final bool isPlayer;
  String aravt;
  String? yurtId;
  SoldierRole role;
  String firstName;
  String familyName;
  String name;
  String placeOrTribeOfOrigin;
  List<String> languages;
  ReligionType religionType;
  ReligionIntensity religionIntensity;
  DateTime dateOfBirth;
  Zodiac zodiac;
  Color backgroundColor;
  int portraitIndex;
  Map<int, RelationshipValues> hordeRelationships = {};
  Map<String, RelationshipValues> externalRelationships = {};
  List<Injury> injuries = [];
  SoldierStatus status = SoldierStatus.alive;
  bool isImprisoned;
  bool isExpelled;
  int age;
  int yearsWithHorde;
  double height;
  StartingInjuryType startingInjury = StartingInjuryType.none;
  String? injuryDescription;
  String? ailments;
  int healthMax;
  int headHealthMax;
  int bodyHealthMax;
  int rightArmHealthMax;
  int leftArmHealthMax;
  int rightLegHealthMax;
  int leftLegHealthMax;
  int headHealthCurrent;
  int bodyHealthCurrent;
  int rightArmHealthCurrent;
  int leftArmHealthCurrent;
  int rightLegHealthCurrent;
  int leftLegHealthCurrent;
  double exhaustion;
  double stress;
  String? scars;
  Map<EquipmentSlot, InventoryItem> equippedItems;
  int ambition;
  int courage;
  int strength;
  int longRangeArcherySkill;
  int mountedArcherySkill;
  int spearSkill;
  int swordSkill;
  int shieldSkill;
  int perception;
  int intelligence;
  int knowledge;
  int patience;
  int judgment;
  int horsemanship;
  int animalHandling;
  int honesty;
  num temperament;
  int stamina;
  int hygiene;
  int charisma;
  int leadership;
  int adaptability;
  num experience;
  GiftOriginPreference giftOriginPreference;
  GiftTypePreference giftTypePreference;
  List<SpecialSkill> specialSkills;
  List<SoldierAttribute> attributes;
  double fungibleScrap;
  double fungibleRupees;
  double kilosOfMeat;
  double kilosOfRice;
  List<InventoryItem> personalInventory;
  List<InteractionLogEntry> interactionLog;
  List<PerformanceEvent> performanceLog;
  QueuedListenItem? queuedListenItem;
  List<AravtDuty> preferredDuties;
  List<AravtDuty> despisedDuties;
  Set<String> usedDialogueTopics = {};

  double get suppliesWealth {
    double itemWealth = personalInventory
        .where((item) => item.valueType == ValueType.Supply)
        .fold(0.0, (sum, item) => sum + item.baseValue);
    return itemWealth + fungibleScrap;
  }

  double get treasureWealth {
    double itemWealth = personalInventory
        .where((item) => item.valueType == ValueType.Treasure)
        .fold(0.0, (sum, item) => sum + item.baseValue);
    return itemWealth + fungibleRupees;
  }

  double get equippedGearSupplyWealth {
    return equippedItems.values
        .where((item) => item.valueType == ValueType.Supply)
        .fold(0.0, (sum, item) => sum + item.baseValue);
  }

  Soldier({
    required this.id,
    required this.aravt,
    this.isPlayer = false,
    this.role = SoldierRole.soldier,
    this.yurtId,
    required this.portraitIndex,
    required this.firstName,
    required this.familyName,
    required this.name,
    required this.placeOrTribeOfOrigin,
    required this.languages,
    required this.religionType,
    required this.religionIntensity,
    required this.dateOfBirth,
    required this.zodiac,
    required this.backgroundColor,
    required this.age,
    required this.yearsWithHorde,
    required this.height,
    required this.startingInjury,
    this.injuryDescription,
    this.ailments,
    required this.healthMax,
    required this.exhaustion,
    required this.stress,
    this.equippedItems = const {},
    required this.ambition,
    required this.courage,
    required this.strength,
    required this.longRangeArcherySkill,
    required this.mountedArcherySkill,
    required this.spearSkill,
    required this.swordSkill,
    required this.shieldSkill,
    required this.perception,
    required this.intelligence,
    required this.knowledge,
    required this.patience,
    required this.judgment,
    required this.horsemanship,
    required this.animalHandling,
    required this.honesty,
    required this.temperament,
    required this.stamina,
    required this.hygiene,
    required this.charisma,
    required this.leadership,
    required this.adaptability,
    required this.experience,
    required this.giftOriginPreference,
    required this.giftTypePreference,
    required this.specialSkills,
    required this.attributes,
    required this.fungibleScrap,
    required this.fungibleRupees,
    required this.kilosOfMeat,
    required this.kilosOfRice,
    this.scars,
    List<InteractionLogEntry>? interactionLog,
    List<PerformanceEvent>? performanceLog,
    this.queuedListenItem,
    List<AravtDuty>? preferredDuties,
    List<AravtDuty>? despisedDuties,
    List<InventoryItem>? personalInventory,
    this.isImprisoned = false,
    this.isExpelled = false,
  })  : headHealthMax = (healthMax * 0.9).clamp(1, 10).round(),
        bodyHealthMax = (healthMax * 1.1).clamp(1, 10).round(),
        rightArmHealthMax = healthMax.clamp(1, 10),
        leftArmHealthMax = healthMax.clamp(1, 10),
        rightLegHealthMax = healthMax.clamp(1, 10),
        leftLegHealthMax = healthMax.clamp(1, 10),
        headHealthCurrent = (healthMax * 0.9).clamp(1, 10).round() -
            (startingInjury == StartingInjuryType.damagedEyeLeft ? 2 : 0),
        bodyHealthCurrent = (healthMax * 1.1).clamp(1, 10).round(),
        rightArmHealthCurrent = healthMax.clamp(1, 10) -
            (startingInjury == StartingInjuryType.fingersMissingRightHand
                ? 2
                : 0),
        leftArmHealthCurrent = healthMax.clamp(1, 10) -
            (startingInjury == StartingInjuryType.oldScarLeftArm ? 1 : 0),
        rightLegHealthCurrent = healthMax.clamp(1, 10) -
            (startingInjury == StartingInjuryType.limpRightLeg ? 2 : 0),
        leftLegHealthCurrent = healthMax.clamp(1, 10),
        this.interactionLog = interactionLog ?? [],
        this.performanceLog = performanceLog ?? [],
        this.preferredDuties = preferredDuties ?? [],
        this.despisedDuties = despisedDuties ?? [],
        this.personalInventory = personalInventory ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'isPlayer': isPlayer,
        'aravt': aravt,
        'yurtId': yurtId,
        'role': role.name,
        'firstName': firstName,
        'familyName': familyName,
        'name': name,
        'placeOrTribeOfOrigin': placeOrTribeOfOrigin,
        'languages': languages,
        'religionType': religionType.name,
        'religionIntensity': religionIntensity.name,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'zodiac': zodiac.name,
        'backgroundColor': backgroundColor.value,
        'portraitIndex': portraitIndex,
        'hordeRelationships': hordeRelationships
            .map((key, value) => MapEntry(key.toString(), value.toJson())),
        'externalRelationships': externalRelationships
            .map((key, value) => MapEntry(key, value.toJson())),
        'injuries': injuries.map((i) => i.toJson()).toList(),
        'status': status.name,
        'isImprisoned': isImprisoned,
        'isExpelled': isExpelled,
        'age': age,
        'yearsWithHorde': yearsWithHorde,
        'height': height,
        'startingInjury': startingInjury.name,
        'injuryDescription': injuryDescription,
        'ailments': ailments,
        'healthMax': healthMax,
        'headHealthCurrent': headHealthCurrent,
        'bodyHealthCurrent': bodyHealthCurrent,
        'rightArmHealthCurrent': rightArmHealthCurrent,
        'leftArmHealthCurrent': leftArmHealthCurrent,
        'rightLegHealthCurrent': rightLegHealthCurrent,
        'leftLegHealthCurrent': leftLegHealthCurrent,
        'exhaustion': exhaustion,
        'stress': stress,
        'scars': scars,
        'equippedItems': equippedItems
            .map((key, value) => MapEntry(key.name, value.toJson())),
        'personalInventory': personalInventory.map((i) => i.toJson()).toList(),
        'ambition': ambition,
        'courage': courage,
        'strength': strength,
        'longRangeArcherySkill': longRangeArcherySkill,
        'mountedArcherySkill': mountedArcherySkill,
        'spearSkill': spearSkill,
        'swordSkill': swordSkill,
        'shieldSkill': shieldSkill,
        'perception': perception,
        'intelligence': intelligence,
        'knowledge': knowledge,
        'patience': patience,
        'judgment': judgment,
        'horsemanship': horsemanship,
        'animalHandling': animalHandling,
        'honesty': honesty,
        'temperament': temperament,
        'stamina': stamina,
        'hygiene': hygiene,
        'charisma': charisma,
        'leadership': leadership,
        'adaptability': adaptability,
        'experience': experience,
        'giftOriginPreference': giftOriginPreference.name,
        'giftTypePreference': giftTypePreference.name,
        'specialSkills': specialSkills.map((s) => s.name).toList(),
        'attributes': attributes.map((a) => a.name).toList(),
        'fungibleScrap': fungibleScrap,
        'fungibleRupees': fungibleRupees,
        'kilosOfMeat': kilosOfMeat,
        'kilosOfRice': kilosOfRice,
        'interactionLog': interactionLog.map((i) => i.toJson()).toList(),
        'performanceLog': performanceLog.map((p) => p.toJson()).toList(),
        'queuedListenItem': queuedListenItem?.toJson(),
        'preferredDuties': preferredDuties.map((d) => d.name).toList(),
        'despisedDuties': despisedDuties.map((d) => d.name).toList(),
      };

  factory Soldier.fromJson(Map<String, dynamic> json) {
    return Soldier(
      id: json['id'],
      isPlayer: json['isPlayer'],
      aravt: json['aravt'],
      yurtId: json['yurtId'],
      role: _soldierRoleFromName(json['role']),
      portraitIndex: json['portraitIndex'],
      firstName: json['firstName'],
      familyName: json['familyName'],
      name: json['name'],
      placeOrTribeOfOrigin: json['placeOrTribeOfOrigin'],
      languages: List<String>.from(json['languages']),
      religionType: _religionTypeFromName(json['religionType']),
      religionIntensity: _religionIntensityFromName(json['religionIntensity']),
      dateOfBirth: DateTime.parse(json['dateOfBirth']),
      zodiac: _zodiacFromName(json['zodiac']),
      backgroundColor: Color(json['backgroundColor']),
      age: json['age'],
      yearsWithHorde: json['yearsWithHorde'],
      height: json['height'],
      startingInjury: _startingInjuryTypeFromName(json['startingInjury']),
      injuryDescription: json['injuryDescription'],
      ailments: json['ailments'],
      healthMax: json['healthMax'],
      exhaustion: (json['exhaustion'] as num).toDouble(),
      stress: (json['stress'] as num).toDouble(),
      equippedItems: (json['equippedItems'] as Map<String, dynamic>).map((key,
              value) =>
          MapEntry(equipmentSlotFromName(key)!, InventoryItem.fromJson(value))),
      personalInventory: (json['personalInventory'] as List)
          .map((i) => InventoryItem.fromJson(i))
          .toList(),
      ambition: json['ambition'],
      courage: json['courage'],
      strength: json['strength'],
      longRangeArcherySkill: json['longRangeArcherySkill'],
      mountedArcherySkill: json['mountedArcherySkill'],
      spearSkill: json['spearSkill'],
      swordSkill: json['swordSkill'],
      shieldSkill: json['shieldSkill'],
      perception: json['perception'],
      intelligence: json['intelligence'],
      knowledge: json['knowledge'],
      patience: json['patience'],
      judgment: json['judgment'],
      horsemanship: json['horsemanship'],
      animalHandling: json['animalHandling'],
      honesty: json['honesty'],
      temperament: json['temperament'],
      stamina: json['stamina'],
      hygiene: json['hygiene'],
      charisma: json['charisma'],
      leadership: json['leadership'],
      adaptability: json['adaptability'],
      experience: json['experience'],
      giftOriginPreference:
          _giftOriginPreferenceFromName(json['giftOriginPreference']),
      giftTypePreference:
          _giftTypePreferenceFromName(json['giftTypePreference']),
      specialSkills: _specialSkillListFromJson(json['specialSkills']),
      attributes: _soldierAttributeListFromJson(json['attributes']),
      fungibleScrap: (json['fungibleScrap'] ?? 0.0).toDouble(),
      fungibleRupees: (json['fungibleRupees'] ?? 0.0).toDouble(),
      kilosOfMeat: (json['kilosOfMeat'] as num).toDouble(),
      kilosOfRice: (json['kilosOfRice'] as num).toDouble(),
      scars: json['scars'],
      interactionLog: (json['interactionLog'] as List)
          .map((i) => InteractionLogEntry.fromJson(i))
          .toList(),
      performanceLog: (json['performanceLog'] as List)
          .map((p) => PerformanceEvent.fromJson(p))
          .toList(),
      queuedListenItem: json['queuedListenItem'] != null
          ? QueuedListenItem.fromJson(json['queuedListenItem'])
          : null,
      preferredDuties: aravtDutyListFromJson(json['preferredDuties']),
      despisedDuties: aravtDutyListFromJson(json['despisedDuties']),
      isImprisoned: json['isImprisoned'] ?? false,
      isExpelled: json['isExpelled'] ?? false,
    )
      ..hordeRelationships =
          (json['hordeRelationships'] as Map<String, dynamic>).map(
              (key, value) =>
                  MapEntry(int.parse(key), RelationshipValues.fromJson(value)))
      ..externalRelationships =
          (json['externalRelationships'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, RelationshipValues.fromJson(value)))
      ..injuries =
          (json['injuries'] as List).map((i) => Injury.fromJson(i)).toList()
      ..status = soldierStatusFromName(json['status'])
      ..headHealthCurrent = json['headHealthCurrent']
      ..bodyHealthCurrent = json['bodyHealthCurrent']
      ..rightArmHealthCurrent = json['rightArmHealthCurrent']
      ..leftArmHealthCurrent = json['leftArmHealthCurrent']
      ..rightLegHealthCurrent = json['rightLegHealthCurrent']
      ..leftLegHealthCurrent = json['leftLegHealthCurrent'];
  }

  RelationshipValues getRelationship(int soldierId) {
    if (!hordeRelationships.containsKey(soldierId)) {
      hordeRelationships[soldierId] = RelationshipValues();
    }
    return hordeRelationships[soldierId]!;
  }
}

class ZodiacEffects {
  final Map<String, int> statModifiers;
  final List<SoldierAttribute> traits;
  const ZodiacEffects({this.statModifiers = const {}, this.traits = const []});
}

class SoldierGenerator {
  static final Random _random = Random();
  static const int gameStartYear = 1140;

  static const Map<Zodiac, ZodiacEffects> _zodiacEffects = {
    Zodiac.rat: ZodiacEffects(
        statModifiers: {'intelligence': 1, 'charisma': 1},
        traits: [SoldierAttribute.gossip]),
    Zodiac.ox: ZodiacEffects(statModifiers: {
      'temperament': 1,
      'stamina': 1,
      'patience': 1,
      'ambition': -1,
      'intelligence': -1
    }, traits: []),
    Zodiac.tiger: ZodiacEffects(
        statModifiers: {'courage': 2, 'intelligence': 1, 'patience': -1},
        traits: [SoldierAttribute.storyTeller]),
    Zodiac.rabbit: ZodiacEffects(statModifiers: {
      'judgment': 1,
      'animalHandling': 1,
      'honesty': 1,
      'leadership': -1
    }, traits: []),
    Zodiac.dragon: ZodiacEffects(statModifiers: {
      'ambition': 1,
      'adaptability': 1,
      'temperament': -1,
      'charisma': -1
    }, traits: []),
    Zodiac.snake: ZodiacEffects(statModifiers: {
      'judgment': 1,
      'perception': 1,
      'knowledge': 1,
      'temperament': -1,
      'honesty': -1
    }, traits: []),
    Zodiac.horse: ZodiacEffects(statModifiers: {
      'courage': 1,
      'judgment': -1,
      'patience': -1,
      'strength': 1,
      'adaptability': 1
    }, traits: []),
    Zodiac.goat: ZodiacEffects(statModifiers: {
      'temperament': 1,
      'judgment': 1,
      'perception': 1,
      'leadership': 1,
      'strength': -1
    }, traits: [
      SoldierAttribute.artist
    ]),
    Zodiac.monkey: ZodiacEffects(statModifiers: {
      'intelligence': 1,
      'judgment': -1,
      'patience': -1,
      'adaptability': 1,
      'knowledge': 1
    }, traits: []),
    Zodiac.rooster: ZodiacEffects(statModifiers: {
      'courage': 1,
      'patience': 1,
      'judgment': 1,
      'temperament': -1,
      'adaptability': -1,
      'leadership': 1,
      'hygiene': 1
    }, traits: []),
    Zodiac.dog: ZodiacEffects(statModifiers: {
      'honesty': 1,
      'ambition': -1,
      'courage': 1,
      'temperament': 1
    }, traits: []),
    Zodiac.pig: ZodiacEffects(statModifiers: {
      'leadership': 1,
      'temperament': 1,
      'honesty': 1,
      'courage': -1,
      'perception': -1
    }, traits: []),
  };

  static const List<String> _firstNames = [
    'Khasar',
    'Batu',
    'Jebe',
    'Subutai',
    'Tengri',
    'Börte',
    'Hoelun',
    'Altan',
    'Jaika',
    'Temujin',
    'Ogedai',
    'Jochi',
    'Chagatai',
    'Tolui',
    'Temur',
    'Bolad',
    'Berke',
    'Khada',
    'Munkh',
    'Sorghaghtani',
    'Ariq',
    'Guyuk',
    'Möngke',
    'Kublai',
    'Hulagu',
    'Toghrul',
    'Yesugei',
    'Jamuqa',
    'Kulan',
    'Qasar',
    'Baliq',
    'Chilaun',
    'Muqali',
    'Subodei'
  ];
  static const List<String> _familyNames = [
    'Borjigin',
    'Kiyat',
    'Onggirat',
    'Merkit',
    'Naiman',
    'Tatar',
    'Qongirat',
    'Uriankhai',
    'Suldus',
    'Barga',
    'Khongirad',
    'Jalayir',
    'Mangqud',
    'Baatu',
    'Chonos',
    'Esen',
    'Khasarid',
    'Jochid',
    'Chagataid',
    'Toluid',
    'Tengeri',
    'Altan',
    'Temurids',
    'Kublai',
    'Hulaguids',
    'Toghrulids',
    'Yesugeiids',
    'Jamuqaids',
    'Kulanids',
    'Qasarids',
    'Baliqids',
    'Chilaunids',
    'Muqaliids'
  ];
  static const Map<StartingInjuryType, String> _startingInjuriesMap = {
    StartingInjuryType.oldScarLeftArm: 'Old Scar (Left Arm)',
    StartingInjuryType.limpRightLeg: 'Limp (Right Leg)',
    StartingInjuryType.damagedEyeLeft: 'Damaged Eye (Left)',
    StartingInjuryType.fingersMissingRightHand: 'Fingers Missing (Right Hand)',
    StartingInjuryType.chronicBackPain: 'Chronic Back Pain'
  };
  static const List<String> _ailmentsList = [
    'Chronic Cough',
    'Weak Digestion',
    'Recurring Fever'
  ];
  static const List<String> _tribeNames = [
    'Borjigin',
    'Kiyat',
    'Onggirat',
    'Merkit',
    'Tatar',
    'Qongirat'
  ];
  static const List<String> _sedentaryNames = [
    'Chinese (Han)',
    'Persian (Khwarezmian)',
    'Rus (Kievan Rus)',
    'Uygur (Turkic)'
  ];
  static const List<ReligionType> _steppeReligions = [
    ReligionType.tengri,
    ReligionType.buddhist,
    ReligionType.christian,
    ReligionType.muslim
  ];
  static const List<SoldierAttribute> _commonAttributes = [
    SoldierAttribute.conservative,
    SoldierAttribute.gossip,
    SoldierAttribute.superstitious,
    SoldierAttribute.forgiving
  ];
  static const List<SoldierAttribute> _uncommonAttributes = [
    SoldierAttribute.wanderlust,
    SoldierAttribute.peacemaker,
    SoldierAttribute.mentor,
    SoldierAttribute.glorySeeker,
    SoldierAttribute.skeptic,
    SoldierAttribute.gregarious,
    SoldierAttribute.coldResistant
  ];
  static const List<SoldierAttribute> _rareAttributes = [
    SoldierAttribute.bully,
    SoldierAttribute.gambler,
    SoldierAttribute.poet,
    SoldierAttribute.grudgeHolder,
    SoldierAttribute.prophet,
    SoldierAttribute.curmudgeon,
    SoldierAttribute.surgeonAttribute,
    SoldierAttribute.horseWhisperer,
    SoldierAttribute.shepherd,
    SoldierAttribute.talentScout,
    SoldierAttribute.survivalist
  ];

  static int _getStandardDistributionValue(int min, int max, int mean) {
    int value = _random.nextInt(max - min + 1) + min;
    double roll = _random.nextDouble();
    if (roll < 0.5)
      value = mean + (_random.nextInt(3) - 1);
    else if (roll < 0.8)
      value = mean + (_random.nextInt(5) - 2);
    else if (roll < 0.95) value = mean + (_random.nextInt(7) - 3);
    return value.clamp(min, max);
  }

  static String _generateFirstName() =>
      _firstNames[_random.nextInt(_firstNames.length)];
  static String _generateFamilyName() =>
      _familyNames[_random.nextInt(_familyNames.length)];

  static DateTime _generateDateOfBirth(int age) {
    final yearOfBirth = gameStartYear - age;
    final month = _random.nextInt(12) + 1;
    final day = _random.nextInt(28) + 1;
    return DateTime(yearOfBirth, month, day);
  }

  static int _generateAge() {
    final roll = _random.nextDouble();
    if (roll < 0.60) return 15 + _random.nextInt(11);
    if (roll < 0.85) return 26 + _random.nextInt(15);
    if (roll < 0.95) return 41 + _random.nextInt(20);
    return 61 + _random.nextInt(30);
  }

  static int _generateYearsWithHorde(int age) {
    final maxYears = age - 10;
    if (maxYears <= 0) return 0;
    return _random.nextInt(min(maxYears + 1, 16));
  }

  static double _generateHeight() {
    double mean = 166.0, stdDev = 7.5;
    double u1 = _random.nextDouble(), u2 = _random.nextDouble();
    double z = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
    return (mean + z * stdDev).clamp(148.0, 214.0);
  }

  static int _generateMaxHealth(int age) {
    int basePotential = 10;
    int peakAge = 25;
    double health;

    if (age <= peakAge) {
      health = 6 + (basePotential - 6) * (age / peakAge);
    } else if (age <= 40) {
      health = basePotential - (age - peakAge) * 0.1;
    } else if (age <= 70) {
      double declineFrom40 = (40 - peakAge) * 0.1;
      health = basePotential - declineFrom40 - (age - 40) * 0.2;
    } else {
      double declineFrom40 = (40 - peakAge) * 0.1;
      double declineFrom70 = (70 - 40) * 0.2;
      health = basePotential - declineFrom40 - declineFrom70 - (age - 70) * 0.3;
    }
    health += _random.nextDouble() * 2 - 1;
    return health.clamp(1, 10).round();
  }

  static StartingInjuryType _generateStartingInjuryType(
      int age, int experience) {
    double injuryChance = (age * 0.005) + (experience * 0.01) + 0.02;
    if (_random.nextDouble() < injuryChance) {
      List<StartingInjuryType> possibleInjuries = _startingInjuriesMap.keys
          .where((k) => k != StartingInjuryType.none)
          .toList();
      if (possibleInjuries.isNotEmpty) {
        return possibleInjuries[_random.nextInt(possibleInjuries.length)];
      }
    }
    return StartingInjuryType.none;
  }

  static String? _generateAilments(int age) {
    double ailmentChance = age * 0.003 + 0.01;
    if (_random.nextDouble() < ailmentChance && _ailmentsList.isNotEmpty) {
      return _ailmentsList[_random.nextInt(_ailmentsList.length)];
    }
    return null;
  }

  static double _generateExhaustion() =>
      _getStandardDistributionValue(0, 5, 1).toDouble();
  static double _generateStress() =>
      _getStandardDistributionValue(0, 5, 1).toDouble();
  static int _generateHygiene() => _getStandardDistributionValue(0, 5, 2);
  static int _generateCoreAttribute(int mean) =>
      _getStandardDistributionValue(0, 10, mean);

  static int _generateLongRangeArcherySkill(
      int perception, int stamina, int patience, num experience,
      {int modifier = 0}) {
    int effectivePerception = (perception + modifier).clamp(0, 10);
    int skill = (effectivePerception * 1.2 +
            stamina * 0.8 +
            patience * 1.1 +
            experience * 0.5) ~/
        4;
    return skill.clamp(0, 10);
  }

  static int _generateMountedArcherySkill(
      int horsemanship, double exhaustion, int courage, num experience,
      {int modifier = 0}) {
    int skill = (horsemanship * 1.5 +
            (10 - exhaustion) * 0.5 +
            courage * 0.8 +
            experience * 0.5 +
            modifier) ~/
        4;
    return skill.clamp(0, 10);
  }

  static int _generateSpearSkill(
      int horsemanship, int strength, int judgment, int stamina, num experience,
      {int modifier = 0}) {
    int skill = (horsemanship * 1.1 +
            strength * 1.2 +
            judgment * 0.8 +
            stamina * 0.9 +
            experience * 0.5 +
            modifier) ~/
        5;
    return skill.clamp(0, 10);
  }

  static int _generateSwordSkill(int strength, int perception, int adaptability,
      int patience, int judgment, num experience,
      {int modifier = 0}) {
    int skill = (strength * 1.3 +
            perception * 0.9 +
            adaptability * 0.8 +
            patience * 0.7 +
            judgment * 0.8 +
            experience * 0.5 +
            modifier) ~/
        6;
    return skill.clamp(0, 10);
  }

  static int _generateShieldSkill(
      int strength, num experience, int courage, int perception,
      {int modifier = 0}) {
    int skill = (strength * 1.4 +
            perception * 1.1 +
            courage * 0.8 +
            experience * 0.5 +
            (modifier / 2).round()) ~/
        4;
    return skill.clamp(0, 10);
  }

  static int _generateExperience(int age, int adaptability) {
    int potentialExperienceYears = max(0, age - 15);
    double experienceRate = 1.0 + (adaptability - 5) * 0.1;
    int experience = (potentialExperienceYears * experienceRate).round();
    return experience.clamp(0, 40);
  }

  static PlaceOrTribeOfOrigin _generatePlaceOrTribeOfOrigin() {
    if (_random.nextDouble() < 0.7 && _tribeNames.isNotEmpty) {
      return PlaceOrTribeOfOrigin(
          name: _tribeNames[_random.nextInt(_tribeNames.length)],
          type: 'Tribe');
    } else if (_sedentaryNames.isNotEmpty) {
      return PlaceOrTribeOfOrigin(
          name: _sedentaryNames[_random.nextInt(_sedentaryNames.length)],
          type: 'Sedentary');
    } else {
      return PlaceOrTribeOfOrigin(name: 'Unknown', type: 'Unknown');
    }
  }

  static List<String> _generateLanguages(String origin) {
    Set<String> langs = {'Mongolian'};
    if (origin.contains('Chinese')) langs.add('Mandarin');
    if (origin.contains('Persian')) langs.add('Persian');
    if (origin.contains('Rus')) langs.add('Old East Slavic');
    if (_random.nextDouble() < 0.1) langs.add('Turkic');
    return langs.toList();
  }

  static Religion _generateReligion(String origin) {
    ReligionType type;
    if (origin.contains('Chinese'))
      type = ReligionType.buddhist;
    else if (origin.contains('Persian'))
      type = ReligionType.muslim;
    else if (origin.contains('Rus'))
      type = ReligionType.christian;
    else {
      final double roll = _random.nextDouble();
      if (roll < 0.6 && _steppeReligions.contains(ReligionType.tengri))
        type = ReligionType.tengri;
      else if (roll < 0.8 && _steppeReligions.contains(ReligionType.buddhist))
        type = ReligionType.buddhist;
      else if (roll < 0.9 && _steppeReligions.contains(ReligionType.christian))
        type = ReligionType.christian;
      else if (_steppeReligions.contains(ReligionType.muslim))
        type = ReligionType.muslim;
      else
        type = ReligionType.none;
    }

    ReligionIntensity intensity;
    final roll = _random.nextDouble();
    if (roll < 0.1)
      intensity = ReligionIntensity.fervent;
    else if (roll < 0.2)
      intensity = ReligionIntensity.atheist;
    else if (roll < 0.3)
      intensity = ReligionIntensity.agnostic;
    else if (roll < 0.4 && type == ReligionType.tengri)
      intensity = ReligionIntensity.syncretic;
    else
      intensity = ReligionIntensity.normal;

    return Religion(type: type, intensity: intensity);
  }

  static GiftOriginPreference _generateGiftOriginPreference(Religion religion) {
    final roll = _random.nextDouble();
    if (roll < 0.10) return GiftOriginPreference.allAppreciative;
    if (roll < 0.15) return GiftOriginPreference.unappreciative;
    if (roll < 0.5) {
      switch (religion.type) {
        case ReligionType.muslim:
          return GiftOriginPreference.muslim;
        case ReligionType.buddhist:
          return GiftOriginPreference.buddhist;
        case ReligionType.christian:
          return GiftOriginPreference.christian;
        case ReligionType.hindu:
          return GiftOriginPreference.hindu;
        case ReligionType.zoroastrian:
          return GiftOriginPreference.zoroastrian;
        case ReligionType.tengri:
          return GiftOriginPreference.tengri;
        default:
          break;
      }
    }
    final preferences = [
      GiftOriginPreference.fromHome,
      GiftOriginPreference.fromRival,
      GiftOriginPreference.chinese,
      GiftOriginPreference.russian,
      GiftOriginPreference.european,
      GiftOriginPreference.arab,
      GiftOriginPreference.indian
    ];
    return preferences.isNotEmpty
        ? preferences[_random.nextInt(preferences.length)]
        : GiftOriginPreference.fromHome;
  }

  static GiftTypePreference _generateGiftTypePreference() {
    final types = GiftTypePreference.values;
    return types.isNotEmpty
        ? types[_random.nextInt(types.length)]
        : GiftTypePreference.supplies;
  }

  static List<SpecialSkill> _generateSpecialSkills() {
    Set<SpecialSkill> skills = {};
    double roll = _random.nextDouble();
    final allSkills = SpecialSkill.values;
    if (allSkills.isEmpty) return [];

    if (roll < 0.05) {
      skills.add(allSkills[_random.nextInt(allSkills.length)]);
      skills.add(allSkills[_random.nextInt(allSkills.length)]);
    } else if (roll < 0.25) {
      skills.add(allSkills[_random.nextInt(allSkills.length)]);
    }
    return skills.toList();
  }

  static List<SoldierAttribute> _generateAttributes(
      List<SoldierAttribute> zodiacAttributes) {
    Set<SoldierAttribute> attributes = {};
    attributes.addAll(zodiacAttributes);

    if (_random.nextDouble() < 0.80 && _commonAttributes.isNotEmpty) {
      attributes
          .add(_commonAttributes[_random.nextInt(_commonAttributes.length)]);
    }
    if (_random.nextDouble() < 0.30 && _commonAttributes.isNotEmpty) {
      attributes
          .add(_commonAttributes[_random.nextInt(_commonAttributes.length)]);
    }
    if (_random.nextDouble() < 0.20 && _uncommonAttributes.isNotEmpty) {
      attributes.add(
          _uncommonAttributes[_random.nextInt(_uncommonAttributes.length)]);
    }
    if (_random.nextDouble() < 0.05 && _rareAttributes.isNotEmpty) {
      attributes.add(_rareAttributes[_random.nextInt(_rareAttributes.length)]);
    }
    _removeConflicts(attributes);
    return attributes.toList();
  }

  static void _removeConflicts(Set<SoldierAttribute> attributes) {
    if (attributes.contains(SoldierAttribute.peacemaker) &&
        attributes.contains(SoldierAttribute.bully)) {
      attributes.remove(_random.nextBool()
          ? SoldierAttribute.peacemaker
          : SoldierAttribute.bully);
    }
    if (attributes.contains(SoldierAttribute.forgiving) &&
        attributes.contains(SoldierAttribute.grudgeHolder)) {
      attributes.remove(_random.nextBool()
          ? SoldierAttribute.forgiving
          : SoldierAttribute.grudgeHolder);
    }
    if (attributes.contains(SoldierAttribute.skeptic) &&
        attributes.contains(SoldierAttribute.superstitious)) {
      attributes.remove(_random.nextBool()
          ? SoldierAttribute.skeptic
          : SoldierAttribute.superstitious);
    }
    if (attributes.contains(SoldierAttribute.conservative) &&
        attributes.contains(SoldierAttribute.wanderlust)) {
      attributes.remove(_random.nextBool()
          ? SoldierAttribute.conservative
          : SoldierAttribute.wanderlust);
    }
  }

  static Map<String, List<AravtDuty>> _generateDutyPreferences({
    required Religion religion,
    required List<SpecialSkill> specialSkills,
    required List<SoldierAttribute> attributes,
    required int intStat,
    required int temStat,
    required int couStat,
    required int knoStat,
    required int chaStat,
    required int ldrStat,
    required int patStat,
    required int honStat,
    required int lrsSkill,
    required int masSkill,
    required int sprSkill,
    required int swdSkill,
    required int shdSkill,
    required int horsemanship,
    required int animalHandling,
  }) {
    Set<AravtDuty> preferred = {};
    Set<AravtDuty> despised = {};

    if (specialSkills.contains(SpecialSkill.surgeon) ||
        (intStat > 6 && temStat > 6 && knoStat > 6)) {
      preferred.add(AravtDuty.medic);
    }
    if (_random.nextDouble() < 0.6) {
      despised.add(AravtDuty.chronicler);
    }
    if (patStat > 7 && knoStat > 7) {
      preferred.add(AravtDuty.chronicler);
      despised.remove(AravtDuty.chronicler);
    }
    if (_random.nextDouble() < 0.7) {
      preferred.add(AravtDuty.cook);
    }
    if (attributes.contains(SoldierAttribute.storyTeller) ||
        attributes.contains(SoldierAttribute.artist) ||
        chaStat > 7) {
      preferred.add(AravtDuty.tuulch);
    }
    if (attributes.contains(SoldierAttribute.conservative) ||
        (honStat > 6 && patStat > 6)) {
      preferred.add(AravtDuty.disciplinarian);
    }
    if (temStat < 3 || honStat < 3) {
      despised.add(AravtDuty.disciplinarian);
      preferred.remove(AravtDuty.disciplinarian);
    }
    if (religion.intensity == ReligionIntensity.fervent) {
      preferred.add(AravtDuty.chaplain);
    }
    if (religion.intensity == ReligionIntensity.atheist) {
      despised.add(AravtDuty.chaplain);
    }
    if (lrsSkill > 6 ||
        masSkill > 6 ||
        sprSkill > 6 ||
        swdSkill > 6 ||
        shdSkill > 6) {
      preferred.add(AravtDuty.drillSergeant);
    }
    if (ldrStat > 6 && couStat > 6) {
      preferred.add(AravtDuty.lieutenant);
    }
    if (horsemanship > 6 || animalHandling > 6) {
      preferred.add(AravtDuty.equerry);
    }

    return {
      'preferred': preferred.toList(),
      'despised': despised.toList(),
    };
  }

  static double _generateWealth(int age, int yearsWithHorde, int honesty) {
    double baseWealth = (age + yearsWithHorde * 2).toDouble() *
        (_random.nextDouble() * 0.5 + 0.5);
    if (honesty < 3) baseWealth *= 1.5;
    if (honesty > 7) baseWealth *= 0.7;
    return baseWealth.clamp(0, 500);
  }

  static double _generateFoodSupply() => _random.nextDouble() * 50 + 10;

  // [GEMINI-FIX] Added optional 'hasHorse' parameter to control mount generation
  static Soldier generateNewSoldier({
    required int id,
    required String aravt,
    bool isPlayerCharacter = false,
    bool hasHorse = true,
    // [GEMINI-NEW] Added optional overrides for Proto-Soldier data
    int? overrideAge,
    int? overrideStrength,
    int? overrideIntelligence,
    int? overrideAmbition,
    int? overridePerception,
    int? overrideTemperament,
    int? overrideKnowledge,
    int? overridePatience,
    int? overrideLongRangeArchery,
    int? overrideMountedArchery,
    int? overrideSpear,
    int? overrideSword,
  }) {
    final int statMean = isPlayerCharacter ? 5 : 4;

    // [GEMINI-FIX] Use override if present, otherwise generate
    final age = overrideAge ?? _generateAge();
    final dateOfBirth = _generateDateOfBirth(age);
    final zodiac = _getZodiac(dateOfBirth.year);
    final yearsWithHorde = _generateYearsWithHorde(age);
    final height = _generateHeight();
    final healthMax = _generateMaxHealth(age);

    // [GEMINI-FIX] Apply overrides to core attributes
    int ambition = overrideAmbition ?? _generateCoreAttribute(statMean);
    int courage = _generateCoreAttribute(
        statMean); // Proto doesn't currently have courage, so we still generate it
    int strength = overrideStrength ?? _generateCoreAttribute(statMean);
    int perception = overridePerception ?? _generateCoreAttribute(statMean);
    int intelligence = overrideIntelligence ?? _generateCoreAttribute(statMean);
    int knowledge = overrideKnowledge ?? _generateCoreAttribute(statMean);
    int patience = overridePatience ?? _generateCoreAttribute(statMean);
    int judgment = _generateCoreAttribute(statMean);
    int horsemanship = _generateCoreAttribute(statMean);
    int animalHandling = _generateCoreAttribute(statMean);
    int honesty = _generateCoreAttribute(statMean);
    int temperament = overrideTemperament ?? _generateCoreAttribute(statMean);
    int stamina = _generateCoreAttribute(statMean);
    int hygiene = _generateHygiene();
    int charisma = _generateCoreAttribute(statMean);
    int leadership = _generateCoreAttribute(statMean);
    int adaptability = _generateCoreAttribute(statMean);

    final effects = _zodiacEffects[zodiac];
    if (effects != null) {
      effects.statModifiers.forEach((statName, modifier) {
        // We only apply zodiac modifiers if we DIDN'T override the stat.
        // If we overrode it, we want exactly what Proto said.
        switch (statName) {
          case 'intelligence':
            if (overrideIntelligence == null)
              intelligence = (intelligence + modifier).clamp(0, 10);
            break;
          case 'charisma':
            charisma = (charisma + modifier).clamp(0, 10);
            break;
          case 'temperament':
            if (overrideTemperament == null)
              temperament = (temperament + modifier).clamp(0, 10);
            break;
          case 'stamina':
            stamina = (stamina + modifier).clamp(0, 10);
            break;
          case 'patience':
            if (overridePatience == null)
              patience = (patience + modifier).clamp(0, 10);
            break;
          case 'ambition':
            if (overrideAmbition == null)
              ambition = (ambition + modifier).clamp(0, 10);
            break;
          case 'courage':
            courage = (courage + modifier).clamp(0, 10);
            break;
          case 'judgment':
            judgment = (judgment + modifier).clamp(0, 10);
            break;
          case 'animalHandling':
            animalHandling = (animalHandling + modifier).clamp(0, 10);
            break;
          case 'honesty':
            honesty = (honesty + modifier).clamp(0, 10);
            break;
          case 'leadership':
            leadership = (leadership + modifier).clamp(0, 10);
            break;
          case 'adaptability':
            adaptability = (adaptability + modifier).clamp(0, 10);
            break;
          case 'strength':
            if (overrideStrength == null)
              strength = (strength + modifier).clamp(0, 10);
            break;
          case 'perception':
            if (overridePerception == null)
              perception = (perception + modifier).clamp(0, 10);
            break;
          case 'knowledge':
            if (overrideKnowledge == null)
              knowledge = (knowledge + modifier).clamp(0, 10);
            break;
          case 'hygiene':
            hygiene = (hygiene + modifier).clamp(0, 10);
            break;
        }
      });
    }

    final experience = _generateExperience(age, adaptability);
    final exhaustion = _generateExhaustion();
    final stress = _generateStress();

    final startingInjuryType = _generateStartingInjuryType(age, experience);
    String? injuryDesc = _startingInjuriesMap[startingInjuryType];
    int perceptionModifier =
        (startingInjuryType == StartingInjuryType.damagedEyeLeft) ? -3 : 0;
    int weaponSkillModifier =
        (startingInjuryType == StartingInjuryType.fingersMissingRightHand)
            ? -2
            : 0;

    // [GEMINI-FIX] Apply overrides to skills.
    // If overridden, we use the exact value. If not, we use the complex generation logic.
    final longRangeArcherySkill = overrideLongRangeArchery ??
        _generateLongRangeArcherySkill(
            perception, stamina, patience, experience,
            modifier: perceptionModifier + weaponSkillModifier);

    final mountedArcherySkill = overrideMountedArchery ??
        _generateMountedArcherySkill(
            horsemanship, exhaustion, courage, experience,
            modifier: perceptionModifier + weaponSkillModifier);

    final swordSkill = overrideSword ??
        _generateSwordSkill(
            strength, perception, adaptability, patience, judgment, experience,
            modifier: weaponSkillModifier);

    final shieldSkill = _generateShieldSkill(
        strength, experience, courage, perception,
        modifier: (weaponSkillModifier / 2).round());

    final spearSkill = overrideSpear ??
        _generateSpearSkill(
            horsemanship, strength, judgment, stamina, experience,
            modifier: weaponSkillModifier);

    final ailments = _generateAilments(age);
    final scars = (startingInjuryType != StartingInjuryType.none ||
            _random.nextDouble() < 0.1)
        ? 'Some scars visible'
        : null;

    // ... (Rest of the method for name, religion, equipment, etc. remains the same)
    final firstName = _generateFirstName();
    final familyName = _generateFamilyName();
    final name = '$firstName $familyName';
    final placeOrTribe = _generatePlaceOrTribeOfOrigin();
    final languages = _generateLanguages(placeOrTribe.name);
    final religion = _generateReligion(placeOrTribe.name);
    final giftOriginPref = _generateGiftOriginPreference(religion);
    final giftTypePref = _generateGiftTypePreference();
    final specialSkills = _generateSpecialSkills();

    List<SoldierAttribute> zodiacAttributes = [];
    if (effects != null && effects.traits.isNotEmpty) {
      if (_random.nextDouble() < 0.20) {
        zodiacAttributes
            .add(effects.traits[_random.nextInt(effects.traits.length)]);
      }
      if (_random.nextDouble() < 0.05) {
        var potentialTrait =
            effects.traits[_random.nextInt(effects.traits.length)];
        if (!zodiacAttributes.contains(potentialTrait) ||
            effects.traits.length > 1) {
          zodiacAttributes.add(potentialTrait);
        }
      }
    }
    final attributes = _generateAttributes(zodiacAttributes);

    final dutyPrefs = _generateDutyPreferences(
      religion: religion,
      specialSkills: specialSkills,
      attributes: attributes,
      intStat: intelligence,
      temStat: temperament,
      couStat: courage,
      knoStat: knowledge,
      chaStat: charisma,
      ldrStat: leadership,
      patStat: patience,
      honStat: honesty,
      lrsSkill: longRangeArcherySkill,
      masSkill: mountedArcherySkill,
      sprSkill: spearSkill,
      swdSkill: swordSkill,
      shdSkill: shieldSkill,
      horsemanship: horsemanship,
      animalHandling: animalHandling,
    );

    final List<InventoryItem> personalInventory = [];
    if (_random.nextDouble() < 0.3) {
      final item = ItemDatabase.createItemInstance('wep_short_bow',
          forcedQuality: 'Worn');
      if (item != null) personalInventory.add(item);
    }
    if (_random.nextDouble() < 0.5) {
      final item = ItemDatabase.createItemInstance('con_dried_meat');
      if (item != null) personalInventory.add(item);
    }

    final Map<EquipmentSlot, InventoryItem> startingEquipment = {};
    try {
      void equip(String templateId, {String? forcedQuality}) {
        final item = ItemDatabase.createItemInstance(templateId,
            forcedQuality: forcedQuality);
        if (item != null && item.equippableSlot != null) {
          startingEquipment[item.equippableSlot!] = item;
        }
      }

      equip('wep_short_bow');
      equip('wep_sword');
      equip('arm_undergarments');
      if (hasHorse) {
        equip('mnt_horse');
      }
      if (_random.nextDouble() < 0.4) equip('wep_long_bow');

      bool hasLance = false;
      if (_random.nextDouble() < 0.3) {
        equip('wep_lance');
        hasLance = true;
      }

      if (!hasLance || _random.nextDouble() < 0.7) {
        if (!startingEquipment.containsKey(EquipmentSlot.spear)) {
          equip('wep_throwing_spear');
        }
      }

      if (_random.nextDouble() < 0.15) equip('rel_necklace');
      if (_random.nextDouble() < 0.15) equip('rel_ring');
      if (_random.nextDouble() < 0.85) equip('arm_helmet');
      if (_random.nextDouble() < 0.95) equip('arm_body');
      if (_random.nextDouble() < 0.5) equip('arm_gauntlets');
      if (_random.nextDouble() < 0.90) equip('arm_boots');
      if (_random.nextDouble() < 0.90) equip('shd_round');
    } catch (e) {
      print("Error during item generation for soldier $id: $e");
    }

    final fungibleScrap = _generateWealth(age, yearsWithHorde, honesty);
    final fungibleRupees = _generateWealth(age, yearsWithHorde, honesty) / 5;
    final kilosOfMeat = _generateFoodSupply();
    final kilosOfRice = _generateFoodSupply() * 0.5;
    final int portraitIndex = _random.nextInt(24);
    final Color backgroundColor = _getColorForZodiac(zodiac);

    return Soldier(
      id: id,
      aravt: aravt,
      isPlayer: isPlayerCharacter,
      role: SoldierRole.soldier,
      portraitIndex: portraitIndex,
      firstName: firstName,
      familyName: familyName,
      name: name,
      placeOrTribeOfOrigin: placeOrTribe.name,
      languages: languages,
      religionType: religion.type,
      religionIntensity: religion.intensity,
      dateOfBirth: dateOfBirth,
      zodiac: zodiac,
      backgroundColor: backgroundColor,
      age: age,
      yearsWithHorde: yearsWithHorde,
      height: height.roundToDouble(),
      startingInjury: startingInjuryType,
      injuryDescription: injuryDesc,
      ailments: ailments,
      healthMax: healthMax,
      exhaustion: exhaustion,
      stress: stress,
      equippedItems: startingEquipment,
      ambition: ambition,
      courage: courage,
      strength: strength,
      longRangeArcherySkill: longRangeArcherySkill,
      mountedArcherySkill: mountedArcherySkill,
      spearSkill: spearSkill,
      swordSkill: swordSkill,
      shieldSkill: shieldSkill,
      perception: perception,
      intelligence: intelligence,
      knowledge: knowledge,
      patience: patience,
      judgment: judgment,
      horsemanship: horsemanship,
      animalHandling: animalHandling,
      honesty: honesty,
      temperament: temperament,
      stamina: stamina,
      hygiene: hygiene,
      charisma: charisma,
      leadership: leadership,
      adaptability: adaptability,
      experience: experience,
      giftOriginPreference: giftOriginPref,
      giftTypePreference: giftTypePref,
      specialSkills: specialSkills,
      attributes: attributes,
      fungibleScrap: fungibleScrap.roundToDouble(),
      fungibleRupees: fungibleRupees.roundToDouble(),
      kilosOfMeat: kilosOfMeat.roundToDouble(),
      kilosOfRice: kilosOfRice.roundToDouble(),
      scars: scars,
      preferredDuties: dutyPrefs['preferred'],
      despisedDuties: dutyPrefs['despised'],
      personalInventory: personalInventory,
    );
  }

  static Zodiac _getZodiac(int birthYear) {
    final int remainder = birthYear % 12;
    switch (remainder) {
      case 0:
        return Zodiac.monkey;
      case 1:
        return Zodiac.rooster;
      case 2:
        return Zodiac.dog;
      case 3:
        return Zodiac.pig;
      case 4:
        return Zodiac.rat;
      case 5:
        return Zodiac.ox;
      case 6:
        return Zodiac.tiger;
      case 7:
        return Zodiac.rabbit;
      case 8:
        return Zodiac.dragon;
      case 9:
        return Zodiac.snake;
      case 10:
        return Zodiac.horse;
      case 11:
        return Zodiac.goat;
      default:
        throw Exception('Invalid birth year remainder: $remainder');
    }
  }

  static Color _getColorForZodiac(Zodiac zodiac) {
    switch (zodiac) {
      case Zodiac.rat:
        return const Color.fromARGB(255, 74, 95, 212);
      case Zodiac.ox:
        return const Color.fromARGB(255, 212, 255, 94);
      case Zodiac.tiger:
        return const Color.fromARGB(255, 235, 164, 57);
      case Zodiac.rabbit:
        return const Color.fromARGB(255, 216, 156, 176);
      case Zodiac.dragon:
        return const Color.fromARGB(255, 156, 161, 75);
      case Zodiac.snake:
        return const Color.fromARGB(255, 134, 45, 37);
      case Zodiac.horse:
        return const Color.fromARGB(255, 73, 136, 75);
      case Zodiac.goat:
        return const Color.fromARGB(255, 111, 94, 139);
      case Zodiac.monkey:
        return const Color.fromARGB(255, 91, 200, 250);
      case Zodiac.rooster:
        return Colors.brown;
      case Zodiac.dog:
        return const Color.fromARGB(255, 197, 137, 207);
      case Zodiac.pig:
        return Colors.grey;
    }
  }
}
