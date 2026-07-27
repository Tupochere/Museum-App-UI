package com.example.mtengatenga_ar

import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val tiltChannelName = "mtengatenga_ar/device_tilt"
    private val installerChannelName = "mtengatenga_ar/app_installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            tiltChannelName
        ).setStreamHandler(DeviceTiltStreamHandler(this))

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            installerChannelName
        ).setMethodCallHandler(AppInstallerHandler(this))
    }
}

/**
 * Bridges the in-app updater to Android's package installer.
 *
 * A non-privileged app can never install silently: [installApk] only *launches*
 * the system installer, which always asks the user to confirm. The app's release
 * APKs are signed with the same keystore, so the OS treats them as an update
 * rather than demanding an uninstall.
 */
class AppInstallerHandler(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canInstall" -> result.success(canInstall())
            "openInstallSettings" -> result.success(openInstallSettings())
            "installApk" -> installApk(call.argument<String>("path"), result)
            else -> result.notImplemented()
        }
    }

    /**
     * True when the app may request package installs. Below API 26 there is no
     * per-app grant — the device-wide "unknown sources" toggle governs it — so
     * report true and let the installer surface any refusal itself.
     */
    private fun canInstall(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        return context.packageManager.canRequestPackageInstalls()
    }

    /** Deep-links to this app's "Install unknown apps" screen. */
    private fun openInstallSettings(): Boolean {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${context.packageName}")
                )
            } else {
                Intent(Settings.ACTION_SECURITY_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (error: Exception) {
            false
        }
    }

    private fun installApk(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("INVALID_PATH", "APK path is empty.", null)
            return
        }

        val apk = File(path)
        if (!apk.exists() || apk.length() <= 0L) {
            result.error("MISSING_APK", "APK file was not found at $path.", null)
            return
        }

        try {
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.updateprovider",
                apk
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(true)
        } catch (error: Exception) {
            result.error(
                "INSTALL_FAILED",
                error.message ?: "Could not open the package installer.",
                null
            )
        }
    }
}

class DeviceTiltStreamHandler(
    context: Context
) : EventChannel.StreamHandler, SensorEventListener {
    private val sensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val accelerometer =
        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events

        if (accelerometer == null) {
            events?.error("NO_ACCELEROMETER", "Accelerometer is not available.", null)
            return
        }

        sensorManager.registerListener(
            this,
            accelerometer,
            SensorManager.SENSOR_DELAY_UI
        )
    }

    override fun onCancel(arguments: Any?) {
        sensorManager.unregisterListener(this)
        eventSink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return

        val x = event.values[0].toDouble()
        val y = event.values[1].toDouble()
        val z = event.values[2].toDouble()
        val horizontalStrength = kotlin.math.abs(z)
        val uprightStrength = kotlin.math.sqrt((x * x) + (y * y))
        val isFlat = horizontalStrength >= 7.0 && uprightStrength <= 6.5

        eventSink?.success(
            mapOf(
                "x" to x,
                "y" to y,
                "z" to z,
                "isFlat" to isFlat
            )
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
