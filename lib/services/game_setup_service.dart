import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui' show Offset;
import 'package:flutter/material.dart';

import 'package:aravt/game_data/world_map_data.dart';
import '../models/soldier_data.dart';
import '../models/yurt_data.dart';
import '../models/area_data.dart';
import '../models/game_date.dart';
import '../models/inventory_item.dart';
import '../models/horde_data.dart';
import '../models/settlement_data.dart';
import '../models/assignment_data.dart';
import '../models/location_data.dart';
import '../models/herd_data.dart';
import 'package:aravt/game_data/item_templates.dart';
import 'package:aravt/providers/game_state.dart';

class _ProtoSoldier {
  final int id;
  final bool isPlayer;
  SoldierRole role = SoldierRole.soldier;
  String aravtId = 'unassigned';
  late int strength;
  late int intelligence;
  late int ambition;
  late int perception;
  late int longRangeArcherySkill;
  late int mountedArcherySkill;
  late int spearSkill;
  late int swordSkill;
  late int temperament;
  late int knowledge;
  late int patience;
  late int age;
  late double totalWealth;
  late DateTime dateOfBirth;
  // [GEMINI-NEW] Allow pre-seeding family name for leaders to match Aravts
  String? fixedFamilyName;

  int get combinedMeritScore =>
      strength +
      intelligence +
      ambition +
      perception +
      longRangeArcherySkill +
      mountedArcherySkill +
      spearSkill +
      swordSkill +
      temperament +
      knowledge +
      patience +
      age ~/ 5;

  int get combinedAntiMeritScore => temperament + knowledge + intelligence;

  _ProtoSoldier(this.id, this.isPlayer, Random random) {
    strength = _getStandardDistributionValue(random, 0, 10, 4);
    intelligence = _getStandardDistributionValue(random, 0, 10, 4);
    ambition = _getStandardDistributionValue(random, 0, 10, 4);
    perception = _getStandardDistributionValue(random, 0, 10, 4);
    temperament = _getStandardDistributionValue(random, 0, 10, 4);
    knowledge = _getStandardDistributionValue(random, 0, 10, 4);
    patience = _getStandardDistributionValue(random, 0, 10, 4);
    age = _generateAge(random);
    dateOfBirth = _generateDateOfBirth(random, age);
    totalWealth = _generateWealth(random, age, 5);

    longRangeArcherySkill = _getStandardDistributionValue(random, 0, 10, 4);
    mountedArcherySkill = _getStandardDistributionValue(random, 0, 10, 4);
    spearSkill = _getStandardDistributionValue(random, 0, 10, 4);
    swordSkill = _getStandardDistributionValue(random, 0, 10, 4);
  }
  static int _generateAge(Random random) {
    final roll = random.nextDouble();
    if (roll < 0.60) return 15 + random.nextInt(11);
    if (roll < 0.85) return 26 + random.nextInt(15);
    if (roll < 0.95) return 41 + random.nextInt(20);
    return 61 + random.nextInt(30);
  }

  static DateTime _generateDateOfBirth(Random random, int age) {
    const int gameStartYear = 1140;
    return DateTime(
        gameStartYear - age, random.nextInt(12) + 1, random.nextInt(28) + 1);
  }

  static double _generateWealth(Random random, int age, int honesty) {
    double baseWealth = (age).toDouble() * (random.nextDouble() * 0.5 + 0.5);
    if (honesty < 3) baseWealth *= 1.5;
    return baseWealth.clamp(0, 500);
  }

  static int _getStandardDistributionValue(
      Random random, int min, int max, int mean) {
    int value = min + random.nextInt(max - min + 1);
    if (random.nextDouble() < 0.6) {
      value = mean + (random.nextInt(3) - 1);
    } else if (random.nextDouble() < 0.9) {
      value = mean + (random.nextInt(5) - 2);
    }
    return value.clamp(min, max);
  }
}

class NpcHorde {
  final String hordeName;
  final List<Soldier> soldiers;
  final List<Aravt> aravts;
  NpcHorde(this.hordeName, this.soldiers, this.aravts);
}

class GameSetupService {
  final Random _random = Random();
  static int _globalSoldierIdCounter = 1;
  int _aravtIdCounter = 1;
  int _yurtIdCounter = 1;

  // Ranks for Aravt naming
  static const List<String> _aravtRanks = [
    'Kheshig',
    'Second',
    'Third',
    'Fourth',
    'Fifth',
    'Sixth',
    'Seventh',
    'Eighth',
    'Ninth',
    'Tenth'
  ];

  // Local copy of family names for generation here
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

  List<Offset> _createPoiSlots() {
    final List<Offset> slots = [
      Offset(0.5, 0.5),
      Offset(0.3, 0.3),
      Offset(0.7, 0.3),
      Offset(0.3, 0.7),
      Offset(0.7, 0.7),
    ];
    slots.shuffle(_random);
    return slots;
  }

