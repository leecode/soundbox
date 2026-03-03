import Foundation
import CoreAudio
import AVFAudio

// MARK: - Lossless Decoder
class LosslessDecoder {

    // MARK: - Supported Formats
    static let supportedExtensions = ["wav", "flac", "aiff", "aif", "alac", "m4a", "aac", "mp3", "ogg"]

    // MARK: - Decode
    func decode(_ url: URL, completion: @escaping (Result<DecodedAudio, Error>) -> Void) {
        print("🔊 开始解码: \(url.path)")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 检查文件是否存在
                guard FileManager.default.fileExists(atPath: url.path) else {
                    print("❌ 文件不存在: \(url.path)")
                    DispatchQueue.main.async {
                        completion(.failure(DecoderError.fileNotFound))
                    }
                    return
                }

                // 使用 AVAudioFile 解码（支持多种格式）
                guard let audioFile = try? AVAudioFile(forReading: url) else {
                    print("❌ 无法打开音频文件: \(url.path)")
                    DispatchQueue.main.async {
                        completion(.failure(DecoderError.unsupportedFormat))
                    }
                    return
                }

                let format = audioFile.processingFormat
                let frameCount = UInt32(audioFile.length)
                let duration = Double(audioFile.length) / format.sampleRate

                print("📊 音频信息: \(format.sampleRate)Hz, \(format.channelCount)声道, 时长:\(duration)秒")

                // 创建缓冲区
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    print("❌ 无法创建缓冲区")
                    DispatchQueue.main.async {
                        completion(.failure(DecoderError.bufferCreationFailed))
                    }
                    return
                }

                // 读取整个文件
                try audioFile.read(into: buffer)

                // 转换为 Data
                let audioData = try self.convertToData(buffer: buffer, format: format)

                // 创建 AudioStreamBasicDescription
                let asbd = self.createASBD(from: format)

                let decodedAudio = DecodedAudio(
                    data: audioData,
                    format: asbd,
                    duration: duration
                )

                print("✅ 解码成功: \(url.lastPathComponent), 数据大小: \(audioData.count) bytes")

                DispatchQueue.main.async {
                    completion(.success(decodedAudio))
                }
            } catch {
                print("❌ 解码失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Get Audio Info
    func getAudioInfo(_ url: URL, completion: @escaping (Result<AudioInfo, Error>) -> Void) {
        print("📝 获取音频信息: \(url.path)")

        DispatchQueue.global(qos: .userInitiated).async {
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ 文件不存在: \(url.path)")
                DispatchQueue.main.async {
                    completion(.failure(DecoderError.fileNotFound))
                }
                return
            }

            guard let audioFile = try? AVAudioFile(forReading: url) else {
                print("❌ 无法打开音频文件: \(url.path)")
                DispatchQueue.main.async {
                    completion(.failure(DecoderError.unsupportedFormat))
                }
                return
            }

            let format = audioFile.processingFormat
            let duration = Double(audioFile.length) / format.sampleRate

            // 判断位深度
            let bitDepth: Int
            if format.commonFormat == .pcmFormatFloat32 {
                bitDepth = 32
            } else if format.commonFormat == .pcmFormatInt16 {
                bitDepth = 16
            } else if format.commonFormat == .pcmFormatInt32 {
                bitDepth = 32
            } else {
                bitDepth = 24 // 默认
            }

            print("✅ 获取信息成功: \(format.sampleRate)Hz, \(bitDepth)bit, \(format.channelCount)声道, \(duration)秒")

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

    // MARK: - Private Helpers
    private func convertToData(buffer: AVAudioPCMBuffer, format: AVAudioFormat) throws -> Data {
        // 对于 float32 格式，直接获取数据
        guard let channelData = buffer.floatChannelData else {
            throw DecoderError.bufferConversionFailed
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(format.channelCount)

        // 创建交错的数据
        var interleavedData = Data(capacity: frameCount * channelCount * MemoryLayout<Float>.size)

        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                var sample = channelData[channel][frame]
                interleavedData.append(contentsOf: withUnsafeBytes(of: &sample) { Array($0) })
            }
        }

        return interleavedData
    }

    private func createASBD(from format: AVAudioFormat) -> AudioStreamBasicDescription {
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = format.sampleRate
        asbd.mChannelsPerFrame = format.channelCount
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerFrame = UInt32(format.channelCount) * UInt32(MemoryLayout<Float>.size)
        asbd.mBytesPerPacket = asbd.mBytesPerFrame
        asbd.mBitsPerChannel = UInt32(MemoryLayout<Float>.size * 8)
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked

        return asbd
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

// MARK: - Decoded Audio
struct DecodedAudio {
    var data: Data
    var format: AudioStreamBasicDescription
    var duration: TimeInterval
}

// MARK: - Decoder Errors
enum DecoderError: Error, LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case bufferCreationFailed
    case bufferConversionFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "音频文件未找到"
        case .unsupportedFormat:
            return "不支持的音频格式"
        case .bufferCreationFailed:
            return "无法创建音频缓冲区"
        case .bufferConversionFailed:
            return "音频数据转换失败"
        case .decodingFailed:
            return "音频解码失败"
        }
    }
}
