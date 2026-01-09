/**
 * Profanity Filter Utility
 * Filters Turkish and English bad words and insults.
 * Comprehensive list for chat moderation.
 */

const BAD_WORDS_TR = [
    // Küfürler ve Hakaretler
    'amk', 'aq', 'sik', 'siktir', 'siktirlo', 'siktim', 'sikmek', 'sikerim', 'sikiş', 'yarrak', 'yarak',
    'oç', 'orospu', 'orospu çocuğu', 'kahpe', 'kahbe', 'kaltak', 'fahişe', 'sürtük', 'yosma', 'kaşar',
    'piç', 'yavşak', 'göt', 'götveren', 'götoş', 'götlek', 'göte', 'götü', 'poponu',
    'ibne', 'puşt', 'top', 'nonş', 'dönme', 'kulampara',
    'çük', 'daşşak', 'taşşak', 'penis', 'vajina', 'am', 'amcık', 'amcığı', 'meme', 'memeler',
    'sikik', 'sokuk', 'sokarım', 'sokmak', 'koyarım', 'koyim', 'koyayım',
    'ananı', 'ananın', 'bacını', 'bacının', 'avradını', 'sülaleni', 'soyunu',
    'zenci', 'keko', 'hırbo', 'lavuk', 'dalyarak', 'zibidi', 'zırto', 'hıyar', 'davar', 'öküz', 'ayı', 'mal', 'salak', 'gerizekalı', 'aptal', 'ahmak', 'beyinsiz', 'ezik', 'çomar',
    'porno', 'seks', 'hardcore', 'erotik', 'kucak', 'kucak dansı',
    'amına', 'amına koyim', 'amına koyayım', 'amina', 'aminakoyim', 'anaskm'
];

const BAD_WORDS_EN = [
    // Profanity & Insults
    'fuck', 'fucking', 'fucked', 'fucker', 'motherfucker', 'mf', 'fck',
    'shit', 'bullshit', 'shitty', 'shite', 'crap',
    'bitch', 'son of a bitch', 'whore', 'slut', 'skank', 'hoe', 'hooker', 'prostitute',
    'ass', 'asshole', 'arse', 'arsehole', 'butt', 'butthole', 'dumbass', 'jackass',
    'dick', 'cock', 'prick', 'knob', 'penis', 'dong', 'schlong',
    'pussy', 'cunt', 'twat', 'vagina', 'clit', 'fanny',
    'tits', 'boobs', 'breasts', 'nipples',
    'bastard', 'jerk', 'idiot', 'moron', 'retard', 'stupid', 'imbecile', 'loser',
    'nigger', 'nigga', 'faggot', 'fag', 'dyke', 'tranny', 'retarded', 'spastic',
    'damn', 'dammit', 'hell', 'crap', 'wanker', 'bollocks', 'bugger', 'bloody',
    'suck', 'sucks', 'sucker', 'blowjob', 'handjob', 'rimjob', 'anal', 'oral', 'porn', 'porno', 'sex', 'sexy'
];

const ALL_WORDS = [...BAD_WORDS_TR, ...BAD_WORDS_EN];

/**
 * Escapes special regex characters
 */
function escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Normalizes text by converting Turkish characters to their English counterparts
 * and converting to lowercase.
 * e.g., "Şerefsiz" -> "serefsiz", "ÇIĞLIK" -> "ciglik"
 */
function normalizeText(text) {
    return text
        .toLowerCase()
        .replace(/ğ/g, 'g')
        .replace(/ü/g, 'u')
        .replace(/ş/g, 's')
        .replace(/ı/g, 'i')
        .replace(/İ/g, 'i')
        .replace(/ö/g, 'o')
        .replace(/ç/g, 'c');
}

/**
 * Filters the input text by replacing bad words with asterisks.
 * Case insensitive.
 * 
 * @param {string} text - The input text
 * @returns {string} - The filtered text
 */
function filterProfanity(text) {
    if (!text) return text;

    let cleanText = text;

    // Create a single regex for all bad words for performance
    // \b ensures we match whole words mostly, but for some Turkish aggregations it might be tricky.
    // We sort by length descending to match longer phrases first (e.g. "orospu çocuğu" before "orospu")
    const sortedWords = ALL_WORDS.sort((a, b) => b.length - a.length);

    const pattern = new RegExp(`\\b(${sortedWords.map(escapeRegExp).join('|')})`, 'gi');

    cleanText = cleanText.replace(pattern, (match) => {
        return '*'.repeat(match.length);
    });

    return cleanText;
}

/**
 * Checks if the text contains any profanity.
 * 
 * @param {string} text 
 * @returns {boolean}
 */
function hasProfanity(text) {
    if (!text) return false;

    // Sort descending to catch compound insults
    const sortedWords = ALL_WORDS.sort((a, b) => b.length - a.length);
    const pattern = new RegExp(`\\b(${sortedWords.map(escapeRegExp).join('|')})`, 'gi');

    // Check raw text
    if (pattern.test(text)) return true;

    // Check normalized text
    const normalized = normalizeText(text);
    return pattern.test(normalized);
}

module.exports = {
    filterProfanity,
    hasProfanity
};
