import Foundation

/// Scope represents the current scope/namespace in swift source code and holds nested symbols within it.
/// Typically a scope starts with "{" and ends with "}"
indirect enum Scope {

    /// The root scope of a file
    case root(symbols: [Symbol])
    /// A nested scope, within a parent scope
    case nested(parent: Scope, symbols: [Symbol])

    /// Starts a new nested scope
    mutating func start() {
        self = .nested(parent: self, symbols: [])
    }

    /// Ends the current scope by adding a new symbol to the scope tree.
    /// The children provided in the closure are the symbols in the scope to be ended
    mutating func end(makeSymbolWithChildrenInScope: (_ children: [Symbol]) -> Symbol) {
        let newSymbol = makeSymbolWithChildrenInScope(symbols)
        
        //print("xxx end \("\(newSymbol)".prefix(80))")

        switch self {
        case .root:
            fatalError("Unbalanced calls to start() and end(_:) at \(newSymbol)")

        case .nested(.root(let rootSymbols), _):
            self = .root(symbols: rootSymbols + [newSymbol])

        case .nested(.nested(let parent, let parentSymbols), _):
            self = .nested(parent: parent, symbols: parentSymbols + [newSymbol])
        }
    }

    /// Symbols at current scope
    var symbols: [Symbol] {
        switch self {
        case .root(let symbols): return symbols
        case .nested(_, let symbols): return symbols
        }
    }
}
