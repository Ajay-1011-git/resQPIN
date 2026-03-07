/// Lightweight token-based NLP classifier for emergency text.
///
/// Pipeline: Normalize → Tokenize → Score → Classify → Confidence check.
///
/// Takes free-form text (from speech recognition) and classifies it into:
/// - **type**: one of POLICE, FIRE, AMBULANCE, FISHERMAN (matches `kSOSTypes`)
/// - **subCategory**: a subcategory string (matches entries in `kSubcategories`)
/// - **severity**: HIGH, MEDIUM, or LOW
///
/// This service is stateless and does not depend on any Flutter or Firebase APIs.
class NLPClassifierService {
  // ─── Confidence threshold ──────────────────────────────────────────────
  // If fewer than this fraction of tokens match any keyword, return UNKNOWN.
  static const double _confidenceThreshold = 0.08;

  // ─── Department keyword sets ──────────────────────────────────────────
  // Single-token keywords for token-level matching.

  static const Set<String> _fireTokens = {
    'fire', 'flame', 'flames', 'smoke', 'burning', 'burn', 'gas',
    'explosion', 'explode', 'inferno', 'blaze', 'arson', 'electrical',
    'circuit', 'spark', 'propane', 'cylinder', 'leak', 'ignite',
  };

  static const Set<String> _medicalTokens = {
    'accident', 'bleeding', 'blood', 'collapsed', 'collapse', 'unconscious',
    'heart', 'breathing', 'choking', 'seizure', 'fracture', 'broken',
    'injured', 'injury', 'stroke', 'fainted', 'pregnancy', 'pregnant',
    'labor', 'chest', 'poison', 'overdose', 'cpr', 'ambulance', 'medical',
    'hospital', 'pain', 'vomiting', 'fever', 'diabetic', 'allergic',
    'anaphylaxis', 'unresponsive', 'cardiac', 'wound', 'hurt',
  };

  static const Set<String> _policeTokens = {
    'theft', 'thief', 'rob', 'robbing', 'robbery', 'stole', 'stolen',
    'steal', 'attack', 'attacked', 'assault', 'suspicious', 'violence',
    'violent', 'weapon', 'gun', 'knife', 'murder', 'kidnap', 'kidnapped',
    'harass', 'harassment', 'stalking', 'burglary', 'trespassing',
    'vandalism', 'fight', 'fighting', 'police', 'threat', 'threatening',
    'abuse', 'domestic', 'criminal', 'crime', 'looting',
  };

  static const Set<String> _fishermanTokens = {
    'boat', 'ship', 'vessel', 'engine', 'sea', 'ocean', 'water',
    'navigation', 'coast', 'coastguard', 'sinking', 'capsized', 'stranded',
    'fisherman', 'fishing', 'mayday', 'anchor', 'drift', 'drifting',
    'overboard', 'propeller', 'reef', 'tide', 'storm', 'wave', 'sailor',
  };

  // ─── Multi-word phrases (bonus scoring) ────────────────────────────────
  // These are checked against the full normalized text for extra weight.

  static const Map<String, String> _multiWordPhrases = {
    'gas leak': 'FIRE',
    'electrical fire': 'FIRE',
    'short circuit': 'FIRE',
    'heart attack': 'AMBULANCE',
    'not breathing': 'AMBULANCE',
    'chest pain': 'AMBULANCE',
    'broken bone': 'AMBULANCE',
    'suspicious activity': 'POLICE',
    'break in': 'POLICE',
    'breaking in': 'POLICE',
    'engine failure': 'FISHERMAN',
    'lost navigation': 'FISHERMAN',
    'man overboard': 'FISHERMAN',
    'storm at sea': 'FISHERMAN',
  };

  // ─── Severity keyword sets ─────────────────────────────────────────────

  static const Set<String> _highSeverityTokens = {
    'bleeding', 'unconscious', 'explosion', 'murder', 'kidnap', 'kidnapped',
    'collapsed', 'sinking', 'capsized', 'choking', 'seizure', 'stroke',
    'gun', 'weapon', 'dying', 'dead', 'critical', 'severe', 'anaphylaxis',
    'overdose', 'mayday', 'overboard', 'arson', 'assault', 'burning',
  };

  static const Set<String> _mediumSeverityTokens = {
    'accident', 'theft', 'injured', 'injury', 'robbery', 'stole', 'stolen',
    'fight', 'harass', 'fracture', 'broken', 'smoke', 'stranded', 'lost',
    'pain', 'vandalism', 'engine',
  };

