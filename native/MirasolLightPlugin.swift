import Flutter
import UIKit
import AVFoundation

/// Estima la luz en iPhone con los parámetros de exposición de la cámara.
/// La imagen se procesa en el momento y no se guarda ni se envía.
/// Fórmula: lux ≈ 250 · N² / (t · ISO), con N la apertura, t el tiempo de
/// exposición en segundos e ISO la sensibilidad.
public class MirasolLightPlugin: NSObject, FlutterPlugin, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var session: AVCaptureSession?
    private var device: AVCaptureDevice?
    private let queue = DispatchQueue(label: "mirasol.light.camera")
    private var samples: [Double] = []
    private var saturatedCount = 0
    private var pending: FlutterResult?
    private var startTime = Date()
    /// Sube con cada medición, para que un temporizador viejo no cierre una nueva.
    private var generation = 0

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "mirasol_light/method", binaryMessenger: registrar.messenger())
        let instance = MirasolLightPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "sensorInfo":
            // En iPhone no se puede leer el sensor de luz: se usa la cámara.
            result(["available": false, "maxRange": 0.0])
        case "requestCameraAccess":
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { result(granted) }
            }
        case "measureWithCamera":
            let args = call.arguments as? [String: Any]
            let seconds = (args?["seconds"] as? NSNumber)?.doubleValue ?? 5.0
            measure(seconds: seconds, result: result)
        case "cancelMeasure":
            cancel()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func measure(seconds: Double, result: @escaping FlutterResult) {
        if pending != nil {
            result(FlutterError(code: "BUSY", message: "Ya hay una medición en curso", details: nil))
            return
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            result(FlutterError(code: "NO_PERMISSION", message: "Falta el permiso de la cámara", details: nil))
            return
        }
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: dev) else {
            result(FlutterError(code: "NO_CAMERA", message: "No se pudo abrir la cámara", details: nil))
            return
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        self.session = session
        self.device = dev
        self.samples = []
        self.saturatedCount = 0
        self.pending = result
        self.startTime = Date()
        self.generation += 1
        let current = self.generation

        queue.async { session.startRunning() }
        // El primer segundo se descarta mientras la exposición automática se acomoda.
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds + 1.0) { [weak self] in
            guard let self = self, self.generation == current else { return }
            self.finish()
        }
    }

    /// Corta la medición en curso: apaga la cámara y responde CANCELLED.
    private func cancel() {
        generation += 1
        queue.async { [weak self] in
            guard let self = self, let reply = self.pending else { return }
            self.session?.stopRunning()
            self.session = nil
            self.device = nil
            self.pending = nil
            DispatchQueue.main.async {
                reply(FlutterError(code: "CANCELLED", message: "Medición cancelada", details: nil))
            }
        }
    }

    private func finish() {
        queue.async { [weak self] in
            guard let self = self, let reply = self.pending else { return }
            self.session?.stopRunning()
            self.session = nil
            self.device = nil
            self.pending = nil

            let count = self.samples.count
            if count == 0 {
                DispatchQueue.main.async {
                    reply(FlutterError(code: "NO_SAMPLES", message: "No se obtuvieron datos de la cámara", details: nil))
                }
                return
            }
            let sorted = self.samples.sorted()
            let median = sorted[count / 2]
            let saturated = Double(self.saturatedCount) / Double(count) > 0.5
            DispatchQueue.main.async {
                reply(["lux": median, "samples": count, "saturated": saturated])
            }
        }
    }

    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard let dev = device, Date().timeIntervalSince(startTime) > 1.0 else { return }
        let t = CMTimeGetSeconds(dev.exposureDuration)
        let iso = Double(dev.iso)
        let n = Double(dev.lensAperture)
        if t <= 0 || iso <= 0 || n <= 0 { return }

        samples.append(250.0 * n * n / (t * iso))

        let format = dev.activeFormat
        if t <= CMTimeGetSeconds(format.minExposureDuration) * 1.05 &&
            iso <= Double(format.minISO) * 1.05 {
            saturatedCount += 1
        }
    }
}
