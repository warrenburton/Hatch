import SwiftSyntax
import SwiftSyntaxParser

/// A SyntaxVistor subclass that parses swift code into a hierarchical list of symbols
open class SymbolParser: SyntaxVisitor {

    // MARK: - Private

    private var scope: Scope = .root(symbols: [])
    
    private var sourceLocationConverter: SourceLocationConverter!
    private var file: String

    // MARK: - Public

    /// Parses `source` and returns a hierarchical list of symbols from a string
    static public func parse(file: String, source: String) throws -> [Symbol] {
        let visitor = Self(file: file)
        visitor.sourceLocationConverter = SourceLocationConverter(file: file, source: source)
        try visitor.walk(SyntaxParser.parse(source: source))
        return visitor.scope.symbols
    }

    /// Designated initializer
    required public init(file: String) {
        self.file = file
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
                name: node.identifier.text,
                children: children,
                inheritedTypes: node.inheritanceClause?.types ?? [],
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
        }
    }

    open override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }

    open override func visitPost(_ node: ProtocolDeclSyntax) {
        endScopeAndAddSymbol { children in
            Protocol(
                name: node.identifier.text,
                children: children,
                inheritedTypes: node.inheritanceClause?.types ?? [],
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
        }
    }

    open override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }

    open override func visitPost(_ node: StructDeclSyntax) {
        endScopeAndAddSymbol { children in
            Struct(
                name: node.identifier.text,
                children: children,
                inheritedTypes: node.inheritanceClause?.types ?? [],
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
        }
    }

    open override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }

    open override func visitPost(_ node: EnumDeclSyntax) {
        endScopeAndAddSymbol { children in
            Enum(
                name: node.identifier.text,
                children: children,
                inheritedTypes: node.inheritanceClause?.types ?? [],
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
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
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
        }
    }

    open override func visit(_ node: EnumCaseElementSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }
    
    open override func visitPost(_ node: EnumCaseElementSyntax) {
        endScopeAndAddSymbol { children in
            EnumCaseElement(
                name: node.identifier.text,
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
        }
    }

    open override func visit(_ node: TypealiasDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }

    open override func visitPost(_ node: TypealiasDeclSyntax) {
        endScopeAndAddSymbol { children in
            Typealias(
                name: node.identifier.text,
                existingType: node.initializer.value.withoutTrivia().description,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
        }
    }

    open override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }

    open override func visitPost(_ node: ExtensionDeclSyntax) {
        endScopeAndAddSymbol { children in
            Extension(
                name: node.extendedType.withoutTrivia().description,
                children: children,
                inheritedTypes: node.inheritanceClause?.types ?? [],
                comments: [],
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
        }
    }
    
    open override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        //print("* VariableDeclSyntax")
        return startScope()
    }
    
    open override func visitPost(_ node: VariableDeclSyntax) {
        var isStatic = false
        
        // Examine this variables modifiers to figure out whether it's static
        if let modifiers = node.modifiers {
            for modifier in modifiers {
                let modifierText = modifier.withoutTrivia().name.text

                if modifierText == "static" || modifierText == "class" {
                    isStatic = true
                }
            }
        }

        let letOrVar: Variable.LetOrVar
        switch node.letOrVarKeyword.text {
        case "let":
            letOrVar =  .let
        case "var":
            letOrVar = .var
        default:
            letOrVar = .let
        }
        
        if let binding = node.bindings.first {
            endScopeAndAddSymbol { children in
                let newObject = Variable(
                    name: binding.pattern.description,
                    children: children,
                    comments: comments(node.leadingTrivia),
                    isStatic: isStatic,
                    letOrVar: letOrVar,
                    typeAnnotation: binding.typeAnnotation?.type.description,
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
        var comments = [Comment]()

        if let extractedComments = trivia?.compactMap(extractComments).flatMap({ $0 }) {
            comments = extractedComments
        }

        return comments
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
    
    /// Triggered on entering a function
    open override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        //print("* FunctionDeclSyntax")
        return startScope()
    }
    
    
    open override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        //print("* FunctionCallExprSyntax")
        return .visitChildren
    }
    open override func visit(_ node: FunctionParameterListSyntax) -> SyntaxVisitorContinueKind {
        //print("* FunctionParameterListSyntax")
        return .visitChildren
    }
    open override func visit(_ node: FunctionSignatureSyntax) -> SyntaxVisitorContinueKind {
        //print("* FunctionSignatureSyntax")
        return .visitChildren
    }
    open override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        //print("* FunctionParameterSyntax")
        return .visitChildren
    }
    
    open override func visit(_ node: FunctionDeclNameSyntax) -> SyntaxVisitorContinueKind {
        //print("* FunctionDeclNameSyntax")
        return .visitChildren
    }
    open override func visit(_ node: FunctionTypeSyntax) -> SyntaxVisitorContinueKind {
        //print("* FunctionTypeSyntax")
        return .visitChildren
    }
                                                                                                   
    open override func visitPost(_ node: GenericWhereClauseSyntax) {
        //print("* GenericWhereClauseSyntax")
    }
    open override func visitPost(_ node: GenericRequirementListSyntax) {
        //print("* GenericRequirementListSyntax")
    }
    open override func visitPost(_ node: GenericRequirementSyntax) {
        //print("* GenericRequirementSyntax")
    }
    open override func visitPost(_ node: GenericParameterListSyntax) {
        //print("* GenericParameterListSyntax")
    }
    
    open override func visit(_ node: GenericParameterSyntax) -> SyntaxVisitorContinueKind{
        //print("* GenericParameterSyntax")
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
    
    open override func visitPost(_ node: GenericParameterClauseSyntax) {
        //print("* GenericParameterClauseSyntax")
    }
    open override func visitPost(_ node: GenericArgumentListSyntax) {
        //print("* GenericArgumentListSyntax")
    }
    open override func visitPost(_ node: GenericArgumentSyntax) {
        //print("* GenericArgumentSyntax")
    }
    open override func visitPost(_ node: GenericArgumentClauseSyntax) {
        //print("* GenericArgumentClauseSyntax")
    }
    

    /// Triggered on exiting a function; moves back up the tree
    open override func visitPost(_ node: FunctionDeclSyntax) {
        var throwingStatus = Function.ThrowingStatus.unknown
        var isStatic = false
        var returnType = ""

        // Examine this function's modifiers to figure out whether it's static
        if let modifiers = node.modifiers {
            for modifier in modifiers {
                let modifierText = modifier.withoutTrivia().name.text

                if modifierText == "static" || modifierText == "class" {
                    isStatic = true
                }
            }
        }

        // Copy in the throwing status
        if let throwsKeyword = node.signature.throwsOrRethrowsKeyword {
            if let throwsOrRethrows = Function.ThrowingStatus(rawValue: throwsKeyword.text) {
                throwingStatus = throwsOrRethrows
            }
        } else {
            throwingStatus = .none
        }

        let name = node.identifier.text

        // Flatten the list of parameters for easier storage
        let parameters = node.signature.input.parameterList.compactMap { $0.description }
        
        //let generics = node.signature.input.

        // If we have a return type, copy it here
        if let nodeReturnType = node.signature.output?.returnType {
            returnType = "\(nodeReturnType)"
        }
        endScopeAndAddSymbol { children in
            let newObject = Function(
                name: name,
                parameters: parameters,
                isStatic: isStatic,
                throwingStatus: throwingStatus,
                returnType: returnType,
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    
}

public extension TypeInheritanceClauseSyntax {
    var types: [String] {
        inheritedTypeCollection.map {
            $0.typeName.withoutTrivia().description
        }
    }
}
