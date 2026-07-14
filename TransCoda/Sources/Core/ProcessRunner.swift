import Foundation

/// Runs short-lived commands to completion and captures their output.
/// Suitable for probes and capability checks with modest output sizes.
enum ProcessRunner {
    struct Output {
        let exitCode: Int32
        let standardOutput: String
        let standardError: String
    }

    static func run(_ executable: URL, arguments: [String]) async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.standardInput = FileHandle.nullDevice

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { finished in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: Output(
                    exitCode: finished.terminationStatus,
                    standardOutput: String(data: outData, encoding: .utf8) ?? "",
                    standardError: String(data: errData, encoding: .utf8) ?? ""
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
