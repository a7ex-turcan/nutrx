import ASCKit
import Foundation

/// `asc` — call any App Store Connect API endpoint with the team key configured in the environment.
///
///     asc get    /v1/bundleIds?limit=5
///     asc post   /v1/bundleIds body.json
///     asc patch  /v1/apps/<id> -          (body from stdin)
///     asc delete /v1/bundleIds/<id>
///
/// Responses are pretty-printed JSON. The exit code is 1 for any non-2xx status or local failure.
@main
struct ASCCommand {
    static let usage = """
        usage: asc <get|post|patch|delete> <path> [body.json | -]
        env:   ASC_KEY_ID, ASC_ISSUER_ID, optional ASC_KEY_PATH
        """

    static func main() async {
        do {
            let succeeded = try await run(Array(CommandLine.arguments.dropFirst()))
            exit(succeeded ? 0 : 1)
        } catch {
            FileHandle.standardError.write(Data("asc: \(error)\n".utf8))
            exit(1)
        }
    }

    static func run(_ arguments: [String]) async throws -> Bool {
        guard arguments.count >= 2 else { throw ASCError.usage(usage) }
        let method = arguments[0].uppercased()
        guard ["GET", "POST", "PATCH", "DELETE"].contains(method) else { throw ASCError.usage(usage) }
        let path = arguments[1]
        let body = try arguments.count > 2 ? readBody(arguments[2]) : nil

        let client = try ASCClient.fromEnvironment()
        let response = try await client.send(method: method, path: path, body: body)
        FileHandle.standardError.write(Data("HTTP \(response.status)\n".utf8))
        print(prettyPrinted(response.body))
        return response.isSuccess
    }

    static func readBody(_ source: String) throws -> Data {
        let data: Data
        if source == "-" {
            data = FileHandle.standardInput.readDataToEndOfFile()
        } else {
            data = try Data(contentsOf: URL(fileURLWithPath: source))
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ASCError.invalidJSON(String(describing: error))
        }
        return data
    }

    static func prettyPrinted(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        guard let object = try? JSONSerialization.jsonObject(with: data),
            let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: pretty, encoding: .utf8)
        else {
            return String(decoding: data, as: UTF8.self)
        }
        return text
    }
}
