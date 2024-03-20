//
//  File.swift
//  
//
//  Created by Warren Burton on 29/01/2024.
//

import Foundation
import SwiftSyntax

extension TriviaPiece {
    var isCommentLine: Bool {
        switch self {
        case .lineComment, .blockComment, .docLineComment, .docBlockComment:
            return true
        default:
            return false
        }
    }
}