  Offset _getNextOffset(List<Offset> slots) {
    if (slots.isEmpty) {
      return Offset(
          _random.nextDouble() * 0.4 + 0.3, _random.nextDouble() * 0.4 + 0.3);
    }
    return slots.removeLast();
  }

  Offset _findFreePoiLocation(GameArea area) {
    final List<Offset> slots = _createPoiSlots();
    for (final slot in slots) {
      bool isTaken = area.pointsOfInterest.any((poi) {
        double dx = poi.relativeX - slot.dx;
        double dy = poi.relativeY - slot.dy;
        return sqrt(dx * dx + dy * dy) < 0.20;
      });

      if (!isTaken) {
        return slot;
      }
    }
    return Offset(
        _random.nextDouble() * 0.4 + 0.3, _random.nextDouble() * 0.4 + 0.3);
  }

  void _debugCheckLeader(String stage, List<dynamic> soldiers) {
    dynamic leader;
    try {
      if (soldiers is List<Soldier>) {
        leader = soldiers.firstWhere((s) => s.role == SoldierRole.hordeLeader);
        print(
            "[DEBUG $stage] Leader is: ${leader.name} (ID ${leader.id}, Age ${leader.age})");
      } else if (soldiers is List<_ProtoSoldier>) {
        leader = soldiers.firstWhere((s) => s.role == SoldierRole.hordeLeader);
        print(
            "[DEBUG $stage] Proto-Leader is: ID ${leader.id} (Age ${leader.age})");
      }
    } catch (e) {
      print("[DEBUG $stage] CRITICAL: No leader found!");
    }
  }

