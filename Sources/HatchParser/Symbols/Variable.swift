import SwiftSyntax

public struct Variable: Symbol {
    
    public enum LetOrVar: String, Codable {
        case `let`
        case `var`
    }
    
    public let name: String
    public let children: [Symbol]
    public let comments: [Comment]
    
    public let isStatic: Bool
    
    /// Is let or var
    public let letOrVar: LetOrVar

    /// The type of the variable
    public let typeAnnotation: String?

    /// The identifier from the init if available
    public var identifierExpression: String?

    /// The syntax that initializes the var
    public let initializer: String?
    
    public var description: String {
        let annotatedType = (typeAnnotation?.nilIfEmpty() == nil) ? "" : ": \(typeAnnotation ?? "")"
        
        let xinitializer: String
        if let initializer, !initializer.isEmpty {
            xinitializer = "= \(initializer)"
        } else {
            xinitializer = ""
        }
        
        let expression = identifierExpression ?? xinitializer
        
        return "\(isStatic ? "static":"") \(letOrVar.rawValue ) \(name)\(annotatedType)\(expression)"
    }
    
    public var sourceRange: SourceRange
}

extension String {
    func nilIfEmpty() -> String? {
        if count == 0 { return nil }
        return self
    }
}
