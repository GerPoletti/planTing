package __PACKAGE__

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Lee el sensor de luz ambiente del teléfono y lo entrega a Flutter en lux. */
class MirasolLightPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    SensorEventListener {

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sensorManager: SensorManager? = null
    private var sink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        sensorManager =
            binding.applicationContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        methodChannel = MethodChannel(binding.binaryMessenger, "mirasol_light/method").also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(binding.binaryMessenger, "mirasol_light/lux").also {
            it.setStreamHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        stop()
        sensorManager = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sensorInfo" -> {
                val sensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LIGHT)
                result.success(
                    mapOf(
                        "available" to (sensor != null),
                        "maxRange" to (sensor?.maximumRange?.toDouble() ?: 0.0),
                    ),
                )
            }
            "cancelMeasure" -> {
                // En Android la medición es el flujo de lecturas: al cancelar la
                // suscripción se llama a onCancel. Esto asegura que el sensor se apague.
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val sensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LIGHT)
        if (sensor == null) {
            events?.error("NO_SENSOR", "Este teléfono no tiene sensor de luz", null)
            return
        }
        sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        stop()
        sink = null
    }

    private fun stop() {
        sensorManager?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_LIGHT) {
            sink?.success(event.values[0].toDouble())
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
