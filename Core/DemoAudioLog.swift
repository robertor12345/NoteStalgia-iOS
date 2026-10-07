import Foundation

/// Demo-recording aid. Simulator screen recordings carry no audio, so when the app is launched
/// with `-NoteStalgiaDemoAudioLog YES` it appends every sound it makes (music start / stop / loop /
/// volume, UI chimes) and every screen change to `Documents/demo-audio-log.jsonl`, stamped with
/// wall-clock time. The walkthrough soundtrack is then rebuilt from the same audio files and the
/// same chime synthesis, in sync with the video.
///
/// Off by default: without the launch argument every call is a single cached `Bool` check.
enum DemoAudioLog {
    static let isEnabled = UserDefaults.standard.bool(forKey: "NoteStalgiaDemoAudioLog")

    private static let queue = DispatchQueue(label: "com.notestalgia.demo-audio-log", qos: .utility)
    private static let fileURL: URL? = {
        guard isEnabled,
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let url = docs.appendingPathComponent("demo-audio-log.jsonl")
        try? FileManager.default.removeItem(at: url)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return url
    }()

    /// `fields` values must be JSON-representable (String, numbers, Bool). Taken as an autoclosure
    /// so call sites on hot paths (every chime, every music event) build nothing when logging is off.
    static func record(_ event: String, _ fields: @autoclosure () -> [String: Any] = [:]) {
        guard isEnabled, let fileURL else { return }
        var entry = fields()
        entry["event"] = event
        entry["t"] = Date().timeIntervalSince1970
        queue.async {
            guard let data = try? JSONSerialization.data(withJSONObject: entry),
                  let handle = try? FileHandle(forWritingTo: fileURL)
            else { return }
            handle.seekToEndOfFile()
            handle.write(data)
            handle.write(Data([0x0A]))
            try? handle.close()
        }
    }
}
