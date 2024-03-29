import SwiftSyntax
import SwiftParser

/// A SyntaxVistor subclass that parses swift code into a hierarchical list of symbols
open class SymbolParser: SyntaxVisitor {
    
    // MARK: - Private
    
    private var scope: Scope = .root(symbols: [])
    private var sourceLocationConverter: SourceLocationConverter!
    
    // MARK: - Public
    
    /// Parses `source` and returns a hierarchical list of symbols from a string
    static public func parse(fileName: String, source: String) -> [Symbol] {
        let visitor = Self()
        visitor.sourceLocationConverter = SourceLocationConverter(file: fileName, source: source)
        visitor.walk(Parser.parse(source: source))
        return visitor.scope.symbols
    }
    
    /// Designated initializer
    required public init() {
        super.init(viewMode: .sourceAccurate)
    }
    
    /// Starts a new scope which can contain zero or more nested symbols
    public func startScope() -> SyntaxVisitorContinueKind {
        scope.start()
        return .visitChildren
    }
    
    /// Ends the current scope and adds the symbol returned by the closure to the symbol tree
    /// - Parameter makeSymbolWithChildrenInScope: Closure that return a new ``Symbol``
    ///
    /// Call in `visitPost(_ node:)` methods
    public func endScopeAndAddSymbol(makeSymbolWithChildrenInScope: (_ children: [Symbol]) -> Symbol) {
        scope.end(makeSymbolWithChildrenInScope: makeSymbolWithChildrenInScope)
    }
    
    // MARK: - SwiftSyntax overridden methods
    
