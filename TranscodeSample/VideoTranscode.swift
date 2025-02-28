import Foundation
import AVKit

class VideoTranscode {
    let sourceURL: URL
    var outputURL: URL?
    var outputFormat: AVFileType = .mov
    var outputDimensions: CGSize?
    var compressionPreset: String = AVAssetExportPresetPassthrough // Default to passthrough

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
    }

    func setOutputFormat(format: AVFileType) {
        self.outputFormat = format
    }

    func setOutputDimensions(dimensions: CGSize) {
        self.outputDimensions = dimensions
    }

    func setCompressionPreset(preset: String) {
        self.compressionPreset = preset
    }

    func transcode(completion: @escaping (Bool, Error?) -> Void) {
        let asset = AVAsset(url: sourceURL)
        guard let exportSession = createExportSession(asset: asset) else {
            completion(false, NSError(domain: "VideoTranscode", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
            return
        }

        exportSession.outputURL = generateOutputURL()
        exportSession.outputFileType = outputFormat

        if let dimensions = outputDimensions {
            exportSession.videoComposition = createVideoComposition(asset: asset, dimensions: dimensions)
        }

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                self.outputURL = exportSession.outputURL
                completion(true, nil)
            case .failed, .cancelled:
                completion(false, exportSession.error)
            default:
                break
            }
        }
    }

    private func createExportSession(asset: AVAsset) -> AVAssetExportSession? {
        return AVAssetExportSession(asset: asset, presetName: compressionPreset)
    }

    private func generateOutputURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension(outputFormat.fileExtension)
    }

    private func createVideoComposition(asset: AVAsset, dimensions: CGSize) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = dimensions
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)

        let layerInstruction = createLayerInstruction(asset: asset, dimensions: dimensions)

        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        return videoComposition
    }

    private func createLayerInstruction(asset: AVAsset, dimensions: CGSize) -> AVMutableVideoCompositionLayerInstruction {
        guard let assetTrack = asset.tracks(withMediaType: .video).first else {
            fatalError("No video track found")
        }

        let naturalSize = calculateNaturalSize(assetTrack: assetTrack)
        let (scaleFactor, xTranslation, yTranslation) = calculateScaleAndTranslation(naturalSize: naturalSize, dimensions: dimensions)
        let transform = createTransform(scaleFactor: scaleFactor, xTranslation: xTranslation, yTranslation: yTranslation, assetTrack: assetTrack)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: assetTrack)
        layerInstruction.setTransform(transform, at: .zero)

        return layerInstruction
    }

    private func calculateNaturalSize(assetTrack: AVAssetTrack) -> CGSize {
        return assetTrack.naturalSize.applying(assetTrack.preferredTransform)
    }

    private func calculateScaleAndTranslation(naturalSize: CGSize, dimensions: CGSize) -> (CGFloat, CGFloat, CGFloat) {
        let aspectRatio = naturalSize.width / naturalSize.height
        var scaleFactor: CGFloat
        var xTranslation: CGFloat = 0
        var yTranslation: CGFloat = 0

        if naturalSize.width > naturalSize.height {
            scaleFactor = dimensions.height / naturalSize.height
            xTranslation = (dimensions.width - (naturalSize.width * scaleFactor)) / 2
        } else {
            scaleFactor = dimensions.width / naturalSize.width
            yTranslation = (dimensions.height - (naturalSize.height * scaleFactor)) / 2
        }

        return (scaleFactor, xTranslation, yTranslation)
    }

    private func createTransform(scaleFactor: CGFloat, xTranslation: CGFloat, yTranslation: CGFloat, assetTrack: AVAssetTrack) -> CGAffineTransform {
        var transform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        transform = transform.translatedBy(x: xTranslation / scaleFactor, y: yTranslation / scaleFactor)
        transform = transform.concatenating(assetTrack.preferredTransform)
        return transform
    }

}

private extension AVFileType {
    var fileExtension: String {
        switch self {
        case .mov:
            return "mov"
        case .mp4:
            return "mp4"
        case .m4v:
            return "m4v"
        default:
            return "mov"
        }
    }
}
