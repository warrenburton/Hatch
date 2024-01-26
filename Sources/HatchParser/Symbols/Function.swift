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
    public let parameters: [FunctionParameter]

    /// Whether the function is static or not
    public let isStatic: Bool

    /// Whether the function throws errors or not
    public let throwingStatus: ThrowingStatus

    /// The data type returned by the function
    public let returnType: String
    
    public var children: [Symbol]
    public var comments: [Comment]
    
    public var description: String {
        let displayParameters = parameters.map { $0.description }.joined(separator: ", ")
        return "\(isStatic ? "static ":"")func \(name)\(genericType)(\(displayParameters)) \(returnExpression)"
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

public struct FunctionParameter: Symbol {
    public var firstName: String
    public var secondName: String?
    public var type: String
    
    public var children: [Symbol]
    public var comments: [Comment]
    public var sourceRange: SwiftSyntax.SourceRange
    
    public var description: String {
        var name = firstName
        if let secondName {
            name += " " + secondName
        }
        name += ": " + type
        return name
    }
    
}