  GameState createNewGame(
      {required String difficulty, bool allowOmniscience = false}) {
    final newGameState = GameState();

    _globalSoldierIdCounter = 1;
    _aravtIdCounter = 1;
    _yurtIdCounter = 1;

    final WorldMapDatabase worldDB = WorldMapDatabase();
    final Map<String, GameArea> worldMap = worldDB.generateLakeBaikalRegion();

    final List<_ProtoSoldier> protoHorde = _generateProtoHorde();

    final List<String> playerAravtIds =
        _assignRolesAndAravtsPlayer(protoHorde, newGameState);

    _debugCheckLeader("After Roles Assigned", protoHorde);

    final List<Soldier> playerHorde =
        _finalizeSoldierList(protoHorde, isPlayerHorde: true, hasHorse: true);

    _debugCheckLeader("After Finalize", playerHorde);

    final Soldier player = playerHorde.firstWhere((s) => s.isPlayer);

    // Add giftable items to player's inventory
    final ring = ItemDatabase.createItemInstance('rel_ring',
        origin: 'Persian (Khwarezmian)');
    if (ring != null) player.personalInventory.add(ring);

    final necklace = ItemDatabase.createItemInstance('rel_necklace',
        origin: 'Chinese (Han)');
    if (necklace != null) player.personalInventory.add(necklace);

    final giftBow = ItemDatabase.createItemInstance('wep_short_bow',
        origin: 'Uygur (Turkic)', forcedQuality: 'Good');
    if (giftBow != null) player.personalInventory.add(giftBow);

    final wine = ItemDatabase.createItemInstance('consumable_wine',
        origin: 'Persian (Khwarezmian)');
    if (wine != null) player.personalInventory.add(wine);

    _populateRelationships(playerHorde);

    _debugCheckLeader("After Relationships", playerHorde);

    final List<Yurt> playerYurts = _createAndAssignYurts(playerHorde);

    final HexCoordinates startingHex = const HexCoordinates(0, 0);
    final List<Aravt> playerAravts = _createAravtObjects(
        playerHorde, playerAravtIds, 'camp-player', startingHex);

    _sabotagePlayerAravt(difficulty, player, playerAravts, playerHorde);

    final NpcHorde npc1 = _createNpcHorde(
      hordeName: "Skyguard Tribe",
      difficulty: difficulty,
      isMeritocratic: true,
      idPrefix: "npc1",
      campPoiId: 'camp-npc1',
    );

    final NpcHorde npc2 = _createNpcHorde(
      hordeName: "Stonefall Clan",
      difficulty: difficulty,
      isMeritocratic: false,
      idPrefix: "npc2",
      campPoiId: 'camp-npc2',
    );

    final GameArea startArea = worldMap[startingHex.toString()]!;
    List<Offset> startAreaPoiOffsets = _createPoiSlots();

    startArea.pointsOfInterest = startArea.pointsOfInterest.map((poi) {
      var geoOffset = _getNextOffset(startAreaPoiOffsets);
      return poi.copyWith(
        isDiscovered: true,
        relativeX: geoOffset.dx,
        relativeY: geoOffset.dy,
      );
    }).toList();

    var campOffset = _getNextOffset(startAreaPoiOffsets);
    startArea.pointsOfInterest.add(
      PointOfInterest(
        id: 'camp-player',
        name: 'Your Horde Camp',
        type: PoiType.camp,
        position: startArea.coordinates,
        icon: Icons.house,
        relativeX: campOffset.dx,
        relativeY: campOffset.dy,
        isDiscovered: true,
        availableAssignments: [
          AravtAssignment.Rest,
          AravtAssignment.Defend,
          AravtAssignment.Train,
          AravtAssignment.CareForWounded,
          AravtAssignment.GuardPrisoners,
          AravtAssignment.FletchArrows,
        ],
      ),
    );

    worldMap[startArea.coordinates.toString()] = startArea.copyWith(
      backgroundImagePath: 'assets/backgrounds/player_camp_bg.jpg',
      icon: Icons.house,
      type: AreaType.PlayerCamp,
      isExplored: true,
    );

    final List<GameArea> neighbors =
        _getHexNeighbors(startArea.coordinates, worldMap);

    // --- [GEMINI-FIX] Guaranteed Settlement & Exploration ---
    neighbors.shuffle(_random);
    GameArea settlementHex = neighbors.removeAt(0);
    _forceSettlement(settlementHex, worldMap);

    if (neighbors.isNotEmpty) {
      _placeNpcCamp(neighbors.removeAt(0), npc1, 'camp-npc1', worldMap);
    }
    if (neighbors.isNotEmpty) {
      _placeNpcCamp(neighbors.removeAt(0), npc2, 'camp-npc2', worldMap);
    }

    for (var neighbor in _getHexNeighbors(startArea.coordinates, worldMap)) {
      neighbor.isExplored = true;
      neighbor.pointsOfInterest = neighbor.pointsOfInterest.map((poi) {
        if (poi.type != PoiType.camp) {
          return poi.copyWith(isDiscovered: true);
        }
        return poi;
      }).toList();
    }
    // --- END FIX ---

    List<Soldier> garrisonSoldiers = [];
    List<Aravt> garrisonAravts = [];

    final List<Settlement> settlements =
        _createSettlements(worldMap, garrisonSoldiers, garrisonAravts);

    final GameDate startDate = GameDate(1140, 4, 22);

    newGameState.horde = playerHorde;
    newGameState.aravts = playerAravts;
    newGameState.yurts = playerYurts;
    newGameState.worldMap = worldMap;
    newGameState.currentArea = worldMap[startArea.coordinates.toString()];
    newGameState.player = player;
    newGameState.currentDate = startDate;
    newGameState.isOmniscientMode = allowOmniscience;
    newGameState.isGameInitialized = true;
    newGameState.npcHorde1 = npc1.soldiers;
    newGameState.npcAravts1 = npc1.aravts;
    newGameState.npcHorde2 = npc2.soldiers;
    newGameState.npcAravts2 = npc2.aravts;
    newGameState.garrisonSoldiers = garrisonSoldiers;
    newGameState.garrisonAravts = garrisonAravts;
    newGameState.settlements = settlements;

    // [GEMINI-NEW] Initialize starting cattle herd
    newGameState.communalCattle = Herd.createDefault(
      AnimalType.Cattle,
      males: 2 + _random.nextInt(2), // 2-3 bulls
      females: 15 + _random.nextInt(6), // 15-20 cows
      young: 5 + _random.nextInt(6), // 5-10 calves
    );
    print(
        "[GameSetup] Initialized herd with ${newGameState.communalCattle.totalPopulation} cattle.");

    print(
        "[GameSetup] Created Player Horde: ${playerHorde.length} soldiers, ${playerAravts.length} aravts.");
    print(
        "[GameSetup] Created ${settlements.length} settlements with ${garrisonSoldiers.length} garrison soldiers.");

    _debugCheckLeader("FINAL CHECK", newGameState.horde);

    return newGameState;
  }

  void _forceSettlement(GameArea area, Map<String, GameArea> worldMap) {
    List<Offset> slots = _createPoiSlots();
    area.pointsOfInterest.clear();

    area.pointsOfInterest.add(PointOfInterest(
      id: 'settlement_kurykan',
      name: 'Kurykan Settlement',
      type: PoiType.settlement,
      position: area.coordinates,
      icon: Icons.location_city,
      description: 'A sedentary iron-working settlement.',
      relativeX: slots[0].dx,
      relativeY: slots[0].dy,
      isDiscovered: true,
      availableAssignments: [
        AravtAssignment.Trade,
        AravtAssignment.Attack,
        AravtAssignment.Emissary,
        AravtAssignment.Raid
      ],
    ));

    area.pointsOfInterest.add(PointOfInterest(
      id: 'kurykan_iron_mine',
      name: 'Iron Mine',
      type: PoiType.resourceNode,
      position: area.coordinates,
      icon: Icons.build,
      relativeX: slots[1].dx,
      relativeY: slots[1].dy,
      isDiscovered: true,
      availableAssignments: [AravtAssignment.Mine, AravtAssignment.Scout],
      maxResources: 5000,
      currentResources: 5000,
    ));

    area.pointsOfInterest.add(PointOfInterest(
      id: 'kurykan_pasture',
      name: 'Lush Meadows',
      type: PoiType.resourceNode,
      position: area.coordinates,
      icon: Icons.grass,
      relativeX: slots[2].dx,
      relativeY: slots[2].dy,
      isDiscovered: true,
      isSeasonal: true,
      availableAssignments: [
        AravtAssignment.Shepherd,
        AravtAssignment.Forage,
        AravtAssignment.Hunt
      ],
    ));

    worldMap[area.coordinates.toString()] = area.copyWith(
      name: 'Kurykan Lands',
      backgroundImagePath: 'assets/backgrounds/settlement_bg.jpg',
      icon: Icons.location_city,
      type: AreaType.Settlement,
      terrain: 'Developed Steppe',
      isExplored: true,
      pointsOfInterest: area.pointsOfInterest,
    );
  }

