import 'dart:math';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_date.dart';

/// Helper functions for generating dialogue responses in interactions
class DialogueHelpers {
  static final Random _random = Random();

  // --- BIRTHDAY REVELATION TOPICS ---

  /// Generates dialogue about the speaker's own birthday
  /// Returns empty string if no birthday dialogue should occur
  static String topicOwnBirthday(Soldier speaker, GameState gameState) {
    final currentDate = gameState.gameDate;
    final daysUntilBirthday =
        _calculateDaysUntilBirthday(speaker.dateOfBirth, currentDate);

    // Upcoming birthday (within 14 days)
    if (daysUntilBirthday >= 0 && daysUntilBirthday <= 14) {
      if (daysUntilBirthday == 0) {
        // Birthday today - 15% chance to mention
        if (_random.nextDouble() < 0.15) {
          return _useTopic(speaker, 'birthday_today',
              "'It's my birthday today, Captain. Another year older.'");
        }
      } else if (daysUntilBirthday <= 7) {
        // Upcoming birthday within a week - 15% chance
        if (_random.nextDouble() < 0.15) {
          return _useTopic(speaker, 'birthday_soon',
              "'My birthday is in $daysUntilBirthday days, Captain.'");
        }
      }
    }

    // General birthday revelation (anytime) - only 5% chance
    if (_random.nextDouble() < 0.05) {
      final monthName = _getMonthName(speaker.dateOfBirth.month);
      return _useTopic(speaker, 'birthday_reveal',
          "'My birthday is on $monthName ${speaker.dateOfBirth.day}, Captain.'");
    }

    return "";
  }

  /// Generates dialogue about an aravt mate's birthday
  /// Returns empty string if no birthday dialogue should occur
  static String topicMateBirthday(
      Soldier speaker, Soldier mate, GameState gameState) {
    final currentDate = gameState.gameDate;
    final daysUntilBirthday =
        _calculateDaysUntilBirthday(mate.dateOfBirth, currentDate);

    // Upcoming mate birthday (within 7 days) - 15% chance
    if (daysUntilBirthday >= 0 && daysUntilBirthday <= 7) {
      if (_random.nextDouble() < 0.15) {
        return _useTopic(speaker, 'mate_birthday_soon_${mate.id}',
            "${mate.name}'s birthday is coming up in $daysUntilBirthday days.");
      }
    }

    // General mate birthday revelation (anytime) - only 5% chance
    if (_random.nextDouble() < 0.05) {
      final monthName = _getMonthName(mate.dateOfBirth.month);
      return _useTopic(speaker, 'mate_birthday_reveal_${mate.id}',
          "${mate.name}'s birthday is on $monthName ${mate.dateOfBirth.day}.");
    }

    return "";
  }

  // --- HELPER FUNCTIONS ---

  static String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month];
  }

  static int _calculateDaysUntilBirthday(DateTime birthday, GameDate current) {
    // Create this year's birthday as GameDate
    int birthdayYear = current.year;
    GameDate thisBirthday =
        GameDate(birthdayYear, birthday.month, birthday.day);

    // If birthday already passed this year, check next year
    if (current.month > birthday.month ||
        (current.month == birthday.month && current.day > birthday.day)) {
      thisBirthday = GameDate(birthdayYear + 1, birthday.month, birthday.day);
    }

    // Calculate days between
    return thisBirthday.totalDays - current.totalDays;
  }

  static String _useTopic(Soldier soldier, String key, String content) {
    if (soldier.usedDialogueTopics.contains(key)) {
      return "";
    }
    soldier.usedDialogueTopics.add(key);
    return content;
  }

  // --- SCOLD/PRAISE DIALOGUE GENERATION ---

  /// Generates self-critical dialogue (for scold responses)
  /// Uses full dialogue generation with tendency towards self-criticism
  static String generateSelfCriticismDialogue(
      Soldier speaker, GameState gameState) {
    // Try to generate natural dialogue first
    String dialogue = _tryGenerateDialogue(speaker, gameState);
    if (dialogue.isNotEmpty) {
      return dialogue;
    }

    // Fallback to simple self-criticism
    if (speaker.attributes.contains(SoldierAttribute.inept)) {
      return "I know, Captain. I'm just... so clumsy sometimes. I'll try harder.";
    }
    return "You are right. I must do better.";
  }

  /// Generates other-blaming dialogue (for failed scold responses)
  /// Uses full dialogue generation with tendency towards blaming others
  static String generateOtherCriticismDialogue(
      Soldier speaker, GameState gameState) {
    // Try to generate natural dialogue first
    String dialogue = _tryGenerateDialogue(speaker, gameState);
    if (dialogue.isNotEmpty) {
      return dialogue;
    }

    // Fallback to simple deflection
    return "It wasn't entirely my fault!";
  }

  /// Generates other-praising dialogue (for praise responses)
  /// Uses full dialogue generation with tendency towards praising others
  static String generateOtherPraiseDialogue(
      Soldier speaker, GameState gameState) {
    // Try to generate natural dialogue first
    String dialogue = _tryGenerateDialogue(speaker, gameState);
    if (dialogue.isNotEmpty) {
      return dialogue;
    }

    // Fallback to simple credit-sharing
    return "It was a team effort, Captain.";
  }

  /// Generates self-praising dialogue (for failed praise responses)
  /// Uses full dialogue generation with tendency towards self-praise
  static String generateSelfPraiseDialogue(
      Soldier speaker, GameState gameState) {
    // Try to generate natural dialogue first
    String dialogue = _tryGenerateDialogue(speaker, gameState);
    if (dialogue.isNotEmpty) {
      return dialogue;
    }

    // Fallback to simple self-praise
    return "I did well, didn't I?";
  }

  /// Helper to attempt dialogue generation
  /// Returns empty string if no dialogue generated
  static String _tryGenerateDialogue(Soldier speaker, GameState gameState) {
    // This will be implemented to call the dialogue generation system
    // For now, return empty to use fallbacks
    // TODO: Integrate with InteractionService._generateDialogue
    return "";
  }
}
