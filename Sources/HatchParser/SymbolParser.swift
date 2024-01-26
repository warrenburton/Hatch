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
        let parameters = node.signature.input.parameterList
            .compactMap { child in
                FunctionParameter(
                    firstName: child.firstName?.text ?? "_",
                    secondName: child.secondName?.text,
                    type: child.type?.description ?? "<untyped>",
                    children: [],
                    comments: comments(node.leadingTrivia),
                    sourceRange: node.sourceRange(converter: sourceLocationConverter)
                )
                
            }
                
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
    
    
    open override func visitPost(_ node: MissingSyntax) {
        
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MissingDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MissingExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MissingStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MissingTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MissingPatternSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    
    #if DEEPDIVE
    open override func visit(_ node: CodeBlockItemSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: CodeBlockItemSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visit(_ node: CodeBlockItemListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: CodeBlockItemListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visit(_ node: CodeBlockSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: CodeBlockSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    #endif
    
    
    open override func visitPost(_ node: UnexpectedNodesSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: InOutExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PoundColumnExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TupleExprElementListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ArrayElementListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DictionaryElementListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: StringLiteralSegmentsSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TryExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AwaitExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MoveExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DeclNameArgumentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DeclNameArgumentListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DeclNameArgumentsSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: IdentifierExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SuperRefExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: NilLiteralExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DiscardAssignmentExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AssignmentExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PackElementExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SequenceExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ExprListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SymbolicReferenceExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PrefixOperatorExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: BinaryOperatorExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ArrowExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: InfixOperatorExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: FloatLiteralExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TupleExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ArrayExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DictionaryExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visitPost(_ node: TupleExprElementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ArrayElementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DictionaryElementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: IntegerLiteralExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: BooleanLiteralExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: UnresolvedTernaryExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TernaryExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MemberAccessExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: UnresolvedIsExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: IsExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: UnresolvedAsExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AsExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TypeExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visitPost(_ node: ClosureCaptureItemSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ClosureCaptureItemListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ClosureCaptureSignatureSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ClosureParamSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ClosureParamListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ClosureSignatureSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ClosureExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: UnresolvedPatternExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MultipleTrailingClosureElementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MultipleTrailingClosureElementListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: FunctionCallExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SubscriptExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: OptionalChainingExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ForcedValueExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PostfixUnaryExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SpecializeExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: StringSegmentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ExpressionSegmentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: StringLiteralExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: RegexLiteralExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visitPost(_ node: KeyPathExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: KeyPathComponentListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: KeyPathComponentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: KeyPathPropertyComponentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: KeyPathSubscriptComponentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: KeyPathOptionalComponentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MacroExpansionExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PostfixIfConfigExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: EditorPlaceholderExprSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: YieldExprListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: YieldExprListElementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TypeInitializerClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    
    
    open override func visitPost(_ node: AssociatedtypeDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
//    open override func visitPost(_ node: FunctionParameterListSyntax) {
//        endScopeAndAddSymbol { children in
//            let newObject = Mystery(
//                name: "NI \(type(of: node))",
//                children: children,
//                comments: comments(node.leadingTrivia),
//                sourceRange: node.sourceRange(converter: sourceLocationConverter)
//            )
//            return newObject
//        }
//    }
//    
//    open override func visitPost(_ node: ParameterClauseSyntax) {
//        endScopeAndAddSymbol { children in
//            let newObject = Mystery(
//                name: "NI \(type(of: node))",
//                children: children,
//                comments: comments(node.leadingTrivia),
//                sourceRange: node.sourceRange(converter: sourceLocationConverter)
//            )
//            return newObject
//        }
//    }
    
    open override func visitPost(_ node: ReturnClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
//    open override func visitPost(_ node: FunctionSignatureSyntax) {
//        endScopeAndAddSymbol { children in
//            let newObject = Mystery(
//                name: "NI \(type(of: node))",
//                children: children,
//                comments: comments(node.leadingTrivia),
//                sourceRange: node.sourceRange(converter: sourceLocationConverter)
//            )
//            return newObject
//        }
//    }
    
    
    open override func visitPost(_ node: IfConfigClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: IfConfigClauseListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: IfConfigDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PoundErrorDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PoundWarningDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PoundSourceLocationSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PoundSourceLocationArgsSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DeclModifierDetailSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DeclModifierSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visitPost(_ node: ActorDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    #if DEEPDIVE
    open override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: SourceFileSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    #endif
    
    
    open override func visitPost(_ node: InitializerClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: FunctionParameterSyntax) {
        
        endScopeAndAddSymbol { children in
            let newObject = FunctionParameter(
                firstName: node.firstName?.text ?? "_",
                secondName: node.secondName?.text,
                type: node.type?.description ?? "<untyped>",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
        
    }
    
    open override func visitPost(_ node: ModifierListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visitPost(_ node: InitializerDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DeinitializerDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SubscriptDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AccessLevelModifierSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AccessPathComponentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AccessPathSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ImportDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AccessorParameterSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AccessorDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AccessorListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AccessorBlockSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PatternBindingSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PatternBindingListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visitPost(_ node: EnumCaseElementListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visitPost(_ node: OperatorDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DesignatedTypeListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DesignatedTypeElementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: OperatorPrecedenceAndTypesSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PrecedenceGroupDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PrecedenceGroupAttributeListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PrecedenceGroupRelationSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PrecedenceGroupNameListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PrecedenceGroupNameElementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PrecedenceGroupAssignmentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PrecedenceGroupAssociativitySyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MacroDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MacroExpansionDeclSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TokenListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: NonEmptyTokenListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: CustomAttributeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AttributeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AttributeListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SpecializeAttributeSpecListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AvailabilityEntrySyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: LabeledSpecializeEntrySyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TargetFunctionEntrySyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: NamedAttributeStringArgumentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DeclNameSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ImplementsAttributeArgumentsSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ObjCSelectorPieceSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ObjCSelectorSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DifferentiableAttributeArgumentsSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DifferentiabilityParamsClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DifferentiabilityParamsSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DifferentiabilityParamListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DifferentiabilityParamSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DerivativeRegistrationAttributeArgumentsSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: QualifiedDeclNameSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: FunctionDeclNameSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: BackDeployedAttributeSpecListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: BackDeployVersionListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: BackDeployVersionArgumentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: OpaqueReturnTypeOfAttributeArgumentsSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ConventionAttributeArgumentsSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ConventionWitnessMethodAttributeArgumentsSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: LabeledStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ContinueStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: WhileStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DeferStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ExpressionStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SwitchCaseListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: RepeatWhileStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: GuardStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: WhereClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ForInStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SwitchStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: CatchClauseListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DoStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ReturnStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: YieldStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: YieldListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: FallthroughStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: BreakStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: CaseItemListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: CatchItemListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ConditionElementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AvailabilityConditionSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MatchingPatternConditionSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: OptionalBindingConditionSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: UnavailabilityConditionSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: HasSymbolConditionSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ConditionElementListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DeclarationStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ThrowStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: IfStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SwitchCaseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SwitchDefaultLabelSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: CaseItemSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: CatchItemSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SwitchCaseLabelSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: CatchClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PoundAssertStmtSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: GenericWhereClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: GenericRequirementListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: GenericRequirementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: SameTypeRequirementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: LayoutRequirementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: GenericParameterListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visitPost(_ node: PrimaryAssociatedTypeListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PrimaryAssociatedTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: GenericParameterClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ConformanceRequirementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PrimaryAssociatedTypeClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }

    #if DEEPDIVE
    open override func visit(_ node: SimpleTypeIdentifierSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: SimpleTypeIdentifierSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    #endif
    
    
    
    open override func visitPost(_ node: MemberTypeIdentifierSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ClassRestrictionTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ArrayTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: DictionaryTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: MetatypeTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: OptionalTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ConstrainedSugarTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ImplicitlyUnwrappedOptionalTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: CompositionTypeElementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: CompositionTypeElementListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: CompositionTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PackExpansionTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: PackReferenceTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TupleTypeElementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TupleTypeElementListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TupleTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: FunctionTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AttributedTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: GenericArgumentListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: GenericArgumentSyntax) {
        
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: GenericArgumentClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: NamedOpaqueReturnTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TypeAnnotationSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: EnumCasePatternSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: IsTypePatternSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: OptionalPatternSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: IdentifierPatternSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AsTypePatternSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TuplePatternSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: WildcardPatternSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TuplePatternElementSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ExpressionPatternSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: TuplePatternElementListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: ValueBindingPatternSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AvailabilitySpecListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AvailabilityArgumentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AvailabilityLabeledArgumentSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: AvailabilityVersionRestrictionSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    open override func visitPost(_ node: VersionTupleSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
 
    #if DEEPDIVE
    open override func visit(_ node: TokenSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: TokenSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "\(type(of: node)) |\(node.text)|",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    #endif
    
    
    open override func visit(_ node: MissingSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MissingDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MissingExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MissingStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MissingTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MissingPatternSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: UnexpectedNodesSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: InOutExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PoundColumnExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TupleExprElementListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ArrayElementListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DictionaryElementListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: StringLiteralSegmentsSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AwaitExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MoveExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DeclNameArgumentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DeclNameArgumentListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DeclNameArgumentsSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: IdentifierExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SuperRefExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: NilLiteralExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DiscardAssignmentExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AssignmentExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PackElementExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ExprListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SymbolicReferenceExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PrefixOperatorExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: BinaryOperatorExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ArrowExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: FloatLiteralExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TupleExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ArrayExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DictionaryExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TupleExprElementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ArrayElementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DictionaryElementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: IntegerLiteralExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: BooleanLiteralExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: UnresolvedTernaryExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TernaryExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: UnresolvedIsExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: IsExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: UnresolvedAsExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AsExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TypeExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ClosureCaptureItemSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ClosureCaptureItemListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ClosureCaptureSignatureSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ClosureParamSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ClosureParamListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ClosureSignatureSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: UnresolvedPatternExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MultipleTrailingClosureElementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MultipleTrailingClosureElementListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SubscriptExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: OptionalChainingExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ForcedValueExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PostfixUnaryExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SpecializeExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: StringSegmentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ExpressionSegmentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: RegexLiteralExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: KeyPathExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: KeyPathComponentListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: KeyPathComponentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: KeyPathPropertyComponentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: KeyPathSubscriptComponentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: KeyPathOptionalComponentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PostfixIfConfigExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: EditorPlaceholderExprSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: YieldExprListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: YieldExprListElementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TypeInitializerClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //   open override func visit(_ node: TypealiasDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AssociatedtypeDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //open override func visit(_ node: FunctionParameterListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //open override func visit(_ node: ParameterClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ReturnClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //open override func visit(_ node: FunctionSignatureSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: IfConfigClauseListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PoundErrorDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PoundWarningDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PoundSourceLocationSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PoundSourceLocationArgsSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DeclModifierDetailSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DeclModifierSyntax) -> SyntaxVisitorContinueKind { startScope() }
    
    #if DEEPDIVE
    open override func visit(_ node: InheritedTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: InheritedTypeSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visit(_ node: InheritedTypeListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: InheritedTypeListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visit(_ node: TypeInheritanceClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: TypeInheritanceClauseSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    #endif
    
    
    // open override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //      open override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //      open override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //      open override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    
    #if DEEPDIVE
    open override func visit(_ node: MemberDeclBlockSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: MemberDeclBlockSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visit(_ node: MemberDeclListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: MemberDeclListSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    
    open override func visit(_ node: MemberDeclListItemSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visitPost(_ node: MemberDeclListItemSyntax) {
        endScopeAndAddSymbol { children in
            let newObject = Mystery(
                name: "NI \(type(of: node))",
                children: children,
                comments: comments(node.leadingTrivia),
                sourceRange: node.sourceRange(converter: sourceLocationConverter)
            )
            return newObject
        }
    }
    #endif
    
    
    open override func visit(_ node: InitializerClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }

    open override func visit(_ node: ModifierListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //open override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AccessLevelModifierSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AccessPathComponentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AccessPathSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AccessorParameterSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AccessorListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AccessorBlockSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PatternBindingSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PatternBindingListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //open override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //open override func visit(_ node: EnumCaseElementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: EnumCaseElementListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //open override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //open override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: OperatorDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DesignatedTypeListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DesignatedTypeElementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: OperatorPrecedenceAndTypesSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PrecedenceGroupDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PrecedenceGroupAttributeListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PrecedenceGroupRelationSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PrecedenceGroupNameListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PrecedenceGroupNameElementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PrecedenceGroupAssignmentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PrecedenceGroupAssociativitySyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MacroDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TokenListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: NonEmptyTokenListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: CustomAttributeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AttributeListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SpecializeAttributeSpecListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AvailabilityEntrySyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: LabeledSpecializeEntrySyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TargetFunctionEntrySyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: NamedAttributeStringArgumentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DeclNameSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ImplementsAttributeArgumentsSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ObjCSelectorPieceSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ObjCSelectorSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DifferentiableAttributeArgumentsSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DifferentiabilityParamsClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DifferentiabilityParamsSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DifferentiabilityParamListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DifferentiabilityParamSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DerivativeRegistrationAttributeArgumentsSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: QualifiedDeclNameSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: FunctionDeclNameSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: BackDeployedAttributeSpecListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: BackDeployVersionListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: BackDeployVersionArgumentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: OpaqueReturnTypeOfAttributeArgumentsSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ConventionAttributeArgumentsSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ConventionWitnessMethodAttributeArgumentsSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: LabeledStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ContinueStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DeferStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ExpressionStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SwitchCaseListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: RepeatWhileStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: WhereClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ForInStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SwitchStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: CatchClauseListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DoStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ReturnStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: YieldStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: YieldListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: FallthroughStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: BreakStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: CaseItemListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: CatchItemListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ConditionElementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AvailabilityConditionSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MatchingPatternConditionSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: OptionalBindingConditionSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: UnavailabilityConditionSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: HasSymbolConditionSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ConditionElementListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DeclarationStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ThrowStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: IfStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SwitchCaseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SwitchDefaultLabelSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: CaseItemSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: CatchItemSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SwitchCaseLabelSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PoundAssertStmtSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: GenericWhereClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: GenericRequirementListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: GenericRequirementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: SameTypeRequirementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: LayoutRequirementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: GenericParameterListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    //open override func visit(_ node: GenericParameterSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PrimaryAssociatedTypeListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PrimaryAssociatedTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: GenericParameterClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ConformanceRequirementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PrimaryAssociatedTypeClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    
    open override func visit(_ node: MemberTypeIdentifierSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ClassRestrictionTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ArrayTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: DictionaryTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: MetatypeTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: OptionalTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ConstrainedSugarTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ImplicitlyUnwrappedOptionalTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: CompositionTypeElementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: CompositionTypeElementListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: CompositionTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PackExpansionTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: PackReferenceTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TupleTypeElementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TupleTypeElementListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TupleTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: FunctionTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AttributedTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: GenericArgumentListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: GenericArgumentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: GenericArgumentClauseSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: NamedOpaqueReturnTypeSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TypeAnnotationSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: EnumCasePatternSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: IsTypePatternSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: OptionalPatternSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AsTypePatternSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TuplePatternSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: WildcardPatternSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TuplePatternElementSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ExpressionPatternSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: TuplePatternElementListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: ValueBindingPatternSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AvailabilitySpecListSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AvailabilityArgumentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AvailabilityLabeledArgumentSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: AvailabilityVersionRestrictionSyntax) -> SyntaxVisitorContinueKind { startScope() }
    open override func visit(_ node: VersionTupleSyntax) -> SyntaxVisitorContinueKind { startScope() }
    
    
    
}

public extension TypeInheritanceClauseSyntax {
    var types: [String] {
        inheritedTypeCollection.map {
            $0.typeName.withoutTrivia().description
        }
    }
}
