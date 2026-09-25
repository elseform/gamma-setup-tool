#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

import Foundation

func usage() -> String {
    """
    Usage:
      gamma-setup-engine create-wine-engine --request-file PATH
    """
}

func argumentValue(_ name: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
        return nil
    }
    return arguments[index + 1]
}

func loadWineEngineRequest(from arguments: [String]) throws -> WineEngineSetupRequest {
    guard let path = argumentValue("--request-file", in: arguments) else {
        throw SetupEngineError.message("--request-file is required")
    }
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(WineEngineSetupRequest.self, from: data)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    FileHandle.standardError.write(Data((usage() + "\n").utf8))
    exit(2)
}

let reporter = JSONEventReporter()

do {
    switch command {
    case "create-wine-engine":
        let request = try loadWineEngineRequest(from: arguments)
        let wineEngineSetup = WineEngineSetup(executablePath: CommandLine.arguments[0], reporter: reporter)
        try await wineEngineSetup.create(request: request)
        reporter.completed(success: true, message: "Setup complete.")
    case "-h", "--help":
        print(usage())
    default:
        throw SetupEngineError.message("unknown command: \(command)")
    }
} catch {
    let message: String
    if let setup = error as? SetupEngineError {
        message = setup.description
    } else {
        message = error.localizedDescription
    }
    reporter.completed(success: false, message: message)
    FileHandle.standardError.write(Data(("error: \(message)\n").utf8))
    exit(1)
}
