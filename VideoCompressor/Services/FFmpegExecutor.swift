import Foundation

actor FFmpegExecutor {
    private var currentProcess: Process?
    private var cancelRequested = false

    func cancel() {
        cancelRequested = true
        currentProcess?.terminate()
    }

    func execute(
        command: FFmpegCommand,
        durationSec: Double,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.launchPath)
        process.arguments = command.arguments
        cancelRequested = false

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            currentProcess = process
        } catch {
            throw CompressionError.missingEncoder(error.localizedDescription)
        }

        let progressTask = Task.detached(priority: .utility) {
            guard durationSec > 0 else { return }
            do {
                for try await line in stdout.fileHandleForReading.bytes.lines {
                    guard let processedSec = FFmpegExecutor.progressSeconds(from: line) else { continue }
                    let progress = min(max(processedSec / durationSec, 0), 1)
                    onProgress(progress)
                }
            } catch {
                // Ignore stream read failures; process termination decides final result.
            }
        }

        let stderrTask = Task.detached(priority: .utility) { () -> String in
            var combined = ""
            do {
                for try await line in stderr.fileHandleForReading.bytes.lines {
                    combined += line
                    combined += "\n"
                    guard durationSec > 0,
                          let processedSec = FFmpegExecutor.progressSeconds(from: line) else { continue }
                    let progress = min(max(processedSec / durationSec, 0), 1)
                    onProgress(progress)
                }
            } catch {
                return combined
            }
            return combined
        }

        let termination = await withCheckedContinuation { (continuation: CheckedContinuation<(Process.TerminationReason, Int32), Never>) in
            process.terminationHandler = { proc in
                continuation.resume(returning: (proc.terminationReason, proc.terminationStatus))
            }
        }

        _ = await progressTask.result
        let capturedError = await stderrTask.value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        clearCurrentProcess()

        if cancelRequested {
            cancelRequested = false
            throw CompressionError.canceled
        }

        if termination.0 == .uncaughtSignal && termination.1 == SIGTERM {
            cancelRequested = false
            throw CompressionError.canceled
        }

        if capturedError.localizedCaseInsensitiveContains("signal 15") ||
            capturedError.localizedCaseInsensitiveContains("received signal") {
            cancelRequested = false
            throw CompressionError.canceled
        }

        if termination.1 == 0 {
            cancelRequested = false
            onProgress(1.0)
            return
        }

        cancelRequested = false
        let message = capturedError.isEmpty ? "ffmpeg exit code: \(termination.1)" : capturedError
        throw CompressionError.ffmpegFailed(message)
    }

    private func clearCurrentProcess() {
        currentProcess = nil
    }

    nonisolated static func progressSeconds(from line: String) -> Double? {
        if line.hasPrefix("out_time_us=") {
            let text = line.replacingOccurrences(of: "out_time_us=", with: "")
            if let us = Double(text), us >= 0 {
                return us / 1_000_000.0
            }
        }

        if line.hasPrefix("out_time_ms=") {
            let text = line.replacingOccurrences(of: "out_time_ms=", with: "")
            if let raw = Double(text), raw >= 0 {
                // ffmpeg progress may report this field in microseconds on some builds.
                return raw >= 1_000_000 ? raw / 1_000_000.0 : raw / 1000.0
            }
        }

        if line.hasPrefix("out_time=") {
            let text = line.replacingOccurrences(of: "out_time=", with: "")
            return parseClock(text)
        }

        if let range = line.range(of: "time=") {
            let tail = line[range.upperBound...]
            let token = tail.split(separator: " ").first.map(String.init) ?? ""
            return parseClock(token)
        }

        return nil
    }

    nonisolated private static func parseClock(_ value: String) -> Double? {
        let parts = value.split(separator: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else {
            return nil
        }
        return max(0, hours * 3600 + minutes * 60 + seconds)
    }
}
