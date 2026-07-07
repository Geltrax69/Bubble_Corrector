//
//  SpellCheckerService.swift
//  WordPop
//

import Cocoa

final class SpellCheckerService {
    static let shared = SpellCheckerService()
    private let checker = NSSpellChecker.shared
    
    func check(word: String) -> [String]? {
        guard !word.isEmpty else { return nil }
        let range = NSRange(location: 0, length: word.utf16.count)
        let misspellings = checker.check(word, range: range, types: NSTextCheckingResult.CheckingType.spelling.rawValue, options: nil, inSpellDocumentWithTag: 0, orthography: nil, wordCount: nil)
        
        if let misspelling = misspellings.first, misspelling.range.location != NSNotFound {
            return checker.guesses(forWordRange: misspelling.range, in: word, language: checker.language(), inSpellDocumentWithTag: 0)
        }
        return nil
    }
}