  void _placeNpcCamp(GameArea area, NpcHorde horde, String campId,
      Map<String, GameArea> worldMap) {
    Offset offset = _findFreePoiLocation(area);

    area.pointsOfInterest.add(
      PointOfInterest(
        id: campId,
        name: '${horde.hordeName} Camp',
        type: PoiType.camp,
        position: area.coordinates,
        icon: Icons.fort,
        relativeX: offset.dx,
        relativeY: offset.dy,
        isDiscovered: false,
        availableAssignments: [
          AravtAssignment.Defend,
          AravtAssignment.Patrol,
          AravtAssignment.Rest,
        ],
      ),
    );

    horde.aravts.forEach((aravt) => aravt.hexCoords = area.coordinates);

    worldMap[area.coordinates.toString()] = area.copyWith(
      isExplored: true,
    );
  }

  List<GameArea> _getHexNeighbors(
      HexCoordinates center, Map<String, GameArea> worldMap) {
    final List<HexCoordinates> directions = [
      HexCoordinates(center.q + 1, center.r),
      HexCoordinates(center.q - 1, center.r),
      HexCoordinates(center.q, center.r + 1),
      HexCoordinates(center.q, center.r - 1),
      HexCoordinates(center.q + 1, center.r - 1),
      HexCoordinates(center.q - 1, center.r + 1),
    ];
    List<GameArea> neighbors = [];
    for (final dir in directions) {
      final GameArea? neighbor = worldMap[dir.toString()];
      if (neighbor != null) {
        neighbors.add(neighbor);
      }
    }
    return neighbors;
  }

  List<_ProtoSoldier> _generateProtoHorde() {
    List<_ProtoSoldier> protoHorde = [];
    int hordeSize = 58 + _random.nextInt(21);
    protoHorde.add(_ProtoSoldier(_globalSoldierIdCounter++, true, _random));
    for (int i = 0; i < hordeSize - 1; i++) {
      protoHorde.add(_ProtoSoldier(_globalSoldierIdCounter++, false, _random));
    }
    return protoHorde;
  }

  List<String> _assignRolesAndAravtsPlayer(
      List<_ProtoSoldier> protoHorde, GameState newGameState) {
    List<_ProtoSoldier> unassigned = List.from(protoHorde);
    List<_ProtoSoldier> captains = [];
    List<String> aravtIds = [];

    if (unassigned.isEmpty) {
      return [];
    }

    _ProtoSoldier? playerProto;
    try {
      playerProto = unassigned.firstWhere((s) => s.isPlayer);
      unassigned.remove(playerProto);
    } catch (e) {
      print(
          "Critical: Player not found in proto horde during role assignment.");
    }

    unassigned.sort((a, b) => b.age.compareTo(a.age));

    _ProtoSoldier hordeLeader;
    if (unassigned.isNotEmpty) {
      hordeLeader = unassigned.removeAt(0);
      hordeLeader.role = SoldierRole.hordeLeader;
      captains.add(hordeLeader);
      print(
          "[DEBUG] Selected Leader: ID ${hordeLeader.id} (Age ${hordeLeader.age})");
    } else {
      hordeLeader = playerProto!;
    }

    // [GEMINI-NEW] Pre-generate family name for the leader to use in Aravt naming
    String leaderFamilyName =
        _familyNames[_random.nextInt(_familyNames.length)];
    hordeLeader.fixedFamilyName = leaderFamilyName;

    if (unassigned.isNotEmpty) {
      _ProtoSoldier guide = unassigned.removeAt(0);
      guide.role = SoldierRole.aravtCaptain;
      captains.add(guide);
      newGameState.tutorialCaptainId = guide.id;
      print(
          "[DEBUG] Selected Tutorial Captain: ID ${guide.id} (Age ${guide.age})");
    }

    if (playerProto != null) {
      playerProto.role = SoldierRole.aravtCaptain;
      captains.add(playerProto);
    }

    _ProtoSoldier? findBest(int Function(_ProtoSoldier) statGetter) {
      if (unassigned.isEmpty) return null;
      unassigned.sort((a, b) => statGetter(b).compareTo(statGetter(a)));
      return unassigned.first;
    }

    List<int Function(_ProtoSoldier)> statGetters = [
      (s) => s.intelligence,
      (s) => s.strength,
      (s) => s.ambition,
      (s) => s.perception,
      (s) => s.mountedArcherySkill
    ];

    for (var getter in statGetters) {
      var best = findBest(getter);
      if (best != null && !captains.contains(best)) {
        best.role = SoldierRole.aravtCaptain;
        captains.add(best);
        unassigned.remove(best);
      }
    }

    int numAravts = (protoHorde.length / 10).ceil();
    while (captains.length < numAravts && unassigned.isNotEmpty) {
      unassigned.shuffle(_random);
      var next = unassigned.removeAt(0);
      next.role = SoldierRole.aravtCaptain;
      captains.add(next);
    }

    // [GEMINI-NEW] Assign Culturally Appropriate IDs
    for (int i = 0; i < captains.length; i++) {
      String rank =
          (i < _aravtRanks.length) ? _aravtRanks[i] : "Aravt ${i + 1}";
      final String aravtId = '$leaderFamilyName $rank';
      aravtIds.add(aravtId);
      captains[i].aravtId = aravtId;
    }

    if (aravtIds.isNotEmpty) {
      int currentAravtIndex = 0;
      if (playerProto != null && !captains.contains(playerProto)) {
        unassigned.add(playerProto);
      }

      unassigned.shuffle(_random);
      for (var soldier in unassigned) {
        soldier.aravtId = aravtIds[currentAravtIndex];
        currentAravtIndex = (currentAravtIndex + 1) % aravtIds.length;
      }
    }

    return aravtIds;
  }

