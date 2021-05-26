import Combine
import CombineRex
import CoreImage
import Foundation
import Vision

enum TextDetection { }

extension TextDetection {
    enum Action {
        case detect(image: URL)
        case didDetect(image: URL, text: String)
        case detectionError(DetectionError)
    }

    struct State: Equatable {
        let isDetecting: Bool
        let lastDetectionAttempt: Result<(image: URL, text: String), DetectionError>?

        static func ==(lhs: State, rhs: State) -> Bool {
            if lhs.isDetecting != rhs.isDetecting { return false }
            switch (lhs.lastDetectionAttempt, rhs.lastDetectionAttempt) {
            case (nil, nil): return true
            case let (.success((lhsImage, lhsText)), .success((rhsImage, rhsText))):
                return lhsImage == rhsImage && lhsText == rhsText
            case let (.failure(lhsError), .failure(rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }

        static var empty: State {
            .init(isDetecting: false, lastDetectionAttempt: nil)
        }
    }

    struct Dependency {
        let detect: (URL) -> AnyPublisher<[String], DetectionError>
    }
}

extension TextDetection {
    static let reducer = Reducer<Action, State>.reduce { action, state in
        switch action {
        case let .detect(image):
            state = .init(isDetecting: true, lastDetectionAttempt: nil)
        case let .didDetect(image, text):
            state = .init(isDetecting: false, lastDetectionAttempt: .success((image: image, text: text)))
        case let .detectionError(error):
            state = .init(isDetecting: false, lastDetectionAttempt: .failure(error))
        }
    }
}

extension TextDetection {
    static let middleware = EffectMiddleware<Action, Action, State, Dependency>.onAction { action, _, getState in
        guard case let .detect(image) = action else { return .doNothing }
        return Effect { context in
            context
                .dependencies
                .detect(image)
                .map { DispatchedAction(Action.didDetect(image: image, text: $0.joined(separator: " "))) }
                .catch { Just(DispatchedAction(Action.detectionError($0))) }
        }
    }
}

enum DetectionError: Error {
    case invalidCImage(URL)
    case invalidCGImage(CIImage)
    case recognizeTextError(RecognizeTextRequestError)
}

public enum RecognizeTextRequestError: Error {
    case schedulingError(Error)
    case resultError(VNRequest, Error)
    case resultHasNoTextObservations([Any]?)
}

extension TextDetection.Dependency {
    static let live = TextDetection.Dependency { url in
        CIImage(contentsOf: url)
            .asResult(orError: DetectionError.invalidCImage(url))
            .flatMap { $0.cgImage.asResult(orError: .invalidCGImage($0)) }
            .map { VNImageRequestHandler(cgImage: $0) }
            .publisher
            .flatMap { VNRecognizeTextRequest.perform(handler: $0).mapError(DetectionError.recognizeTextError) }
            .map { $0.compactMap { observation in observation.topCandidates(1).first?.string } }
            .eraseToAnyPublisher()
    }
}

extension VNRecognizeTextRequest {
    public static func perform(handler: VNImageRequestHandler) -> Deferred<Future<[VNRecognizedTextObservation], RecognizeTextRequestError>> {
        Deferred {
            Future { completion in
                let request = VNRecognizeTextRequest.init { req, err in
                    if let err = err {
                        completion(.failure(.resultError(req, err)))
                        return
                    }

                    guard let observations = req.results as? [VNRecognizedTextObservation] else {
                        completion(.failure(.resultHasNoTextObservations(req.results)))
                        return
                    }

                    completion(.success(observations))
                }

                do {
                    try handler.perform([request])
                } catch {
                    completion(.failure(.schedulingError(error)))
                }
            }
        }
    }
}

