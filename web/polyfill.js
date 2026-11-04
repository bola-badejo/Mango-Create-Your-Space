// Polyfill for Intl.Segmenter to fix deprecation warnings
if (typeof Intl.Segmenter === 'undefined') {
  console.log('Intl.Segmenter not available, providing minimal polyfill');
  
  Intl.Segmenter = class Segmenter {
    constructor(locales, options) {
      this.locales = locales;
      this.options = options;
    }
    
    segment(text) {
      return {
        *[Symbol.iterator]() {
          // Simple implementation - split by spaces for basic functionality
          const words = text.split(/\s+/);
          for (let i = 0; i < words.length; i++) {
            const word = words[i];
            if (word) {
              yield {
                segment: word,
                index: text.indexOf(word, i > 0 ? text.indexOf(words[i-1]) + words[i-1].length : 0),
                input: text,
                isWordLike: true
              };
            }
          }
        },
        containing(index) {
          // Simple implementation
          const words = text.split(/\s+/);
          let currentIndex = 0;
          for (const word of words) {
            const wordStart = text.indexOf(word, currentIndex);
            const wordEnd = wordStart + word.length;
            if (index >= wordStart && index < wordEnd) {
              return {
                segment: word,
                index: wordStart,
                input: text,
                isWordLike: true
              };
            }
            currentIndex = wordEnd;
          }
          return null;
        }
      };
    }
  };
  
  // Also fix v8BreakIterator warning
  if (Intl.v8BreakIterator) {
    // Keep it but don't use it
    console.log('v8BreakIterator available but deprecated');
  }
}