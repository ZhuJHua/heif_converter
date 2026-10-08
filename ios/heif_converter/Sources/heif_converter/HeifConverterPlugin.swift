import Flutter
import ImageIO
import UIKit

public class HeifConverterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "heif_converter", binaryMessenger: registrar.messenger())
    let instance = HeifConverterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "convert":
      guard let input = call.arguments as? Dictionary<String, Any>,
            let path = input["path"] as? String else {
        result(FlutterError(code: "illegalArgument", message: "Invalid arguments.", details: nil))
        return
      }
      var output: String?
      if let o = input["output"] as? String, !o.isEmpty {
        output = o
      }
      var format: String?
      if let f = input["format"] as? String, !f.isEmpty {
        format = f
      }
      if output == nil {
        if let fmt = format {
          output = NSTemporaryDirectory().appendingFormat("%d.%@", Int(Date().timeIntervalSince1970 * 1000), fmt)
        } else {
          result(FlutterError(code: "illegalArgument", message: "Output path and format is blank.", details: nil))
          return
        }
      }
      let converted = convert(path: path, output: output!)
      if converted == nil {
        result(FlutterError(code: "conversionFailed", message: "Failed to convert image: \(path)", details: nil))
      } else {
        result(converted)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func convert(path: String, output: String) -> String? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
      return nil
    }
    let index = CGImageSourceGetPrimaryImageIndex(source)
    let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
    var orientation = sourceProperties[kCGImagePropertyOrientation] as? Int ?? 1
    let isJpeg = output.hasSuffix(".jpg") || output.hasSuffix(".jpeg")
    let image: CGImage?
    if isJpeg || orientation == 1 {
      // JPEG keeps the stored pixels and records the orientation in EXIF.
      image = CGImageSourceCreateImageAtIndex(source, index, nil)
    } else {
      // Most PNG decoders (including Flutter's) ignore the orientation in PNG metadata, so rotate
      // the pixels instead. With no max pixel size set, the "thumbnail" is the full-size image.
      image = CGImageSourceCreateThumbnailAtIndex(source, index, [
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
      ] as CFDictionary)
      orientation = 1
    }
    var properties: [CFString: Any] = [kCGImagePropertyOrientation: orientation]
    if isJpeg {
      properties[kCGImageDestinationLossyCompressionQuality] = 1.0
    }
    let data = NSMutableData()
    guard let cgImage = image,
          let destination = CGImageDestinationCreateWithData(
            data, (isJpeg ? "public.jpeg" : "public.png") as CFString, 1, nil) else {
      return nil
    }
    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      return nil
    }
    let outputURL = URL(fileURLWithPath: output)
    let parentURL = outputURL.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: parentURL.path) {
      try? FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
    }
    FileManager.default.createFile(atPath: output, contents: data as Data, attributes: nil)
    return output
  }
}
