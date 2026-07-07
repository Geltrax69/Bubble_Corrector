//
//  WordBufferService.swift
//  WordPop
//

import Foundation

class WordBufferService {
    private(set) var currentWord: String = ""
    
    func append(_ text: String) {
        currentWord += text
    }
    
    func backspace() {
        if !currentWord.isEmpty {
            currentWord.removeLast()
        }
    }
    
    func clear() {
        currentWord = ""
    }
    
    func isBoundary(_ text: String) -> Bool {
        let boundaryChars = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        return text.rangeOfCharacter(from: boundaryChars) != nil
    }
}
