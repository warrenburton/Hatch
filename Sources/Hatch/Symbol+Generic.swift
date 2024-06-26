//
//  File.swift
//  
//
//  Created by Warren Burton on 15/05/2023.
//

import Foundation
import SwiftSyntax

public struct Generic: Symbol {
    
    public var name: String
    
    public var children: [Symbol]
    public var comments: [Comment]
    public let modifiers: [String] = []
    public var attributes: [String] = []
    
    public var sourceRange: SourceRange
}