  static const Set<String> _lowSeverityTokens = {
    'suspicious', 'noise', 'minor', 'small', 'slight', 'trespassing',
    'stalking', 'drift', 'mild',
  };

  // Multi-word severity phrases checked against full text
  static const Map<String, String> _severityPhrases = {
    'not breathing': 'HIGH',
    'huge fire': 'HIGH',
    'heart attack': 'HIGH',
    'man overboard': 'HIGH',
    'gas leak': 'MEDIUM',
    'engine failure': 'MEDIUM',
    'break in': 'MEDIUM',
    'suspicious activity': 'LOW',
  };

  // ─── Subcategory mapping per department ────────────────────────────────

  static const Map<String, Map<String, Set<String>>> _subCategoryTokens = {
    'FIRE': {
      'House fire': {'fire', 'house', 'home', 'burning', 'flame', 'blaze', 'inferno'},
      'Electrical fire': {'electrical', 'circuit', 'wiring', 'spark', 'electric'},
      'Gas leak': {'gas', 'leak', 'smell', 'propane', 'cylinder'},
    },
    'AMBULANCE': {
      'Accident': {'accident', 'crash', 'collision', 'hit', 'injured', 'injury', 'fracture', 'broken'},
      'Heart attack': {'heart', 'chest', 'cardiac', 'collapsed', 'cpr', 'stroke'},
      'Unconscious': {'unconscious', 'fainted', 'unresponsive', 'seizure', 'choking', 'breathing'},
      'Pregnancy emergency': {'pregnancy', 'pregnant', 'labor', 'contractions', 'delivery', 'baby'},
    },
    'POLICE': {
      'Theft': {'theft', 'thief', 'stole', 'stolen', 'steal', 'rob', 'robbing', 'robbery', 'burglary'},
      'Violence': {'violence', 'violent', 'attack', 'attacked', 'assault', 'fight', 'fighting', 'weapon', 'gun', 'knife', 'murder', 'abuse', 'domestic', 'threat', 'threatening'},
      'Suspicious activity': {'suspicious', 'stalking', 'trespassing', 'vandalism', 'harass', 'harassment'},
    },
    'FISHERMAN': {
      'Engine failure': {'engine', 'propeller', 'motor', 'stalled'},
      'Lost navigation': {'navigation', 'lost', 'drift', 'drifting', 'stranded', 'direction'},
      'Medical emergency at sea': {'medical', 'sea', 'injured', 'unconscious', 'overboard'},
    },
  };

  // ═══════════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════

