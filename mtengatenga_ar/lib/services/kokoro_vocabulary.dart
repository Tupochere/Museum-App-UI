/// Kokoro-82M phoneme vocabulary.
///
/// Maps symbols to integer token IDs expected by the Kokoro ONNX model.
/// Extracted from the official `config.json` at
/// <https://huggingface.co/hexgrad/Kokoro-82M/blob/main/config.json>.
///
/// Token 0 = padding, used at the start and end of sequences.
/// These are **Misaki G2P output symbols**, not raw IPA.
class KokoroVocabulary {
  KokoroVocabulary._();

  /// Padding / silence token.
  static const int pad = 0;

  /// The full symbol-to-ID map from Kokoro config.json.
  static const Map<String, int> symbolToId = {
    // ── Punctuation ───────────────────────────────────────────────────────
    ';': 1,
    ':': 2,
    ',': 3,
    '.': 4,
    '!': 5,
    '?': 6,
    '—': 9,
    '…': 10,
    '"': 11,
    '(': 12,
    ')': 13,
    '\u201C': 14,  // left double quotation mark "
    '\u201D': 15,  // right double quotation mark "
    // ── Whitespace ────────────────────────────────────────────────────────
    ' ': 16,
    // ── Diacritics / special ──────────────────────────────────────────────
    '\u0303': 17,  // combining tilde
    'ʣ': 18,
    'ʥ': 19,
    'ʦ': 20,
    'ʨ': 21,
    'ᵝ': 22,
    '\uAB67': 23,  // latin small letter ts digraph
    // ── Uppercase vowel markers ───────────────────────────────────────────
    'A': 24,
    'I': 25,
    'O': 31,
    'Q': 33,
    'S': 35,
    'T': 36,
    'W': 39,
    'Y': 41,
    // ── Miscellaneous ─────────────────────────────────────────────────────
    'ᵊ': 42,
    // ── Lowercase letters / IPA ───────────────────────────────────────────
    'a': 43,
    'b': 44,
    'c': 45,
    'd': 46,
    'e': 47,
    'f': 48,
    'h': 50,
    'i': 51,
    'j': 52,
    'k': 53,
    'l': 54,
    'm': 55,
    'n': 56,
    'o': 57,
    'p': 58,
    'q': 59,
    'r': 60,
    's': 61,
    't': 62,
    'u': 63,
    'v': 64,
    'w': 65,
    'x': 66,
    'y': 67,
    'z': 68,
    // ── IPA vowels ────────────────────────────────────────────────────────
    'ɑ': 69,
    'ɐ': 70,
    'ɒ': 71,
    'æ': 72,
    'β': 75,
    'ɔ': 76,
    'ɕ': 77,
    'ç': 78,
    'ɖ': 80,
    'ð': 81,
    'ʤ': 82,
    'ə': 83,
    'ɚ': 85,
    'ɛ': 86,
    'ɜ': 87,
    'ɟ': 90,
    'ɡ': 92,
    'ɥ': 99,
    'ɨ': 101,
    'ɪ': 102,
    'ʝ': 103,
    'ɯ': 110,
    'ɰ': 111,
    'ŋ': 112,
    'ɳ': 113,
    'ɲ': 114,
    'ɴ': 115,
    'ø': 116,
    'ɸ': 118,
    'θ': 119,
    'œ': 120,
    'ɹ': 123,
    'ɾ': 125,
    'ɻ': 126,
    'ʁ': 128,
    'ɽ': 129,
    'ʂ': 130,
    'ʃ': 131,
    'ʈ': 132,
    'ʧ': 133,
    'ʊ': 135,
    'ʋ': 136,
    'ʌ': 138,
    'ɣ': 139,
    'ɤ': 140,
    'χ': 142,
    'ʎ': 143,
    'ʒ': 147,
    'ʔ': 148,
    // ── Suprasegmentals ───────────────────────────────────────────────────
    'ˈ': 156,
    'ˌ': 157,
    'ː': 158,
    // ── Aspiration / palatalization ────────────────────────────────────────
    'ʰ': 162,
    'ʲ': 164,
    // ── Intonation markers ────────────────────────────────────────────────
    '↓': 169,
    '→': 171,
    '↗': 172,
    '↘': 173,
    // ── Other ─────────────────────────────────────────────────────────────
    'ᵻ': 177,
  };

  /// Reverse lookup: ID → symbol.
  static final Map<int, String> idToSymbol = {
    for (final entry in symbolToId.entries) entry.value: entry.key,
    0: '<pad>',
  };
}
