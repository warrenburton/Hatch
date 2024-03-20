//
//  File.swift
//  
//
//  Created by Warren Burton on 14/05/2023.
//

import Foundation
import SwiftSyntax

/// a single comment line
public struct Comment {
    public enum CommentType: String {
        case regular
        case documentation
    }

    public var type: CommentType
    public var text: String
}
