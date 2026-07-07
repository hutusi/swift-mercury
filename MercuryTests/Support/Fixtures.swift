import Foundation
@testable import Mercury

private final class BundleLocator {}

enum Fixtures {
    struct MissingFixture: Error {
        let name: String
    }

    static func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: BundleLocator.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw MissingFixture(name: name)
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try JSONCoding.makeDecoder().decode(T.self, from: data(name))
    }

    static func decode<T: Decodable>(_ type: T.Type, fromJSON json: String) throws -> T {
        try JSONCoding.makeDecoder().decode(T.self, from: Data(json.utf8))
    }
}
