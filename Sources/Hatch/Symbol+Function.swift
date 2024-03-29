//
//  Created by Warren Burton on 14/05/2023.
//

import Foundation
import SwiftSyntax

public struct Function: Symbol {
   
    /// The function name
    public let name: String

    /// The parameter names received by the function
    public let parameters: [FunctionParameter]

    /// Whether the function is static or not
    public var isStatic: Bool {
        modifiers.contains("static") || modifiers.contains("class")
    }

    /// Whether the function throws errors or not
    public let throwingStatus: ThrowingStatus

    /// The data type returned by the function
    public let returnType: String
    
    public var children: [Symbol]
    public var comments: [Comment]
    public var modifiers: [String]
    public var attributes: [String]
    public var isInitializer: Bool = false
    
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

public struct FunctionParameter: Symbol, Identifiable {
    public var id: String {
        description
    }
    
    public var firstName: String
    public var secondName: String?
    public var type: String
    public var initializerClause: String? = nil
    
    public var children: [Symbol]
    public var comments: [Comment]
    public var sourceRange: SwiftSyntax.SourceRange
    public var modifiers: [String] = []
    public var attributes: [String] = []
    
    public var resolvedName: String {
        return secondName ?? firstName
    }
    
    public var description: String {
        var name = firstName
        if let secondName {
            name += " " + secondName
        }
        name += ": " + type
        return name
    }
    
    public var defaultValue: String? {
        let cset = CharacterSet(charactersIn: " =")
        return initializerClause?.trimmingCharacters(in: cset)
    }
}