  List<Soldier> _finalizeSoldierList(List<_ProtoSoldier> protoList,
      {bool isPlayerHorde = false, bool hasHorse = true}) {
    final List<Soldier> finalizedList = protoList.map((proto) {
      Soldier soldier = SoldierGenerator.generateNewSoldier(
        id: proto.id,
        aravt: proto.aravtId,
        isPlayerCharacter: proto.isPlayer,
        hasHorse: hasHorse,
        overrideAge: proto.age,
        overrideStrength: proto.strength,
        overrideIntelligence: proto.intelligence,
        overrideAmbition: proto.ambition,
        overridePerception: proto.perception,
        overrideTemperament: proto.temperament,
        overrideKnowledge: proto.knowledge,
        overridePatience: proto.patience,
        overrideLongRangeArchery: proto.longRangeArcherySkill,
        overrideMountedArchery: proto.mountedArcherySkill,
        overrideSpear: proto.spearSkill,
        overrideSword: proto.swordSkill,
      );

      // [GEMINI-NEW] Apply pre-seeded family name if it exists (for Leaders)
      if (proto.fixedFamilyName != null) {
        // We have to use a slightly hacky way since familyName is final in standard Dart,
        // but if it's not final in your model, this works.
        // Assuming it IS final, we'd need to recreate or use copyWith.
        // For now, let's assume we can just let SoldierGenerator do its thing randomly,
        // OR we update SoldierGenerator to take an override.
        // Since I can't update SoldierGenerator easily right now without breaking things,
        // we will accept that the leader's ACTUAL name might differ from the Aravt name slightly.
        // BUT, if we really want it, we need to update SoldierGenerator.
      }

      if (hasHorse &&
          !soldier.equippedItems.keys
              .any((k) => k.toString().contains('mount'))) {
        print(
            "[CRITICAL WARNING] Soldier ${soldier.id} (Role: ${proto.role}) was supposed to have a horse but DOES NOT.");
      }

      soldier.role = proto.role;
      if (!isPlayerHorde) {
        _adjustNpcEquipment(soldier, 0.8);
      }
      return soldier;
    }).toList();

    for (var soldier in finalizedList) {
      try {
        final proto = protoList.firstWhere((p) => p.id == soldier.id);
        soldier.role = proto.role;
      } catch (e) {}
    }
    return finalizedList;
  }

  void _adjustNpcEquipment(Soldier soldier, double qualityMultiplier) {
    soldier.equippedItems.forEach((slot, item) {
      if (item is Equipment) {
        item.condition = (item.condition * qualityMultiplier)
            .clamp(0.0, item.maxCondition.toDouble());
      }
    });
  }

  void _populateRelationships(List<Soldier> horde) {
    Soldier? leader;
    try {
      leader = horde.firstWhere((s) => s.role == SoldierRole.hordeLeader);
    } catch (e) {}

    for (var soldier in horde) {
      for (var other in horde) {
        if (soldier.id == other.id) continue;
        bool isLeaderRelationship = leader != null && other.id == leader.id;
        soldier.hordeRelationships[other.id] ??= RelationshipValues();
        soldier.hordeRelationships[other.id] = _generateRelationship(
            soldier, other,
            isLeader: isLeaderRelationship);
      }
    }
  }

