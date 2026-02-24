import Foundation

actor FFmpegExecutor {
    private var currentProcess: Process?

    func cancel() {
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
                    guard line.hasPrefix("out_time_ms=") else { continue }
                    let msText = line.replacingOccurrences(of: "out_time_ms=", with: "")
                    guard let outTimeMs = Double(msText) else { continue }
                    let progress = min(max(outTimeMs / (durationSec * 1_000_000), 0), 1)
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

        if termination.0 == .uncaughtSignal && termination.1 == SIGTERM {
            throw CompressionError.canceled
        }

        if termination.1 == 0 {
            onProgress(1.0)
            return
        }

        let message = capturedError.isEmpty ? "ffmpeg exit code: \(termination.1)" : capturedError
        throw CompressionError.ffmpegFailed(message)
    }

    private func clearCurrentProcess() {
        currentProcess = nil
    }
}
