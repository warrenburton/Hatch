import Foundation
import SwiftSyntax


struct InitClause: Symbol {
    
    public var name: String
    
    public var children: [Symbol] = []
    public var comments: [Comment] = []
    public let modifiers: [String] = []
    public var attributes: [String] = []
    
    public var sourceRange: SourceRange
    
}
