import Foundation

// MARK: - Symbol Protocol

/// Represents a Swift type or symbol
public protocol Symbol {
    var children: [Symbol] { get }
    var comments: [Comment] { get }
}

/// Represent a Swift type that can inherit from or conform to other types
public protocol InheritingSymbol {
    var name: String { get }
    var inheritedTypes: [String] { get }
}

// MARK: - Concrete Symbols

/// A swift protocol
public typealias ProtocolType = Protocol

public struct Protocol: Symbol, InheritingSymbol  {
    public let name: String
    public let children: [Symbol]
    public let inheritedTypes: [String]
    public let comments: [Comment]
}

/// A swift class
public struct Class: Symbol, InheritingSymbol  {
    public let name: String
    public let children: [Symbol]
    public let inheritedTypes: [String]
    public let comments: [Comment]
}

/// A swift struct
public struct Struct: Symbol, InheritingSymbol  {
    public let name: String
    public let children: [Symbol]
    public let inheritedTypes: [String]
    public let comments: [Comment]
}

/// A swift enum
public struct Enum: Symbol, InheritingSymbol  {
    public let name: String
    public let children: [Symbol]
    public let inheritedTypes: [String]
    public let comments: [Comment]
}

/// A single case of a swift enum
public struct EnumCase: Symbol  {
    public var name: String {
        caseDeclarations.compactMap({ $0 as? EnumCaseElement} ).first?.name ?? "oh no"
    }
    public var caseDeclarations: [Symbol]
    public var children: [Symbol] { [] }
    public let comments: [Comment]
}

/// A single element of a swift enum case
public struct EnumCaseElement: Symbol  {
    public let name: String
    public let children: [Symbol]
    public let comments: [Comment]
}

/// A swift typealias to an existing type
public struct Typealias: Symbol  {
    public let name: String
    public let existingType: String
    public let children: [Symbol] = []
    public let comments: [Comment]
}

/// A swift extension
public struct Extension: Symbol, InheritingSymbol  {
    public let name: String
    public let children: [Symbol]
    public let inheritedTypes: [String]
    public let comments: [Comment]
}


