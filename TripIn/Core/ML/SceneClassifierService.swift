import Vision
import CoreML
import UIKit

class SceneClassifierService {
    static let shared = SceneClassifierService()

    enum SceneError: Error {
        case modelLoadFailed
        case classificationFailed
        case invalidImage
    }

    private var model: VNCoreMLModel?

    init() {
        do {
            let coreMLModel = try SceneClassifier(configuration: MLModelConfiguration()).model
            self.model = try VNCoreMLModel(for: coreMLModel)
        } catch {
            print("Failed to load SceneClassifier model: \(error)")
        }
    }

    func classify(image: UIImage) async throws -> String {
        guard let model = model else { throw SceneError.modelLoadFailed }
        guard let cgImage = image.cgImage else { throw SceneError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(throwing: SceneError.classificationFailed)
                    return
                }
                // Map model output to existing attraction_category values
                let mappedCategory = self.mapSceneToCategory(topResult.identifier)
                continuation.resume(returning: mappedCategory)
            }
            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // Map raw model labels to your existing attraction_category system
    private func mapSceneToCategory(_ label: String) -> String {
        switch label {
        case "beach":  return "beach"
        case "nature": return "nature"
        case "urban":  return "cultural"
        default:       return "outdoor"
        }
    }
}
