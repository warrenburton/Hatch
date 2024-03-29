import Foundation
import Hatch
import SwiftSyntax

@main
public struct ExampleApp {
    public static func main() throws {

        // MARK: - Example of parsing a string

        let source = """
        
        struct A1 {
            struct BC {
                struct C1 {}
                struct C2 {}
                struct C3 {}
        
            }
        
            struct BD {
                struct D1 {}
                struct D2 {}
            }
        
            struct BX {}
        }
        
        struct A2 {}
        
        enum MyEnum {}
        
        """
        
        let symbols = SymbolParser.parse(fileName: "example.swift", source: source)
            .flattened()
            .compactMap { $0 as? InheritingSymbol }
        
        dump(symbols)

        // MARK: - Example of parsing from the file system

        let path = "~/Repositories/myProject" as NSString
        let directoryURL = URL(fileURLWithPath: path.expandingTildeInPath)
        
        let allSymbols = try FileManager.default
            .enumerator(at: directoryURL, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.hasDirectoryPath == false }
            .filter { $0.pathExtension == "swift" }
            .flatMap { try SymbolParser.parse(fileName: "example.swift", source: String(contentsOf: $0)) }
        
        dump(allSymbols)

        // MARK: - Example of StringBuilder

        @StringBuilder var output: String {
            """
            let a = 10
            
            print("for start")
            """
            
            
            for t in symbols.map(\.name) {
            """
                print(\(t))
            """
            }
            
            """
            print("for done")
            end
            """
        }
        
        print(output)
    }
}

// MARK: - Custom Visitor

class MyProjectVisitor: SymbolParser {
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        startScope()
    }
    
    override func visitPost(_ node: StructDeclSyntax) {
        guard let genericWhereClause = node.genericWhereClause else {
            super.visitPost(node)
            return
        }
        
        
        endScopeAndAddSymbol { children in
            MySpecialStruct(
                name: node.name.text,
                children: children,
                comments: [],
                sourceRange: SourceRange(
                    start: SourceLocation(
                        line: 1,
                        column: 0,
                        offset: 0,
                        file: "foo"
                    ),
                    end: SourceLocation(
                        line: 2,
                        column: 0,
                        offset: 0,
                        file: "foo"
                    )
                ),
                genericWhereClause: genericWhereClause.description
            )
        }
    }
}

struct MySpecialStruct: Symbol {
    let name: String
    let children: [Symbol]
    var comments: [Hatch.Comment]
    var sourceRange: SwiftSyntax.SourceRange
    
    let genericWhereClause: String
}

// MARK: - FileManager convenience

extension FileManager {
    public func filesInDirectory(_ directoryURL: URL) -> [URL] {
        guard let enumerator = enumerator(at: directoryURL, includingPropertiesForKeys: []) else {
            return []
        }
        
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.hasDirectoryPath == false }
    }
}
