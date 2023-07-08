import Foundation


/// OSAScript runs AppleScript or JavaScript(JXA)
public struct OSAScript {
    
    public enum Language {
        case appleScript
        case javaScript
        
        var parameter: String {
            switch self {
            case .appleScript:
                return "AppleScript"
            case .javaScript:
                return "JavaScript"
            }
        }
    }
    
    public enum Error: LocalizedError {
        case unknown
        case commandFailed(Int32)
        case custom(String)

        public var errorDescription: String? {
            switch self {
            case .unknown:
                return "something went wrong"
            case .commandFailed(let statusCode):
                return "command exit with code: \(statusCode)"
            case .custom(let string):
                return string
            }
        }
    }
    
    public init() { }
    
    private let osascriptPath = URL(fileURLWithPath: "/usr/bin/osascript")
    
    /// Run script
    /// - Parameters:
    ///   - script: script you want to run
    ///   - arguments: these arguments will be passed as a list of strings to the direct parameter of the “run” handler.
    ///   - language: language of your script
    /// - Returns: Standard output
    @discardableResult public func run(script: String, arguments: [String] = [], language: Language = .appleScript) throws -> String? {
        var args = [
            "-l",
            language.parameter,
            "-e",
        ]
        args.append(script)
        
        if !arguments.isEmpty {
            args.append(contentsOf: arguments)
        }
        
        return try executeCommand(arguments: args)
    }
}


private extension OSAScript {
    func executeCommand(arguments: [String]) throws -> String? {
        let stdoutPipe = Pipe()

        let stderrPipe = Pipe()
        let process = Process()
        process.executableURL = osascriptPath
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationReason == .exit && process.terminationStatus == 0 {
            return try stdoutPipe.output()
        }

        let stderr = try stderrPipe.output()
        if let stderr {
            throw OSAScript.Error.custom(stderr)
        } else {
            let problem = "\(process.terminationReason.rawValue):\(process.terminationStatus)"
            throw OSAScript.Error.custom("\(osascriptPath.lastPathComponent) invocation failed: \(problem)")
        }
    }
}

private extension Pipe {
    func output() throws -> String? {
        let data = try fileHandleForReading.readToEnd()
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }
}