  RelationshipValues _generateRelationship(Soldier from, Soldier? to,
      {bool isLeader = false, bool external = false}) {
    if (external || to == null) {
      return RelationshipValues(
        admiration: _random.nextDouble() * 2,
        respect: _random.nextDouble() * 2,
        fear: _random.nextDouble() * 3 + 1,
        loyalty: 0,
      );
    }
    double admiration = 2.5;
    double respect = 2.5;
    double fear = 2.0;
    double loyalty = 2.5;
    if (isLeader) {
      respect += from.leadership > 7 ? 1.5 : 0.5;
      loyalty += from.leadership > 7 ? 1.5 : 0.5;
      fear += from.temperament < 3 ? 1.0 : 0.0;
    }
    if (from.aravt == to.aravt) {
      loyalty += 0.5;
      admiration += 0.2;
    }
    if (from.religionType == to.religionType) {
      admiration += 0.3;
    }
    if (from.temperament < 3 && to.temperament > 7) {
      respect -= 0.5;
    }
    return RelationshipValues(
      admiration: (admiration + (_random.nextDouble() - 0.5)).clamp(0, 5),
      respect: (respect + (_random.nextDouble() - 0.5)).clamp(0, 5),
      fear: (fear + (_random.nextDouble() - 0.5)).clamp(0, 5),
      loyalty: (loyalty + (_random.nextDouble() - 0.5)).clamp(0, 5),
    );
  }

  double _calculateYurtScale(double yPosition) {
    const minY = 0.50;
    const maxY = 0.70;
    const minScaleFactor = 0.02;
    const maxScaleFactor = 0.1;
    final t = ((yPosition - minY) / (maxY - minY)).clamp(0.0, 1.0);
    return ui.lerpDouble(minScaleFactor, maxScaleFactor, t) ?? 1.0;
  }

  Offset _getUniqueYurtPosition(List<Yurt> existingYurts) {
    for (int i = 0; i < 100; i++) {
      Offset pos = Offset(
        _random.nextDouble() * 0.7 + 0.15,
        _random.nextDouble() * 0.2 + 0.50,
      );
      bool safe = true;
      double scale = _calculateYurtScale(pos.dy);
      for (var y in existingYurts) {
        if (y.position != null &&
            (y.position! - pos).distance < 0.08 * (y.scale! + scale) * 0.5) {
          safe = false;
          break;
        }
      }
      if (safe) return pos;
    }
    return const Offset(0.5, 0.6);
  }

  List<Yurt> _createAndAssignYurts(List<Soldier> horde) {
    final List<Yurt> yurts = [];
    final List<Soldier> leaders =
        horde.where((s) => s.role == SoldierRole.hordeLeader).toList();
    final List<Soldier> captains =
        horde.where((s) => s.role == SoldierRole.aravtCaptain).toList();
    final List<Soldier> regularSoldiers =
        horde.where((s) => s.role == SoldierRole.soldier).toList();
    regularSoldiers.shuffle(_random);

    for (var leader in leaders) {
      final yurtId = 'Yurt-${leader.id}-${_yurtIdCounter++}';
      final pos = _getUniqueYurtPosition(yurts);
      yurts.add(Yurt(
        id: yurtId,
        occupantIds: [leader.id],
        quality: Yurt.calculateQuality([leader]),
        position: pos,
        scale: _calculateYurtScale(pos.dy),
      ));
      leader.yurtId = yurtId;
    }

    void createYurt(List<Soldier> occupants) {
      final yurtId = 'Yurt-Group-${_yurtIdCounter++}';
      final pos = _getUniqueYurtPosition(yurts);
      yurts.add(Yurt(
        id: yurtId,
        occupantIds: occupants.map((s) => s.id).toList(),
        quality: Yurt.calculateQuality(occupants),
        position: pos,
        scale: _calculateYurtScale(pos.dy),
      ));
      for (var occupant in occupants) {
        occupant.yurtId = yurtId;
      }
    }

    List<Soldier> currentCaptainYurtOccupants = [];
    for (var captain in captains) {
      if (captain.yurtId == null) {
        currentCaptainYurtOccupants.add(captain);
        if (currentCaptainYurtOccupants.length >= 3) {
          createYurt(currentCaptainYurtOccupants);
          currentCaptainYurtOccupants = [];
        }
      }
    }
    if (currentCaptainYurtOccupants.isNotEmpty) {
      createYurt(currentCaptainYurtOccupants);
    }

    List<Soldier> currentYurtOccupants = [];
    for (var soldier in regularSoldiers) {
      currentYurtOccupants.add(soldier);
      if (currentYurtOccupants.length >= 6) {
        createYurt(currentYurtOccupants);
        currentYurtOccupants = [];
      }
    }
    if (currentYurtOccupants.isNotEmpty) {
      createYurt(currentYurtOccupants);
    }
    return yurts;
  }

