//
//  AudioRemarkRecorder.swift
//  Truedata
//

import AVFoundation
import Combine
import Foundation

final class AudioRemarkRecorder: NSObject, ObservableObject {

    enum PermissionState {
        case unknown
        case denied
        case granted
    }

    static let maxDuration = 60

    @Published private(set) var permissionState: PermissionState = .unknown
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var hasRecording = false

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var recordingURL: URL?

    var formattedElapsed: String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    var audioRemarkPayload: String {
        guard hasRecording,
              let recordingURL,
              let data = try? Data(contentsOf: recordingURL),
              !data.isEmpty else {
            return ""
        }
        return "data:audio/mp4;base64,\(data.base64EncodedString())"
    }

    func refreshPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            permissionState = .granted
        case .denied:
            permissionState = .denied
        case .undetermined:
            permissionState = .unknown
        @unknown default:
            permissionState = .unknown
        }
    }

    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionState = granted ? .granted : .denied
            }
        }
    }

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording() {
        guard permissionState == .granted, !isRecording else { return }

        deleteRecording()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("edit-order-audio-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record(forDuration: TimeInterval(Self.maxDuration))
            recordingURL = url
            isRecording = true
            elapsedSeconds = 0
            startTimer()
        } catch {
            recordingURL = nil
            isRecording = false
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        stopTimer()

        if elapsedSeconds > 0, recordingURL != nil {
            hasRecording = true
        } else {
            deleteRecording()
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func togglePlayback() {
        if isPlaying {
            stopPlayback()
            return
        }

        guard hasRecording, let recordingURL else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
        } catch {
            stopPlayback()
        }
    }

    func deleteRecording() {
        stopPlayback()
        stopTimer()

        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }

        audioRecorder?.stop()
        audioRecorder = nil
        recordingURL = nil
        isRecording = false
        hasRecording = false
        elapsedSeconds = 0
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedSeconds = min(self.elapsedSeconds + 1, Self.maxDuration)
            if self.elapsedSeconds >= Self.maxDuration {
                self.stopRecording()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension AudioRemarkRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRecording = false
            self.stopTimer()
            if flag, self.elapsedSeconds > 0 {
                self.hasRecording = true
            } else {
                self.deleteRecording()
            }
        }
    }
}

extension AudioRemarkRecorder: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.stopPlayback()
        }
    }
}
