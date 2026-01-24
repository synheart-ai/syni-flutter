package com.synheart.syni

import android.content.Context
import com.syni.sdk.Syni
import com.syni.sdk.core.EngineType
import com.syni.sdk.core.GenerationOptions
import com.syni.sdk.core.SyniConfig
import com.syni.sdk.core.SyniError
import com.syni.sdk.core.SyniInput
import com.syni.sdk.core.SyniRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

/**
 * Flutter plugin for Syni SDK on Android.
 *
 * This plugin delegates all inference and routing to syni-kotlin.
 * It handles method channel communication between Flutter and the native SDK.
 */
class SyniPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var isInitialized = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.synheart.syni/sdk")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> handleInitialize(call, result)
            "generate" -> handleGenerate(call, result)
            "getModels" -> handleGetModels(result)
            "downloadModel" -> handleDownloadModel(call, result)
            "deleteModel" -> handleDeleteModel(call, result)
            else -> result.notImplemented()
        }
    }

    // MARK: - Method Handlers

    private fun handleInitialize(call: MethodCall, result: Result) {
        val configJson = call.arguments as? String
        if (configJson == null) {
            result.error("INVALID_REQUEST", "Invalid configuration JSON", null)
            return
        }

        try {
            val configObj = JSONObject(configJson)

            // Build SyniConfig from Flutter config
            val syniConfig = SyniConfig(
                specVersion = configObj.optString("specVersion", "1.0.0"),
                debug = configObj.optBoolean("debugLogging", false)
            )

            // Initialize syni-kotlin SDK
            Syni.initialize(context, syniConfig)
            isInitialized = true

            // Return version info
            val response = JSONObject().apply {
                put("nativeSdkVersion", Syni.version)
                put("specVersion", syniConfig.specVersion)
            }

            result.success(response.toString())
        } catch (e: Exception) {
            result.error("PLATFORM_ERROR", "Failed to initialize: ${e.message}", null)
        }
    }

    private fun handleGenerate(call: MethodCall, result: Result) {
        if (!isInitialized) {
            result.error("INVALID_REQUEST", "SDK not initialized. Call initialize() first.", null)
            return
        }

        val requestJson = call.arguments as? String
        if (requestJson == null) {
            result.error("INVALID_REQUEST", "Invalid request JSON", null)
            return
        }

        scope.launch {
            try {
                val requestObj = JSONObject(requestJson)

                val personaId = requestObj.optString("personaId")
                val inputText = requestObj.optString("input")

                if (personaId.isNullOrEmpty() || inputText.isNullOrEmpty()) {
                    result.error("INVALID_REQUEST", "Missing required fields: personaId, input", null)
                    return@launch
                }

                // Build context from request parameters
                val contextMap = mutableMapOf<String, String>()
                val params = requestObj.optJSONObject("parameters")
                if (params != null) {
                    params.keys().forEach { key ->
                        val value = params.opt(key)
                        if (value is String) {
                            contextMap[key] = value
                        }
                    }
                }

                // Build generation options
                val constraints = requestObj.optJSONObject("constraints")
                val options = if (constraints != null) {
                    GenerationOptions(
                        localOnly = constraints.optBoolean("offlineOnly", false),
                        cloudOnly = false
                    )
                } else {
                    GenerationOptions.DEFAULT
                }

                // Create SyniInput
                val input = SyniInput(
                    text = inputText,
                    context = contextMap
                )

                // Create SyniRequest
                val syniRequest = SyniRequest(
                    personaId = personaId,
                    input = input,
                    options = options
                )

                // Execute generation
                val syniResult = Syni.generate(syniRequest)

                when (syniResult) {
                    is com.syni.sdk.core.SyniResult.Success -> {
                        val response = syniResult.value

                        // Convert outputJSON to JSONObject
                        val outputJson = JSONObject(response.outputString())

                        val meta = JSONObject().apply {
                            put("schemaId", response.metadata.schemaId ?: response.metadata.personaId)
                            put("personaId", response.metadata.personaId)
                            put("engine", response.metadata.engine.name.lowercase())
                            put("durationMs", response.metadata.latencyMs)
                            put("isFallback", response.isFallback)
                        }

                        val responseObj = JSONObject().apply {
                            put("outputJson", outputJson)
                            put("meta", meta)
                        }

                        result.success(responseObj.toString())
                    }
                    is com.syni.sdk.core.SyniResult.Failure -> {
                        val error = syniResult.error
                        result.error(
                            errorCode(error),
                            error.message ?: "Generation failed",
                            null
                        )
                    }
                }
            } catch (e: SyniError) {
                result.error(errorCode(e), e.message ?: "Generation failed", null)
            } catch (e: Exception) {
                result.error("PLATFORM_ERROR", "Generation failed: ${e.message}", null)
            }
        }
    }

    private fun handleGetModels(result: Result) {
        if (!isInitialized) {
            result.error("INVALID_REQUEST", "SDK not initialized", null)
            return
        }

        try {
            val models = Syni.getDownloadedModels()

            val modelsArray = JSONArray()
            models.forEach { model ->
                modelsArray.put(JSONObject().apply {
                    put("id", model.id)
                    put("name", model.name)
                    put("sizeBytes", model.sizeBytes)
                })
            }

            result.success(modelsArray.toString())
        } catch (e: Exception) {
            result.error("PLATFORM_ERROR", "Failed to get models: ${e.message}", null)
        }
    }

    private fun handleDownloadModel(call: MethodCall, result: Result) {
        if (!isInitialized) {
            result.error("INVALID_REQUEST", "SDK not initialized", null)
            return
        }

        val argsJson = call.arguments as? String
        if (argsJson == null) {
            result.error("INVALID_REQUEST", "Invalid arguments", null)
            return
        }

        scope.launch {
            try {
                val args = JSONObject(argsJson)
                val modelId = args.optString("modelId")

                if (modelId.isNullOrEmpty()) {
                    result.error("INVALID_REQUEST", "Missing modelId", null)
                    return@launch
                }

                // Download model - collect flow to completion
                Syni.downloadModel(
                    url = "", // URL would come from model registry
                    modelId = modelId
                ).collect { progress ->
                    // Could emit progress events here if needed
                }

                result.success(null)
            } catch (e: Exception) {
                result.error("PLATFORM_ERROR", "Failed to download model: ${e.message}", null)
            }
        }
    }

    private fun handleDeleteModel(call: MethodCall, result: Result) {
        if (!isInitialized) {
            result.error("INVALID_REQUEST", "SDK not initialized", null)
            return
        }

        val argsJson = call.arguments as? String
        if (argsJson == null) {
            result.error("INVALID_REQUEST", "Invalid arguments", null)
            return
        }

        scope.launch {
            try {
                val args = JSONObject(argsJson)
                val modelId = args.optString("modelId")

                if (modelId.isNullOrEmpty()) {
                    result.error("INVALID_REQUEST", "Missing modelId", null)
                    return@launch
                }

                Syni.deleteModel(modelId)
                result.success(null)
            } catch (e: Exception) {
                result.error("PLATFORM_ERROR", "Failed to delete model: ${e.message}", null)
            }
        }
    }

    // MARK: - Helpers

    private fun errorCode(error: SyniError): String {
        return when (error) {
            is SyniError.EngineUnavailable -> "ENGINE_UNAVAILABLE"
            is SyniError.PersonaNotFound -> "INVALID_REQUEST"
            is SyniError.SchemaNotFound -> "INVALID_REQUEST"
            is SyniError.GrammarNotFound -> "INVALID_REQUEST"
            is SyniError.ValidationFailed -> "SCHEMA_VIOLATION"
            is SyniError.Timeout -> "TIMEOUT"
            is SyniError.Cancelled -> "CANCELLED"
            else -> "PLATFORM_ERROR"
        }
    }
}
