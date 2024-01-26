
import Foundation
import SwiftSyntax

public struct Import: Symbol {
    
    public var name: String
    public var children: [Symbol]
    public var comments: [Comment]
    public var sourceRange: SwiftSyntax.SourceRange
    
}
