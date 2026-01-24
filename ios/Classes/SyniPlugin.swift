import Flutter
import UIKit
import SyniSwift

/// Flutter plugin for Syni SDK on iOS.
///
/// This plugin delegates all inference and routing to syni-swift.
/// It handles method channel communication between Flutter and the native SDK.
public class SyniPlugin: NSObject, FlutterPlugin {

    private var isInitialized = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.synheart.syni/sdk",
            binaryMessenger: registrar.messenger()
        )
        let instance = SyniPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(call: call, result: result)
        case "generate":
            handleGenerate(call: call, result: result)
        case "getModels":
            handleGetModels(result: result)
        case "downloadModel":
            handleDownloadModel(call: call, result: result)
        case "deleteModel":
            handleDeleteModel(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Method Handlers

    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let configJson = call.arguments as? String,
              let configData = configJson.data(using: .utf8),
              let configDict = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_REQUEST",
                message: "Invalid configuration JSON",
                details: nil
            ))
            return
        }

        // Build SyniConfig from Flutter config
        let syniConfig = SyniConfig(
            specVersion: configDict["specVersion"] as? String ?? "1.0.0",
            debugLoggingEnabled: configDict["debugLogging"] as? Bool ?? false
        )

        // Initialize SyniSwift SDK
        Task {
            do {
                try await Syni.initialize(config: syniConfig)
                self.isInitialized = true

                // Return version info
                let responseDict: [String: Any] = [
                    "nativeSdkVersion": Syni.version,
                    "specVersion": syniConfig.specVersion
                ]

                if let responseData = try? JSONSerialization.data(withJSONObject: responseDict),
                   let responseJson = String(data: responseData, encoding: .utf8) {
                    DispatchQueue.main.async {
                        result(responseJson)
                    }
                } else {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "PLATFORM_ERROR",
                            message: "Failed to serialize response",
                            details: nil
                        ))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "PLATFORM_ERROR",
                        message: "Failed to initialize SDK: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            }
        }
    }

    private func handleGenerate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(
                code: "INVALID_REQUEST",
                message: "SDK not initialized. Call initialize() first.",
                details: nil
            ))
            return
        }

        guard let requestJson = call.arguments as? String,
              let requestData = requestJson.data(using: .utf8),
              let requestDict = try? JSONSerialization.jsonObject(with: requestData) as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_REQUEST",
                message: "Invalid request JSON",
                details: nil
            ))
            return
        }

        guard let personaId = requestDict["personaId"] as? String,
              let inputText = requestDict["input"] as? String else {
            result(FlutterError(
                code: "INVALID_REQUEST",
                message: "Missing required fields: personaId, input",
                details: nil
            ))
            return
        }

        // Build context from request
        var context: [String: String] = [:]
        if let params = requestDict["parameters"] as? [String: Any] {
            for (key, value) in params {
                if let stringValue = value as? String {
                    context[key] = stringValue
                }
            }
        }

        // Build generation options
        var options: GenerationOptions? = nil
        if let constraints = requestDict["constraints"] as? [String: Any] {
            let localOnly = constraints["offlineOnly"] as? Bool ?? false
            options = GenerationOptions(localOnly: localOnly)
        }

        // Create SyniInput
        let input = SyniInput(text: inputText, context: context)

        // Create SyniRequest
        let syniRequest = SyniRequest(
            personaId: personaId,
            input: input,
            options: options
        )

        // Execute generation
        Task {
            do {
                let response = try await Syni.generate(request: syniRequest)

                // Convert response to Flutter format
                let responseDict: [String: Any] = [
                    "outputJson": response.outputJSON,
                    "meta": [
                        "schemaId": response.metadata.personaId,
                        "personaId": response.metadata.personaId,
                        "engine": response.metadata.engine.rawValue,
                        "durationMs": response.metadata.latencyMs,
                        "isFallback": response.isFallback
                    ]
                ]

                if let responseData = try? JSONSerialization.data(withJSONObject: responseDict),
                   let responseJson = String(data: responseData, encoding: .utf8) {
                    DispatchQueue.main.async {
                        result(responseJson)
                    }
                } else {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "PLATFORM_ERROR",
                            message: "Failed to serialize response",
                            details: nil
                        ))
                    }
                }
            } catch let error as SyniError {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: self.errorCode(for: error),
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "PLATFORM_ERROR",
                        message: "Generation failed: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            }
        }
    }

    private func handleGetModels(result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(
                code: "INVALID_REQUEST",
                message: "SDK not initialized",
                details: nil
            ))
            return
        }

        Task {
            let models = await Syni.getDownloadedModels()

            let modelsArray: [[String: Any]] = models.map { model in
                [
                    "id": model.id,
                    "name": model.name,
                    "sizeBytes": model.sizeBytes
                ]
            }

            if let responseData = try? JSONSerialization.data(withJSONObject: modelsArray),
               let responseJson = String(data: responseData, encoding: .utf8) {
                DispatchQueue.main.async {
                    result(responseJson)
                }
            } else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "PLATFORM_ERROR",
                        message: "Failed to serialize models",
                        details: nil
                    ))
                }
            }
        }
    }

    private func handleDownloadModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(
                code: "INVALID_REQUEST",
                message: "SDK not initialized",
                details: nil
            ))
            return
        }

        guard let argsJson = call.arguments as? String,
              let argsData = argsJson.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
              let modelId = args["modelId"] as? String else {
            result(FlutterError(
                code: "INVALID_REQUEST",
                message: "Missing modelId",
                details: nil
            ))
            return
        }

        Task {
            do {
                try await Syni.downloadModel(id: modelId)
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "PLATFORM_ERROR",
                        message: "Failed to download model: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            }
        }
    }

    private func handleDeleteModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(
                code: "INVALID_REQUEST",
                message: "SDK not initialized",
                details: nil
            ))
            return
        }

        guard let argsJson = call.arguments as? String,
              let argsData = argsJson.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
              let modelId = args["modelId"] as? String else {
            result(FlutterError(
                code: "INVALID_REQUEST",
                message: "Missing modelId",
                details: nil
            ))
            return
        }

        Task {
            do {
                try await Syni.deleteModel(id: modelId)
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "PLATFORM_ERROR",
                        message: "Failed to delete model: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            }
        }
    }

    // MARK: - Helpers

    private func errorCode(for error: SyniError) -> String {
        switch error {
        case .engineUnavailable:
            return "ENGINE_UNAVAILABLE"
        case .personaNotFound:
            return "INVALID_REQUEST"
        case .schemaNotFound, .grammarNotFound:
            return "INVALID_REQUEST"
        case .validationFailed:
            return "SCHEMA_VIOLATION"
        case .timeout:
            return "TIMEOUT"
        case .cancelled:
            return "CANCELLED"
        default:
            return "PLATFORM_ERROR"
        }
    }
}
