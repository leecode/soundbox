import Foundation
import CoreAudio
import AVFAudio

// MARK: - Lossless Decoder
class LosslessDecoder {

    // MARK: - Supported Formats
    static let supportedExtensions = ["wav", "flac", "aiff", "aif", "alac", "m4a", "aac", "mp3", "ogg"]

    // MARK: - Get Audio Info
    func getAudioInfo(_ url: URL, completion: @escaping (Result<AudioInfo, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard FileManager.default.fileExists(atPath: url.path) else {
                DispatchQueue.main.async {
                    completion(.failure(DecoderError.fileNotFound))
                }
                return
            }

            guard let audioFile = try? AVAudioFile(forReading: url) else {
                DispatchQueue.main.async {
                    completion(.failure(DecoderError.unsupportedFormat))
                }
                return
            }

            let format = audioFile.processingFormat
            let duration = Double(audioFile.length) / format.sampleRate

            let bitDepth: Int
            switch format.commonFormat {
            case .pcmFormatFloat32:
                bitDepth = 32
            case .pcmFormatInt16:
                bitDepth = 16
            case .pcmFormatInt32:
                bitDepth = 32
            default:
                bitDepth = 24
            }

            let info = AudioInfo(
                url: url,
                sampleRate: format.sampleRate,
                bitDepth: bitDepth,
                channels: Int(format.channelCount),
                duration: duration,
                isFloat: format.commonFormat == .pcmFormatFloat32
            )

            DispatchQueue.main.async {
                completion(.success(info))
            }
        }
    }
}

// MARK: - Audio Info
struct AudioInfo {
    let url: URL
    let sampleRate: Double
    let bitDepth: Int
    let channels: Int
    let duration: TimeInterval
    let isFloat: Bool

    var audioFormat: AudioFormat {
        AudioFormat(
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channels: channels,
            isFloat: isFloat,
            isBigEndian: false
        )
    }
}

// MARK: - Decoder Errors
enum DecoderError: Error, LocalizedError {
    case fileNotFound
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "音频文件未找到"
        case .unsupportedFormat:
            return "不支持的音频格式"
        }
    }
}
