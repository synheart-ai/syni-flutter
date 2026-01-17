import Flutter
import UIKit

/// Flutter plugin for Syni SDK on iOS.
///
/// This plugin delegates all inference and routing to syni-swift.
/// It handles method channel communication between Flutter and the native SDK.
public class SyniPlugin: NSObject, FlutterPlugin {

    /// The native Syni SDK instance (from syni-swift).
    /// This should be replaced with actual syni-swift import when integrated.
    // private var syniSDK: SyniSDK?

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
              let config = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_REQUEST",
                message: "Invalid configuration JSON",
                details: nil
            ))
            return
        }

        // TODO: Initialize syni-swift SDK with config
        // syniSDK = SyniSDK(config: config)

        isInitialized = true

        // Return version info
        let responseDict: [String: Any] = [
            "nativeSdkVersion": "1.2.0", // TODO: Get from syni-swift
            "specVersion": "1.1.0"       // TODO: Get from syni-swift
        ]

        if let responseData = try? JSONSerialization.data(withJSONObject: responseDict),
           let responseJson = String(data: responseData, encoding: .utf8) {
            result(responseJson)
        } else {
            result(FlutterError(
                code: "PLATFORM_ERROR",
                message: "Failed to serialize response",
                details: nil
            ))
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
              let request = try? JSONSerialization.jsonObject(with: requestData) as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_REQUEST",
                message: "Invalid request JSON",
                details: nil
            ))
            return
        }

        // TODO: Delegate to syni-swift for actual inference
        // syniSDK?.generate(request: request) { response, error in
        //     if let error = error {
        //         result(FlutterError(...))
        //         return
        //     }
        //     result(response)
        // }

        // Placeholder response for testing
        let personaId = request["personaId"] as? String ?? "unknown"
        let responseDict: [String: Any] = [
            "outputJson": [
                "suggestions": [
                    ["text": "Hello!", "confidence": 0.95],
                    ["text": "Hi there!", "confidence": 0.85],
                    ["text": "Hey!", "confidence": 0.75]
                ]
            ],
            "meta": [
                "schemaId": "keyboard.suggestions.v1",
                "personaId": personaId,
                "engine": "local",
                "durationMs": 50,
                "isFallback": false
            ]
        ]

        if let responseData = try? JSONSerialization.data(withJSONObject: responseDict),
           let responseJson = String(data: responseData, encoding: .utf8) {
            result(responseJson)
        } else {
            result(FlutterError(
                code: "PLATFORM_ERROR",
                message: "Failed to serialize response",
                details: nil
            ))
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

        // TODO: Get models from syni-swift
        let models: [[String: Any]] = []

        if let responseData = try? JSONSerialization.data(withJSONObject: models),
           let responseJson = String(data: responseData, encoding: .utf8) {
            result(responseJson)
        } else {
            result(FlutterError(
                code: "PLATFORM_ERROR",
                message: "Failed to serialize models",
                details: nil
            ))
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

        // TODO: Delegate to syni-swift
        result(nil)
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

        // TODO: Delegate to syni-swift
        result(nil)
    }
}