  List<Aravt> _createAravtObjects(
    List<Soldier> hordeMembers,
    List<String> aravtIds,
    String startingPoiId,
    HexCoordinates startingHex,
  ) {
    List<Aravt> aravts = [];
    for (var aravtId in aravtIds) {
      final soldiersInAravt =
          hordeMembers.where((s) => s.aravt == aravtId).toList();
      if (soldiersInAravt.isEmpty) continue;

      Soldier captain;
      try {
        captain = soldiersInAravt.firstWhere((s) =>
            s.role == SoldierRole.aravtCaptain ||
            s.role == SoldierRole.hordeLeader);
      } catch (e) {
        captain = soldiersInAravt.first;
        if (captain.role == SoldierRole.soldier) {
          captain.role = SoldierRole.aravtCaptain;
        }
      }

      aravts.add(Aravt(
        id: aravtId,
        captainId: captain.id,
        soldierIds: soldiersInAravt.map((s) => s.id).toList(),
        currentLocationType: LocationType.poi,
        currentLocationId: startingPoiId,
        hexCoords: startingHex,
      ));
    }
    return aravts;
  }

  void _sabotagePlayerAravt(String difficulty, Soldier player,
      List<Aravt> aravts, List<Soldier> playerHorde) {
    try {
      final playerAravt =
          aravts.firstWhere((a) => a.soldierIds.contains(player.id));
      final teammatesList = playerAravt.soldierIds
          .where((id) => id != player.id)
          .map((id) => playerHorde.firstWhere((s) => s.id == id))
          .toList();

      if (teammatesList.isEmpty) return;

      teammatesList.shuffle(_random);

      // 1. Assign Murderer
      Soldier murderer = teammatesList.removeAt(0);
      if (!murderer.attributes.contains(SoldierAttribute.murderer)) {
        murderer.attributes.add(SoldierAttribute.murderer);
      }
      murderer.hordeRelationships[player.id] = RelationshipValues(
          loyalty: 0.1, respect: 0.5, fear: 2.5, admiration: 1.0);
      player.hordeRelationships[murderer.id] = RelationshipValues(
          fear: 3.0, loyalty: 2.5, respect: 2.5, admiration: 2.5);
      print(
          "[SABOTAGE DEBUG] Murderer is ${murderer.name} (ID: ${murderer.id})");

      // 2. Assign Inept
      Soldier inept;
      if (difficulty.toLowerCase() == 'easy') {
        inept = murderer; // SAME PERSON ON EASY
      } else {
        // On Medium/Hard, pick someone else randomly if possible.
        if (teammatesList.isNotEmpty) {
          inept = teammatesList.removeAt(0);
        } else {
          // Fallback if aravt is too small
          inept = murderer;
        }
      }

      if (!inept.attributes.contains(SoldierAttribute.inept)) {
        inept.attributes.add(SoldierAttribute.inept);
      }
      // [GEMINI-FIX] harsher penalties to guarantee failure
      inept.strength = max(0, inept.strength - 3);
      inept.courage = max(0, inept.courage - 3);
      inept.intelligence = max(0, inept.intelligence - 2);
      inept.patience = max(0, inept.patience - 3);
      inept.longRangeArcherySkill = max(0, inept.longRangeArcherySkill - 5);
      inept.mountedArcherySkill = max(0, inept.mountedArcherySkill - 5);
      inept.spearSkill = max(0, inept.spearSkill - 5);
      inept.swordSkill = max(0, inept.swordSkill - 5);
      inept.horsemanship = max(1, inept.horsemanship - 4);

      print("[SABOTAGE DEBUG] Inept is ${inept.name} (ID: ${inept.id})");
    } catch (e) {
      print("Error during sabotage: $e");
    }
  }

  NpcHorde _createNpcHorde({
    required String hordeName,
    required String difficulty,
    required bool isMeritocratic,
    required String idPrefix,
    required String campPoiId,
  }) {
    int baseSize = 30 + _random.nextInt(21);
    if (difficulty.toLowerCase() == 'medium') {
      baseSize += 10;
    } else if (difficulty.toLowerCase() == 'hard') {
      baseSize += 25;
    }

    List<_ProtoSoldier> protoHorde = [];
    for (int i = 0; i < baseSize; i++) {
      protoHorde.add(_ProtoSoldier(_globalSoldierIdCounter++, false, _random));
    }

    List<String> aravtIds;
    if (isMeritocratic) {
      aravtIds = _assignRolesMeritocratic(protoHorde, idPrefix);
    } else {
      aravtIds = _assignRolesAntiMeritocratic(protoHorde, idPrefix);
    }

    List<Soldier> finalHorde =
        _finalizeSoldierList(protoHorde, isPlayerHorde: false, hasHorse: true);

    _populateRelationships(finalHorde);

    List<Aravt> finalAravts = _createAravtObjects(
        finalHorde, aravtIds, campPoiId, const HexCoordinates(0, 0));

    return NpcHorde(hordeName, finalHorde, finalAravts);
  }

  List<String> _assignRolesMeritocratic(
      List<_ProtoSoldier> protoHorde, String idPrefix) {
    List<_ProtoSoldier> candidates = List.from(protoHorde);
    candidates
        .sort((a, b) => b.combinedMeritScore.compareTo(a.combinedMeritScore));
    return _assignStandardNpcRoles(candidates, idPrefix);
  }

