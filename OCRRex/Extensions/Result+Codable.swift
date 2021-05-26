import Foundation

extension Result {
    enum CodingKeys: CodingKey {
        case success
        case failure
    }
}

extension Result: Encodable where Success: Encodable, Failure: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .success(value):
            try container.encode(value, forKey: .success)
        case let .failure(error):
            try container.encode(error, forKey: .failure)
        }
    }
}

extension Result: Decodable where Success: Decodable, Failure: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.success) {
            let value = try container.decode(Success.self, forKey: .success)
            self = .success(value)
        } else if container.contains(.failure) {
            let error = try container.decode(Failure.self, forKey: .failure)
            self = .failure(error)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .success,
                in: container,
                debugDescription: "The container should have either a value or a error key"
            )
        }
    }
}
