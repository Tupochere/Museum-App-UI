import 'kokoro_vocabulary.dart';

/// Converts English text to Kokoro phoneme-ID sequences.
///
/// Uses a rule-based grapheme-to-phoneme (G2P) approach with a built-in
/// dictionary for common irregular words. Output uses **Misaki G2P symbols**
/// (the phoneme set Kokoro was trained on), which are mostly IPA but with
/// uppercase diphthong shortcuts (A=eɪ, I=aɪ, O=oʊ, W=aʊ, Y=ɔɪ) and
/// merged affricates (ʤ, ʧ).
class KokoroPhonemizer {
  /// Maximum phoneme tokens per inference chunk (Kokoro context = 512, minus
  /// 2 for start/end padding).
  static const int maxTokensPerChunk = 510;

  /// Convert [text] to a list of token-ID chunks ready for model input.
  ///
  /// Each chunk is padded with token 0 at start and end, and is at most
  /// [maxTokensPerChunk] + 2 tokens long.
  List<List<int>> tokenize(String text) {
    final normalized = _normalize(text);
    final sentences = _splitSentences(normalized);
    final chunks = <List<int>>[];
    var currentTokens = <int>[];

    for (final sentence in sentences) {
      final tokens = _sentenceToTokens(sentence);
      if (tokens.isEmpty) continue;

      if (currentTokens.isNotEmpty &&
          currentTokens.length + tokens.length > maxTokensPerChunk) {
        chunks.add(_padChunk(currentTokens));
        currentTokens = <int>[];
      }

      if (tokens.length > maxTokensPerChunk) {
        if (currentTokens.isNotEmpty) {
          chunks.add(_padChunk(currentTokens));
          currentTokens = <int>[];
        }
        chunks.addAll(_splitLongSentence(tokens));
      } else {
        currentTokens.addAll(tokens);
      }
    }

    if (currentTokens.isNotEmpty) {
      chunks.add(_padChunk(currentTokens));
    }

    return chunks;
  }

  // ── Normalization ──────────────────────────────────────────────────────────

  String _normalize(String text) {
    var result = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Expand common contractions.
    result = result
        .replaceAll("won't", 'will not')
        .replaceAll("Won't", 'will not')
        .replaceAll("can't", 'cannot')
        .replaceAll("Can't", 'Cannot')
        .replaceAll("n't", ' not')
        .replaceAll("'re", ' are')
        .replaceAll("'ve", ' have')
        .replaceAll("'ll", ' will')
        .replaceAll("'m", ' am')
        .replaceAll("'d", ' would');
    result = _expandNumbers(result);
    return result;
  }

  String _expandNumbers(String text) {
    return text.replaceAllMapped(RegExp(r'\b(\d+)\b'), (m) {
      final n = int.tryParse(m.group(1)!);
      if (n == null) return m.group(0)!;
      return _numberToWords(n);
    });
  }

