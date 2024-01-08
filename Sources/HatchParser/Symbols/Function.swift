//
//  File.swift
//  
//
//  Created by Warren Burton on 14/05/2023.
//

import Foundation
import SwiftSyntax

public struct Function: Symbol {
    /// Stores whether the function is throwing or not
    public enum ThrowingStatus: String {
        case none, `throws`, `rethrows`, unknown
    }
    
    /// The function name
    public let name: String

    /// The parameter names received by the function
    public let parameters: [String]

    /// Whether the function is static or not
    public let isStatic: Bool

    /// Whether the function throws errors or not
    public let throwingStatus: ThrowingStatus

    /// The data type returned by the function
    public let returnType: String
    
    public var children: [Symbol]
    public var comments: [Comment]
    
    public var description: String {
        
        return "\(isStatic ? "static ":"")func \(name)\(genericType)(\(parameters.joined(separator: ""))) \(returnExpression)"
    }
    
    public var sourceRange: SourceRange
    
}

extension Function {
    var genericType: String {
        let generics = children
            .map({ $0 as? Generic })
            .compactMap({ $0?.name })
            .joined(separator: ", ")
        
        guard !generics.isEmpty else {
            return ""
        }
        return "<\(generics)>"
    }
    
    var returnExpression: String {
        guard !returnType.isEmpty, returnType != "Void" else {
            return ""
        }
        
        return "-> \(returnType)"
    }
}