  /// Classify free-form emergency text into a structured result.
  ///
  /// Pipeline: normalize → tokenize → score departments → detect subcategory
  /// → detect severity → compute confidence → return result.
  EmergencyClassification classifyEmergency(String text) {
    // ── STEP 1: Normalize ──
    final normalized = _normalize(text);
    print('[NLPClassifier] Normalized text: "$normalized"');

    // ── STEP 2: Tokenize ──
    final tokens = _tokenize(normalized);
    print('[NLPClassifier] Tokens (${tokens.length}): $tokens');

    if (tokens.isEmpty) {
      print('[NLPClassifier] No tokens — returning UNKNOWN');
      return const EmergencyClassification(
        type: 'UNKNOWN',
        subCategory: 'Unrecognized',
        severity: 'MEDIUM',
        confidence: 0.0,
      );
    }

    // ── STEP 3 & 4: Score departments via token matching ──
    int fireScore = 0;
    int medicalScore = 0;
    int policeScore = 0;
    int fishermanScore = 0;
    int totalMatches = 0;

    for (final token in tokens) {
      if (_fireTokens.contains(token)) {
        fireScore++;
        totalMatches++;
      }
      if (_medicalTokens.contains(token)) {
        medicalScore++;
        totalMatches++;
      }
      if (_policeTokens.contains(token)) {
        policeScore++;
        totalMatches++;
      }
      if (_fishermanTokens.contains(token)) {
        fishermanScore++;
        totalMatches++;
      }
    }

    // Bonus: multi-word phrase matching against full text
    for (final entry in _multiWordPhrases.entries) {
      if (normalized.contains(entry.key)) {
        switch (entry.value) {
          case 'FIRE':
            fireScore += 2;
            break;
          case 'AMBULANCE':
            medicalScore += 2;
            break;
          case 'POLICE':
            policeScore += 2;
            break;
          case 'FISHERMAN':
            fishermanScore += 2;
            break;
        }
        totalMatches++;
      }
    }

    print('[NLPClassifier] fireScore: $fireScore');
    print('[NLPClassifier] medicalScore: $medicalScore');
    print('[NLPClassifier] policeScore: $policeScore');
    print('[NLPClassifier] fishermanScore: $fishermanScore');

    // ── STEP 5: Determine department (highest score) ──
    final scores = {
      'FIRE': fireScore,
      'AMBULANCE': medicalScore,
      'POLICE': policeScore,
      'FISHERMAN': fishermanScore,
    };

    String bestType = 'UNKNOWN';
    int bestScore = 0;
    scores.forEach((type, score) {
      if (score > bestScore) {
        bestScore = score;
        bestType = type;
      }
    });

    // ── STEP 8: Confidence check ──
    final double confidence = tokens.isNotEmpty
        ? totalMatches / tokens.length
        : 0.0;
    print('[NLPClassifier] Confidence: ${(confidence * 100).toStringAsFixed(1)}% '
        '($totalMatches matches / ${tokens.length} tokens)');

    if (bestScore == 0 || confidence < _confidenceThreshold) {
      print('[NLPClassifier] Low confidence or no matches — returning UNKNOWN');
      return EmergencyClassification(
        type: 'UNKNOWN',
        subCategory: 'Unrecognized',
        severity: 'MEDIUM',
        confidence: confidence,
      );
    }

    // ── STEP 6: Category detection within department ──
    final subCategory = _determineSubCategory(tokens, normalized, bestType);

    // ── STEP 7: Severity detection ──
    final severity = _determineSeverity(tokens, normalized);

    print('[NLPClassifier] Predicted: $bestType / $subCategory / $severity');
    return EmergencyClassification(
      type: bestType,
      subCategory: subCategory,
      severity: severity,
      confidence: confidence,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  /// STEP 1: Lowercase, strip punctuation, trim.
  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ')    // collapse whitespace
        .trim();
  }

  /// STEP 2: Split normalized text into word tokens.
  List<String> _tokenize(String normalized) {
    if (normalized.isEmpty) return [];
    return normalized.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// STEP 6: Pick best subcategory for the winning department.
  String _determineSubCategory(
      List<String> tokens, String normalized, String department) {
    final categoryMap = _subCategoryTokens[department];
    if (categoryMap == null) return 'General Emergency';

    String bestCategory = categoryMap.keys.first;
    int bestScore = 0;

    categoryMap.forEach((category, keywords) {
      int score = 0;
      // Token-level matching
      for (final token in tokens) {
        if (keywords.contains(token)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestCategory = category;
      }
    });

    return bestCategory;
  }

  /// STEP 7: Determine severity from tokens + multi-word phrases.
  String _determineSeverity(List<String> tokens, String normalized) {
    int highScore = 0;
    int mediumScore = 0;
    int lowScore = 0;

    // Token-level scoring
    for (final token in tokens) {
      if (_highSeverityTokens.contains(token)) highScore++;
      if (_mediumSeverityTokens.contains(token)) mediumScore++;
      if (_lowSeverityTokens.contains(token)) lowScore++;
    }

    // Multi-word phrase bonus
    for (final entry in _severityPhrases.entries) {
      if (normalized.contains(entry.key)) {
        switch (entry.value) {
          case 'HIGH':
            highScore += 2;
            break;
          case 'MEDIUM':
            mediumScore += 2;
            break;
          case 'LOW':
            lowScore += 2;
            break;
        }
      }
    }

    if (highScore >= mediumScore && highScore >= lowScore && highScore > 0) {
      return 'HIGH';
    }
    if (mediumScore >= lowScore && mediumScore > 0) {
      return 'MEDIUM';
    }
    if (lowScore > 0) {
      return 'LOW';
    }
    return 'MEDIUM';
  }
}

/// Result of NLP classification.
class EmergencyClassification {
  /// SOS type: POLICE, FIRE, AMBULANCE, FISHERMAN, or UNKNOWN
  final String type;

  /// Subcategory matching entries in `kSubcategories`
  final String subCategory;

  /// Severity: HIGH, MEDIUM, or LOW
  final String severity;

  /// Confidence ratio: matchedKeywords / totalTokens (0.0 to 1.0+)
  final double confidence;

  const EmergencyClassification({
    required this.type,
    required this.subCategory,
    required this.severity,
    required this.confidence,
  });

  @override
  String toString() =>
      'EmergencyClassification(type: $type, subCategory: $subCategory, '
      'severity: $severity, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
}
