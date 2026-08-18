//
//  JSONValue.swift
//  Truedata
//

import Foundation

enum JSONValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
            return
        }
        if let int = try? container.decode(Int.self) {
            self = .int(int)
            return
        }
        if let double = try? container.decode(Double.self) {
            self = .double(double)
            return
        }
        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }
        if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
            return
        }
        if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
            return
        }
        self = .null
    }

    var stringValue: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return value ? "true" : "false"
        default: return ""
        }
    }

    var intValue: Int {
        switch self {
        case .int(let value): return value
        case .double(let value): return Int(value)
        case .string(let value): return Int(value) ?? 0
        case .bool(let value): return value ? 1 : 0
        default: return 0
        }
    }

    var boolValue: Bool {
        switch self {
        case .bool(let value): return value
        case .int(let value): return value != 0
        case .string(let value): return ["1", "true", "yes"].contains(value.lowercased())
        default: return false
        }
    }

    var doubleValue: Double {
        switch self {
        case .double(let value): return value
        case .int(let value): return Double(value)
        case .string(let value): return Double(value.replacingOccurrences(of: ",", with: "")) ?? 0
        default: return 0
        }
    }

    var objectValue: [String: JSONValue] {
        if case .object(let object) = self { return object }
        return [:]
    }

    var arrayValue: [JSONValue] {
        if case .array(let items) = self { return items }
        return []
    }

    subscript(_ key: String) -> JSONValue? {
        if case .object(let object) = self {
            if let value = object[key] { return value }
            return object.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
        }
        return nil
    }

    func nestedInt(in containers: [String], keys: [String]) -> Int {
        for container in containers {
            guard let nested = self[container] else { continue }
            for key in keys {
                if let value = nested[key] {
                    return value.intValue
                }
            }
        }
        for key in keys {
            if let value = self[key] {
                return value.intValue
            }
        }
        return 0
    }
}