  static const _ones = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
    'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
    'sixteen', 'seventeen', 'eighteen', 'nineteen',
  ];
  static const _tens = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
    'eighty', 'ninety',
  ];

  String _numberToWords(int n) {
    if (n < 0) return 'minus ${_numberToWords(-n)}';
    if (n < 20) return _ones[n];
    if (n < 100) {
      final remainder = n % 10;
      return '${_tens[n ~/ 10]}${remainder > 0 ? ' ${_ones[remainder]}' : ''}';
    }
    if (n < 1000) {
      final remainder = n % 100;
      return '${_ones[n ~/ 100]} hundred${remainder > 0 ? ' and ${_numberToWords(remainder)}' : ''}';
    }
    if (n < 1000000) {
      final thousands = n ~/ 1000;
      final remainder = n % 1000;
      return '${_numberToWords(thousands)} thousand${remainder > 0 ? ' ${_numberToWords(remainder)}' : ''}';
    }
    return n.toString();
  }

  // ── Sentence splitting ─────────────────────────────────────────────────────

  List<String> _splitSentences(String text) {
    final parts = text.split(RegExp(r'(?<=[.!?])\s+'));
    return parts.where((s) => s.trim().isNotEmpty).toList();
  }

  // ── G2P core ───────────────────────────────────────────────────────────────

  List<int> _sentenceToTokens(String sentence) {
    final tokens = <int>[];
    final words = sentence.split(RegExp(r'\s+'));

    for (var i = 0; i < words.length; i++) {
      final word = words[i].trim();
      if (word.isEmpty) continue;

      // Handle trailing punctuation.
      var core = word;
      String? trailingPunct;
      if (word.length > 1 && RegExp(r'[,.\-!?;:…]$').hasMatch(word)) {
        core = word.substring(0, word.length - 1);
        trailingPunct = word[word.length - 1];
      }

      if (core.isNotEmpty) {
        final phonemes = _wordToPhonemes(core.toLowerCase());
        tokens.addAll(_phonemesToIds(phonemes));
      }

      if (trailingPunct != null) {
        final punctId = KokoroVocabulary.symbolToId[trailingPunct];
        if (punctId != null) tokens.add(punctId);
      }

      // Inter-word space.
      if (i < words.length - 1) {
        final spaceId = KokoroVocabulary.symbolToId[' '];
        if (spaceId != null) tokens.add(spaceId);
      }
    }

    return tokens;
  }

  /// Convert a single word to a Misaki-format phoneme string.
  String _wordToPhonemes(String word) {
    final dictEntry = _dictionary[word];
    if (dictEntry != null) return dictEntry;
    return _rulesG2P(word);
  }

  /// Convert a Misaki phoneme string to Kokoro token IDs.
  ///
  /// Handles multi-character symbols by checking two-char matches first.
  List<int> _phonemesToIds(String phonemes) {
    final ids = <int>[];
    var i = 0;
    while (i < phonemes.length) {
      if (i + 1 < phonemes.length) {
        final digraph = phonemes.substring(i, i + 2);
        final id = KokoroVocabulary.symbolToId[digraph];
        if (id != null) {
          ids.add(id);
          i += 2;
          continue;
        }
      }
      final char = phonemes[i];
      final id = KokoroVocabulary.symbolToId[char];
      if (id != null) {
        ids.add(id);
      }
      i++;
    }
    return ids;
  }

  // ── Padding ────────────────────────────────────────────────────────────────

  List<int> _padChunk(List<int> tokens) {
    return [KokoroVocabulary.pad, ...tokens, KokoroVocabulary.pad];
  }

  List<List<int>> _splitLongSentence(List<int> tokens) {
    final chunks = <List<int>>[];
    for (var i = 0; i < tokens.length; i += maxTokensPerChunk) {
      final end = (i + maxTokensPerChunk < tokens.length)
          ? i + maxTokensPerChunk
          : tokens.length;
      chunks.add(_padChunk(tokens.sublist(i, end)));
    }
    return chunks;
  }

  // ── Rule-based G2P ─────────────────────────────────────────────────────────
  //
  // Produces Misaki-format phonemes:
  //   Diphthongs: A (eɪ), I (aɪ), O (oʊ), W (aʊ), Y (ɔɪ)
  //   Affricates: ʧ (ch), ʤ (dg/j)
  //   Consonants: standard IPA (ɹ, ŋ, θ, ð, ʃ, ʒ, etc.)

  String _rulesG2P(String word) {
    var remaining = word;
    final buffer = StringBuffer();

    while (remaining.isNotEmpty) {
      var matched = false;
      for (final rule in _g2pRules) {
        if (remaining.startsWith(rule.grapheme)) {
          buffer.write(rule.phoneme);
          remaining = remaining.substring(rule.grapheme.length);
          matched = true;
          break;
        }
      }
      if (!matched) {
        remaining = remaining.substring(1);
      }
    }

    return buffer.toString();
  }

  // ── G2P rule table (longest-match-first) ───────────────────────────────────
  // Output uses Misaki symbols: A I O W Y for diphthongs, ʧ ʤ for affricates.

  static const List<_G2PRule> _g2pRules = [
    // Multi-character patterns.
    const _G2PRule('tion', 'ʃən'),
    const _G2PRule('sion', 'ʒən'),
    const _G2PRule('cious', 'ʃəs'),
    const _G2PRule('tious', 'ʃəs'),
    const _G2PRule('ture', 'ʧɚ'),
    const _G2PRule('ight', 'It'),
    const _G2PRule('ious', 'iəs'),
    const _G2PRule('eous', 'iəs'),
    const _G2PRule('ould', 'ʊd'),
    const _G2PRule('ound', 'Wnd'),
    const _G2PRule('ouse', 'Ws'),
    const _G2PRule('ment', 'mənt'),
    const _G2PRule('ness', 'nəs'),
    const _G2PRule('able', 'Abəl'),
    const _G2PRule('ible', 'ɪbəl'),
    const _G2PRule('ling', 'lɪŋ'),
    const _G2PRule('ting', 'tɪŋ'),
    const _G2PRule('ning', 'nɪŋ'),
    const _G2PRule('king', 'kɪŋ'),
    const _G2PRule('ring', 'ɹɪŋ'),
    const _G2PRule('sing', 'sɪŋ'),
    const _G2PRule('ing', 'ɪŋ'),
    const _G2PRule('tch', 'ʧ'),
    const _G2PRule('dge', 'ʤ'),
    const _G2PRule('sch', 'sk'),
    const _G2PRule('chr', 'kɹ'),
    const _G2PRule('chl', 'kl'),
    const _G2PRule('kn', 'n'),
    const _G2PRule('wr', 'ɹ'),
    const _G2PRule('wh', 'w'),
    const _G2PRule('gh', ''),
    const _G2PRule('ph', 'f'),
    const _G2PRule('th', 'θ'),
    const _G2PRule('sh', 'ʃ'),
    const _G2PRule('ch', 'ʧ'),
    const _G2PRule('ng', 'ŋ'),
    const _G2PRule('nk', 'ŋk'),
    const _G2PRule('qu', 'kw'),
    const _G2PRule('ck', 'k'),
    const _G2PRule('ai', 'A'),
    const _G2PRule('ay', 'A'),
    const _G2PRule('ea', 'iː'),
    const _G2PRule('ee', 'iː'),
    const _G2PRule('ei', 'iː'),
    const _G2PRule('ey', 'iː'),
    const _G2PRule('ie', 'iː'),
    const _G2PRule('oa', 'O'),
    const _G2PRule('oe', 'O'),
    const _G2PRule('oo', 'uː'),
    const _G2PRule('ou', 'W'),
    const _G2PRule('ow', 'W'),
    const _G2PRule('oi', 'Y'),
    const _G2PRule('oy', 'Y'),
    const _G2PRule('au', 'ɔː'),
    const _G2PRule('aw', 'ɔː'),
    const _G2PRule('ew', 'juː'),
    const _G2PRule('er', 'ɚ'),
    const _G2PRule('ir', 'ɜɹ'),
    const _G2PRule('ur', 'ɜɹ'),
    const _G2PRule('or', 'ɔɹ'),
    const _G2PRule('ar', 'ɑɹ'),
    // Single-character mappings.
    const _G2PRule('a', 'æ'),
    const _G2PRule('b', 'b'),
    const _G2PRule('c', 'k'),
    const _G2PRule('d', 'd'),
    const _G2PRule('e', 'ɛ'),
    const _G2PRule('f', 'f'),
    const _G2PRule('g', 'ɡ'),
    const _G2PRule('h', 'h'),
    const _G2PRule('i', 'ɪ'),
    const _G2PRule('j', 'ʤ'),
    const _G2PRule('k', 'k'),
    const _G2PRule('l', 'l'),
    const _G2PRule('m', 'm'),
    const _G2PRule('n', 'n'),
    const _G2PRule('o', 'ɑ'),
    const _G2PRule('p', 'p'),
    const _G2PRule('r', 'ɹ'),
    const _G2PRule('s', 's'),
    const _G2PRule('t', 't'),
    const _G2PRule('u', 'ʌ'),
    const _G2PRule('v', 'v'),
    const _G2PRule('w', 'w'),
    const _G2PRule('x', 'ks'),
    const _G2PRule('y', 'j'),
    const _G2PRule('z', 'z'),
  ];

  // ── Common word dictionary ─────────────────────────────────────────────────
  // Uses Misaki-format phonemes: A=eɪ, I=aɪ, O=oʊ, W=aʊ, Y=ɔɪ, ʧ=ch, ʤ=dg

  static const Map<String, String> _dictionary = {
    // Articles & pronouns
    'the': 'ðə',
    'a': 'ə',
    'an': 'ən',
    'i': 'I',
    'you': 'juː',
    'he': 'hiː',
    'she': 'ʃiː',
    'it': 'ɪt',
    'we': 'wiː',
    'they': 'ðA',
    'me': 'miː',
    'him': 'hɪm',
    'her': 'hɜɹ',
    'us': 'ʌs',
    'them': 'ðɛm',
    'my': 'mI',
    'your': 'jɔɹ',
    'his': 'hɪz',
    'our': 'Wɚ',
    'their': 'ðɛɹ',
    'its': 'ɪts',
    'this': 'ðɪs',
    'that': 'ðæt',
    'these': 'ðiːz',
    'those': 'ðOz',
    // Common verbs
    'is': 'ɪz',
    'are': 'ɑɹ',
    'was': 'wɑz',
    'were': 'wɜɹ',
    'be': 'biː',
    'been': 'bɪn',
    'being': 'biːɪŋ',
    'have': 'hæv',
    'has': 'hæz',
    'had': 'hæd',
    'do': 'duː',
    'does': 'dʌz',
    'did': 'dɪd',
    'will': 'wɪl',
    'would': 'wʊd',
    'could': 'kʊd',
    'should': 'ʃʊd',
    'may': 'mA',
    'might': 'mIt',
    'shall': 'ʃæl',
    'can': 'kæn',
    'go': 'ɡO',
    'going': 'ɡOɪŋ',
    'gone': 'ɡɑn',
    'come': 'kʌm',
    'came': 'kAm',
    'give': 'ɡɪv',
    'gave': 'ɡAv',
    'given': 'ɡɪvən',
    'take': 'tAk',
    'took': 'tʊk',
    'taken': 'tAkən',
    'make': 'mAk',
    'made': 'mAd',
    'know': 'nO',
    'knew': 'njuː',
    'known': 'nOn',
    'think': 'θɪŋk',
    'thought': 'θɔːt',
    'see': 'siː',
    'saw': 'sɔː',
    'seen': 'siːn',
    'say': 'sA',
    'said': 'sɛd',
    'get': 'ɡɛt',
    'got': 'ɡɑt',
    'use': 'juːz',
    'used': 'juːzd',
    'find': 'fInd',
    'found': 'fWnd',
    'put': 'pʊt',
    'work': 'wɜɹk',
    'call': 'kɔːl',
    'called': 'kɔːld',
    'live': 'lɪv',
    'look': 'lʊk',
    'want': 'wɑnt',
    // Prepositions, conjunctions, adverbs
    'of': 'ʌv',
    'to': 'tuː',
    'in': 'ɪn',
    'for': 'fɔɹ',
    'on': 'ɑn',
    'with': 'wɪð',
    'at': 'æt',
    'by': 'bI',
    'from': 'fɹʌm',
    'as': 'æz',
    'into': 'ɪntuː',
    'about': 'əbWt',
    'through': 'θɹuː',
    'after': 'æftɚ',
    'over': 'Ovɚ',
    'between': 'bɪtwiːn',
    'under': 'ʌndɚ',
    'before': 'bɪfɔɹ',
    'during': 'djʊɹɪŋ',
    'without': 'wɪðWt',
    'again': 'əɡɛn',
    'and': 'ænd',
    'but': 'bʌt',
    'or': 'ɔɹ',
    'not': 'nɑt',
    'no': 'nO',
    'yes': 'jɛs',
    'so': 'sO',
    'if': 'ɪf',
    'when': 'wɛn',
    'where': 'wɛɹ',
    'what': 'wɑt',
    'which': 'wɪʧ',
    'who': 'huː',
    'how': 'hW',
    'why': 'wI',
    'very': 'vɛɹiː',
    'also': 'ɔːlsO',
    'just': 'ʤʌst',
    'than': 'ðæn',
    'then': 'ðɛn',
    'now': 'nW',
    'here': 'hɪɹ',
    'there': 'ðɛɹ',
    'only': 'Onliː',
    'still': 'stɪl',
    'even': 'iːvən',
    'well': 'wɛl',
    // Common nouns
    'time': 'tIm',
    'year': 'jɪɹ',
    'people': 'piːpəl',
    'way': 'wA',
    'day': 'dA',
    'world': 'wɜɹld',
    'life': 'lIf',
    'hand': 'hænd',
    'place': 'plAs',
    'case': 'kAs',
    'week': 'wiːk',
    'point': 'pYnt',
    'house': 'hWs',
    'water': 'wɔːtɚ',
    'room': 'ɹuːm',
    'mother': 'mʌðɚ',
    'area': 'ɛɹiːə',
    'money': 'mʌniː',
    'story': 'stɔɹiː',
    'young': 'jʌŋ',
    // Common adjectives
    'other': 'ʌðɚ',
    'new': 'njuː',
    'good': 'ɡʊd',
    'old': 'Old',
    'great': 'ɡɹAt',
    'high': 'hI',
    'small': 'smɔːl',
    'large': 'lɑɹʤ',
    'long': 'lɔːŋ',
    'little': 'lɪtəl',
    'own': 'On',
    'right': 'ɹIt',
    'big': 'bɪɡ',
    'sure': 'ʃʊɹ',
    'whole': 'hOl',
    'true': 'tɹuː',
    'one': 'wʌn',
    'two': 'tuː',
    'three': 'θɹiː',
    'four': 'fɔɹ',
    'five': 'fIv',
    'eight': 'At',
    // Museum-specific words
    'museum': 'mjuːziːəm',
    'exhibit': 'ɪɡzɪbɪt',
    'exhibition': 'ɛksɪbɪʃən',
    'artifact': 'ɑɹtɪfækt',
    'gallery': 'ɡæləɹiː',
    'sculpture': 'skʌlpʧɚ',
    'painting': 'pAntɪŋ',
    'ancient': 'Anʃənt',
    'century': 'sɛnʧɚiː',
    'history': 'hɪstəɹiː',
    'historical': 'hɪstɔɹɪkəl',
    'culture': 'kʌlʧɚ',
    'cultural': 'kʌlʧɚəl',
    'heritage': 'hɛɹɪtɪʤ',
    'collection': 'kəlɛkʃən',
    'display': 'dɪsplA',
    'ceramic': 'səɹæmɪk',
    'pottery': 'pɑtɚiː',
    'bronze': 'bɹɑnz',
    'marble': 'mɑɹbəl',
    'stone': 'stOn',
    'iron': 'Iɚn',
    'gold': 'ɡOld',
    'silver': 'sɪlvɚ',
    'ivory': 'Ivɚiː',
    'textile': 'tɛkstIl',
    'mosaic': 'mOzAɪk',
    'fresco': 'fɹɛskO',
    'portrait': 'pɔɹtɹɪt',
    'statue': 'stæʧuː',
    'temple': 'tɛmpəl',
    'tomb': 'tuːm',
    'dynasty': 'dInəstiː',
    'civilization': 'sɪvɪlɪzAʃən',
    'archaeology': 'ɑɹkiːɑləʤiː',
    'archaeological': 'ɑɹkiːəlɑʤɪkəl',
    'restoration': 'ɹɛstəɹAʃən',
    'preservation': 'pɹɛzɚvAʃən',
    'masterpiece': 'mæstɚpiːs',
    'technique': 'tɛkniːk',
    'period': 'pɪɹiːəd',
    'era': 'ɛɹə',
    'design': 'dɪzIn',
    'symbol': 'sɪmbəl',
    'symbolic': 'sɪmbɑlɪk',
    'traditional': 'tɹədɪʃənəl',
    'beautiful': 'bjuːtɪfəl',
    'unique': 'juːniːk',
    'significant': 'sɪɡnɪfɪkənt',
    'remarkable': 'ɹɪmɑɹkəbəl',
    'elaborate': 'ɪlæbɚɪt',
    'intricate': 'ɪntɹɪkɪt',
    'magnificent': 'mæɡnɪfɪsənt',
    'precious': 'pɹɛʃəs',
    'sacred': 'sAkɹɪd',
    'ritual': 'ɹɪʧuːəl',
    'royal': 'ɹYəl',
    'medieval': 'mɛdiːiːvəl',
    'renaissance': 'ɹɛnəsɑns',
    'baroque': 'bəɹOk',
    'indigenous': 'ɪndɪʤənəs',
    // Words commonly mispronounced by rules
    'some': 'sʌm',
    'done': 'dʌn',
    'none': 'nʌn',
    'once': 'wʌns',
    'move': 'muːv',
    'love': 'lʌv',
    'above': 'əbʌv',
    'women': 'wɪmɪn',
    'woman': 'wʊmən',
    'eye': 'I',
    'eyes': 'Iz',
    'enough': 'ɪnʌf',
    'though': 'ðO',
    'laugh': 'læf',
    'cough': 'kɔːf',
    'rough': 'ɹʌf',
    'tough': 'tʌf',
    'colonel': 'kɜɹnəl',
    'island': 'Ilənd',
    'knife': 'nIf',
    'knight': 'nIt',
    'write': 'ɹIt',
    'wrong': 'ɹɔːŋ',
    'scene': 'siːn',
    'science': 'sIəns',
    'because': 'bɪkɔːz',
    'every': 'ɛvɹiː',
    'different': 'dɪfɹənt',
    'important': 'ɪmpɔɹtənt',
    'another': 'ənʌðɚ',
    'something': 'sʌmθɪŋ',
    'everything': 'ɛvɹiːθɪŋ',
    'nothing': 'nʌθɪŋ',
    'welcome': 'wɛlkʌm',
  };
}

class _G2PRule {
  const _G2PRule(this.grapheme, this.phoneme);
  final String grapheme;
  final String phoneme;
}
