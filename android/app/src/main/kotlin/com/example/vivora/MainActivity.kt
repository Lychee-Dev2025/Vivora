package com.example.vivora

import com.example.vivora.activitymonitoring.ActivityMonitoringBridge
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private var activityMonitoringBridge: ActivityMonitoringBridge? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		activityMonitoringBridge = ActivityMonitoringBridge(this, this)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vivora/activity_monitoring")
			.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
				val bridge = activityMonitoringBridge
				if (bridge == null) {
					result.error("bridge_unavailable", "Activity bridge is not ready.", null)
					return@setMethodCallHandler
				}

				when (call.method) {
					"getPermissionSnapshot" -> result.success(bridge.getPermissionSnapshot())
					"getSyncMetadata" -> result.success(bridge.getSyncMetadata())
					"saveSyncMetadata" -> {
						@Suppress("UNCHECKED_CAST")
						val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
						bridge.saveSyncMetadata(arguments)
						result.success(null)
					}

					"openUsageAccessSettings" -> {
						bridge.openUsageAccessSettings()
						result.success(null)
					}

					"requestActivityPermission" -> {
						bridge.requestActivityPermission(
							onGranted = { result.success(true) },
							onDenied = { result.success(false) },
						)
					}

					"scheduleBackgroundSync" -> bridge.scheduleBackgroundSync { scheduled -> result.success(scheduled) }
					"removeBackgroundSync" -> {
						bridge.removeBackgroundSync()
						result.success(null)
					}
					"captureActivityRange" -> {
						@Suppress("UNCHECKED_CAST")
						val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
						val startMillis = (arguments["startMillis"] as? Number)?.toLong() ?: 0L
						val endMillis = (arguments["endMillis"] as? Number)?.toLong() ?: 0L
						result.success(bridge.captureActivityRange(startMillis, endMillis))
					}

					"getUsageDiagnostics" -> {
						@Suppress("UNCHECKED_CAST")
						val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
						val startMillis = (arguments["startMillis"] as? Number)?.toLong() ?: 0L
						val endMillis = (arguments["endMillis"] as? Number)?.toLong() ?: 0L
						result.success(bridge.getUsageDiagnostics(startMillis, endMillis))
					}

					else -> result.notImplemented()
				}
			}
	}

	override fun onRequestPermissionsResult(
		requestCode: Int,
		permissions: Array<out String>,
		grantResults: IntArray,
	) {
		if (activityMonitoringBridge?.onRequestPermissionsResult(requestCode, grantResults) == true) {
			return
		}
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)
	}
}
