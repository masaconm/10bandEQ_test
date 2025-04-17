import Foundation
import AVFoundation

func convertToMP3(sourceURL: URL, destinationURL: URL, bitrate: Int32) throws {
    print("🔄 Start converting to MP3")
    print("📥 Source path: \(sourceURL.path)")
    print("📤 Destination path: \(destinationURL.path)")

    let audioFile = try AVAudioFile(forReading: sourceURL)
    let format = audioFile.processingFormat
    let frameCount = AVAudioFrameCount(audioFile.length)

    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        throw NSError(domain: "LAME", code: -10, userInfo: [NSLocalizedDescriptionKey: "Buffer allocation failed"])
    }

    try audioFile.read(into: buffer)

    guard let floatData = buffer.floatChannelData?[0] else {
        throw NSError(domain: "LAME", code: -11, userInfo: [NSLocalizedDescriptionKey: "No float channel data"])
    }

    let samples = UnsafeBufferPointer(start: floatData, count: Int(buffer.frameLength))
    var pcmSamples = samples.map { sample -> Int16 in
        if sample.isNaN || sample.isInfinite {
            return 0
        }
        let scaled = sample * 32767.0
        let clamped = max(-32768.0, min(32767.0, scaled))
        return Int16(clamped)
    }

    guard let lame = lame_init() else {
        throw NSError(domain: "LAME", code: -13, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize lame encoder"])
    }

    lame_set_in_samplerate(lame, Int32(format.sampleRate))
    lame_set_brate(lame, bitrate)
    lame_set_quality(lame, 2)
    lame_init_params(lame)

    let numSamples = Int32(pcmSamples.count)
    let mp3BufferSize = Int(1.25 * Float(numSamples) + 7200)  // LAME推奨
    let mp3Buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: mp3BufferSize)


    let destPath = destinationURL.path
    let mp3File = fopen(destPath, "wb")

    guard mp3File != nil else {
        mp3Buffer.deallocate()
        print("❌ fopen failed at path: \(destPath)")
        perror("fopen")  // POSIXエラー詳細を出力
        throw NSError(domain: "LAME", code: -12, userInfo: [NSLocalizedDescriptionKey: "Unable to open MP3 destination"])
    }

    defer {
        lame_close(lame)
        fclose(mp3File)
        mp3Buffer.deallocate()
    }

    let encoded = lame_encode_buffer(
        lame,
        &pcmSamples,
        &pcmSamples,
        Int32(pcmSamples.count),
        mp3Buffer,
        Int32(mp3BufferSize)
    )
    if encoded < 0 {
        print("❌ Encoding failed with code: \(encoded)")
        throw NSError(domain: "LAME", code: Int(encoded), userInfo: [NSLocalizedDescriptionKey: "MP3 encoding failed"])
    }

    fwrite(mp3Buffer, 1, Int(encoded), mp3File)

    let flush = lame_encode_flush(lame, mp3Buffer, Int32(mp3BufferSize))
    fwrite(mp3Buffer, 1, Int(flush), mp3File)

    print("✅ MP3 export completed: \(destinationURL.lastPathComponent)")
}