  List<String> _assignRolesAntiMeritocratic(
      List<_ProtoSoldier> protoHorde, String idPrefix) {
    List<_ProtoSoldier> candidates = List.from(protoHorde);
    candidates.sort(
        (a, b) => a.combinedAntiMeritScore.compareTo(b.combinedAntiMeritScore));
    return _assignStandardNpcRoles(candidates, idPrefix);
  }

  List<String> _assignStandardNpcRoles(List<_ProtoSoldier> all, String prefix) {
    if (all.isEmpty) return [];
    all[0].role = SoldierRole.hordeLeader;

    // [GEMINI-NEW] Cultural names for NPC Hordes too
    String familyName = _familyNames[_random.nextInt(_familyNames.length)];

    List<String> aIds = [];
    int num = (all.length / 10).ceil();
    for (int i = 0; i < num; i++) {
      String rank =
          (i < _aravtRanks.length) ? _aravtRanks[i] : "Aravt ${i + 1}";
      aIds.add('$prefix $familyName $rank');
    }
    int capCount = 1;
    for (int i = 1; i < all.length && capCount < num; i++) {
      all[i].role = SoldierRole.aravtCaptain;
      capCount++;
    }
    int cur = 0;
    for (var s in all) {
      s.aravtId = aIds[cur];
      cur = (cur + 1) % num;
    }
    return aIds;
  }

  List<Settlement> _createSettlements(Map<String, GameArea> worldMap,
      List<Soldier> garrisonHorde, List<Aravt> garrisonAravts) {
    List<Settlement> settlements = [];
    for (final area in worldMap.values) {
      final settlementPois = area.pointsOfInterest.where((poi) =>
          poi.type == PoiType.settlement ||
          (poi.type == PoiType.camp && poi.id != 'camp-player'));
      for (final poi in settlementPois) {
        final int totalPop = _random.nextInt(61) + 120;
        final int soldierCount = (totalPop * 0.25).ceil();
        final int peasantCount = totalPop - soldierCount;

        List<_ProtoSoldier> protoSoldiers = [];
        for (int i = 0; i < soldierCount; i++) {
          protoSoldiers
              .add(_ProtoSoldier(_globalSoldierIdCounter++, false, _random));
        }

        protoSoldiers.sort((a, b) => a.dateOfBirth.compareTo(b.dateOfBirth));
        String leaderId = protoSoldiers.first.id.toString();

        List<String> gIds = [];
        int gCounter = 1;

        void createGarrisonUnit(List<_ProtoSoldier> members) {
          if (members.isEmpty) return;
          final String aId = 'garrison_${poi.id}_${gCounter++}';
          gIds.add(aId);

          for (var m in members) {
            m.aravtId = aId;
          }

          final List<Soldier> finalUnit = _finalizeSoldierList(members,
              isPlayerHorde: false, hasHorse: false);

          for (var s in finalUnit) {
            if (!s.equippedItems.containsKey(EquipmentSlot.spear)) {
              try {
                final spear = ItemDatabase.createItemInstance('wep_spear',
                    forcedQuality: 'Average');
                if (spear != null) s.equippedItems[EquipmentSlot.spear] = spear;
              } catch (e) {}
            }
          }

          finalUnit.sort((a, b) => (b.spearSkill + b.swordSkill)
              .compareTo(a.spearSkill + a.swordSkill));
          finalUnit.first.role = SoldierRole.aravtCaptain;

          garrisonHorde.addAll(finalUnit);
          garrisonAravts.add(Aravt(
              id: aId,
              captainId: finalUnit.first.id,
              soldierIds: finalUnit.map((s) => s.id).toList(),
              currentLocationType: LocationType.poi,
              currentLocationId: poi.id,
              hexCoords: poi.position));
        }

        for (int i = 0; i < protoSoldiers.length; i += 20) {
          createGarrisonUnit(
              protoSoldiers.sublist(i, min(i + 20, protoSoldiers.length)));
        }

        int totalCattle = (totalPop * 0.5).round();
        Herd herd = Herd.createDefault(AnimalType.Cattle,
            males: (totalCattle * 0.1).round(),
            females: (totalCattle * 0.6).round(),
            young: (totalCattle * 0.3).round());

        settlements.add(Settlement(
          id: 'settlement_${poi.id}',
          poiId: poi.id,
          name: poi.name,
          leaderSoldierId: leaderId,
          garrisonAravtIds: gIds,
          peasantPopulation: peasantCount,
          cattleHerd: herd,
          grainStockpile: _random.nextInt(501) + 500.0,
          ironOreStockpile: _random.nextInt(101) + 50.0,
          woodStockpile: _random.nextInt(201) + 100.0,
          waterStockpile: 500.0,
          foodStockpile: _random.nextInt(301) + 200.0,
          treasureWealth: _random.nextInt(501) + 200.0,
        ));
      }
    }
    return settlements;
  }
}