    open override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }
    
    open override func visitPost(_ node: ClassDeclSyntax) {
        
        endScopeAndAddSymbol { children in
            Class(
                name: node.name.text,
                children: children,
                inheritedTypes: node.inheritanceClause?.types ?? [],
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter),
                modifiers: node.modifiers.map({ $0.name.text }),
                attributes: node.attributes.map({ $0.trimmedDescription })
            )
        }
    }
    
    open override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }
    
    open override func visitPost(_ node: ProtocolDeclSyntax) {
        
        endScopeAndAddSymbol { children in
            Protocol(
                name: node.name.text,
                children: children,
                inheritedTypes: node.inheritanceClause?.types ?? [],
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter),
                modifiers: node.modifiers.map({ $0.name.text }),
                attributes: node.attributes.map({ $0.trimmedDescription })
            )
        }
    }
    
    open override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }
    
    open override func visitPost(_ node: StructDeclSyntax) {
        
        endScopeAndAddSymbol { children in
            Struct(
                name: node.name.text,
                children: children,
                inheritedTypes: node.inheritanceClause?.types ?? [],
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter),
                modifiers: node.modifiers.map({ $0.name.text }),
                attributes: node.attributes.map({ $0.trimmedDescription })
            )
        }
    }
    
    open override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }
    
    open override func visitPost(_ node: EnumDeclSyntax) {
        
        endScopeAndAddSymbol { children in
            Enum(
                name: node.name.text,
                children: children,
                inheritedTypes: node.inheritanceClause?.types ?? [],
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter),
                modifiers: node.modifiers.map({ $0.name.text }),
                attributes: node.attributes.map({ $0.trimmedDescription })
            )
        }
    }
    
    open override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }
    
    open override func visitPost(_ node: EnumCaseDeclSyntax) {
        
        endScopeAndAddSymbol { children in
            EnumCase(
                caseDeclarations: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter),
                modifiers: node.modifiers.map({ $0.name.text }),
                attributes: node.attributes.map({ $0.trimmedDescription })
            )
        }
    }
    
    open override func visit(_ node: EnumCaseElementSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }
    
    open override func visitPost(_ node: EnumCaseElementSyntax) {
        
        endScopeAndAddSymbol { children in
            EnumCaseElement(
                name: node.name.text,
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
        }
    }
    
    open override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }
    
    open override func visitPost(_ node: TypeAliasDeclSyntax) {
        
        endScopeAndAddSymbol { children in
            Typealias(
                name: node.name.text,
                existingType: node.initializer.value.description,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter),
                modifiers: node.modifiers.map({ $0.name.text })
            )
        }
    }
    
    open override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }
    
    open override func visitPost(_ node: ExtensionDeclSyntax) {
        
        endScopeAndAddSymbol { children in
            Extension(
                name: node.extendedType.description,
                children: children,
                inheritedTypes: node.inheritanceClause?.types ?? [],
                comments: [],
                sourceRange: node.sourceRange(converter: sourceLocationConverter),
                modifiers: node.modifiers.map({ $0.name.text }),
                attributes: node.attributes.map({ $0.trimmedDescription })
            )
        }
    }
    
    open override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        return startScope()
    }
    
    open override func visitPost(_ node: VariableDeclSyntax) {
        
        let letOrVar: Hatch.Variable.LetOrVar
        switch node.bindingSpecifier.text {
        case "let":
            letOrVar =  .let
        case "var":
            letOrVar = .var
        default:
            letOrVar = .let
        }
        
        
        if let binding = node.bindings.first {
            
            let trimmedType = binding.typeAnnotation?.type.trimmed.description
            print("&& \(node.attributes.map({ $0.trimmedDescription }))")
            endScopeAndAddSymbol { children in
                let newObject = Variable(
                    name: binding.pattern.description,
                    children: children,
                    comments: comments(node.leadingTrivia),
                    modifiers: node.modifiers.map({ $0.name.text }),
                    attributes: node.attributes.map({ $0.trimmedDescription }),
                    letOrVar: letOrVar,
                    typeAnnotation: trimmedType,
                    identifierExpression: nil,
                    initializer: binding.initializer?.value.description,
                    sourceRange: node.sourceRange(converter: sourceLocationConverter)
                )
                return newObject
            }
        } else {
            super.visitPost(node)
        }
    }
    
    /// Reads all leading trivia for a node, discards everything that isn't a comment, then
    /// sends back an array of what's left.
    func comments(_ trivia: Trivia?) -> [Comment] {
        guard let trivia else {
            return []
        }
        
        var target: [Comment] = []
        
        // walk backwards till first empty line break
        for piece in trivia.reversed() {
            if case let .newlines(count) = piece, count > 1 {
                break
            }
            target.append(contentsOf: extractComments(from: piece).reversed())
        }
        
        return target.reversed()
    }
    
    /// Converts trivia to comments
    func extractComments(from trivia: TriviaPiece) -> [Comment] {
        switch trivia {
        case .lineComment(let text), .blockComment(let text):
            let lines = text.components(separatedBy: "\n")
            return lines.map({ Comment(type: .regular, text: $0) })
        case .docLineComment(let text), .docBlockComment(let text):
            let lines = text.components(separatedBy: "\n")
            return lines.map({ Comment(type: .documentation, text: $0) })
        default:
            return []
        }
    }
    
    
    
    open override func visit(_ node: GenericParameterSyntax) -> SyntaxVisitorContinueKind{
        return startScope()
    }
    
    open override func visitPost(_ node: GenericParameterSyntax) {
        let name = node.description
        
        
        endScopeAndAddSymbol { children in
            let newObject = Generic(
                name: name,
                children: children,
                comments: [],
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            
            return newObject
        }
    }
    
    /// Triggered on entering a function
    open override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        return startScope()
    }
    
    /// Triggered on exiting a function; moves back up the tree
    open override func visitPost(_ node: FunctionDeclSyntax) {
        var throwingStatus = ThrowingStatus.unknown
        var returnType = ""
        
        // Copy in the throwing status
        if let throwsKeyword = node.signature.effectSpecifiers?.throwsSpecifier {
            if let throwsOrRethrows = ThrowingStatus(rawValue: throwsKeyword.description) {
                //print("&& imma let you throw")
                throwingStatus = throwsOrRethrows
            }
        } else {
            throwingStatus = .none
        }
        
        
        let name = node.name.text
        
        // Flatten the list of parameters for easier storage
        let parameters = node.signature.parameterClause.parameters
            .compactMap { child in
                FunctionParameter(
                    firstName: child.firstName.text,
                    secondName: child.secondName?.text,
                    type: child.type.description,
                    initializerClause: child.defaultValue?.trimmedDescription,
                    children: [],
                    comments: comments(node.leadingTrivia),
                    sourceRange: node.sourceRange(converter: sourceLocationConverter)
                )
                
            }
                
        // If we have a return type, copy it here
        if let nodeReturnType = node.signature.returnClause?.type {
            returnType = "\(nodeReturnType)"
        }
        
        endScopeAndAddSymbol { children in
            let newObject = Function(
                name: name,
                parameters: parameters,
                throwingStatus: throwingStatus,
                returnType: returnType,
                children: children,
                comments: comments(node.leadingTrivia),
                modifiers: node.modifiers.map({ $0.name.text }),
                attributes: node.attributes.map({ $0.trimmedDescription }),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: FunctionParameterSyntax) {
        
        endScopeAndAddSymbol { children in
            let newObject = FunctionParameter(
                firstName: node.firstName.text,
                secondName: node.secondName?.text,
                type: node.type.description,
                initializerClause: node.defaultValue?.trimmedDescription,
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
        
    }
    
    /// Visiting ``InitializerDeclSyntax`` specifically.
    open override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }
    
    /// The function called after visiting ``InitializerDeclSyntax`` and its descendants.
    open override func visitPost(_ node: InitializerDeclSyntax) {
        var throwingStatus = ThrowingStatus.unknown
        var returnType = ""
        
        // Copy in the throwing status
        if let throwsKeyword = node.signature.effectSpecifiers?.throwsSpecifier {
            if let throwsOrRethrows = ThrowingStatus(rawValue: throwsKeyword.description) {
                throwingStatus = throwsOrRethrows
            }
        } else {
            throwingStatus = .none
        }
        
        
        // Flatten the list of parameters for easier storage
        let parameters = node.signature.parameterClause.parameters
            .compactMap { child in
                                
                return FunctionParameter(
                    firstName: child.firstName.text,
                    secondName: child.secondName?.text,
                    type: child.type.description,
                    initializerClause: child.defaultValue?.trimmedDescription,
                    children: [],
                    comments: comments(node.leadingTrivia),
                    sourceRange: node.sourceRange(converter: sourceLocationConverter)
                )
                
            }
                
        // If we have a return type, copy it here
        if let nodeReturnType = node.signature.returnClause?.type {
            returnType = "\(nodeReturnType)"
        }
        
        endScopeAndAddSymbol { children in
            let newObject = Function(
                name: "init",
                parameters: parameters,
                throwingStatus: throwingStatus,
                returnType: returnType,
                children: children,
                comments: comments(node.leadingTrivia),
                modifiers: node.modifiers.map({ $0.name.text }),
                attributes: node.attributes.map({ $0.trimmedDescription }),
                isInitializer: true,
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    
    open override func visit(_ node: InitializerClauseSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }
    
    open override func visitPost(_ node: InitializerClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newobject = InitClause(
                name: node.trimmedDescription,
                children: children,
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newobject
        }
    }

}

public extension InheritanceClauseSyntax {
    var types: [String] {
        inheritedTypes.map {
            $0.type.description
        }
    }
}
