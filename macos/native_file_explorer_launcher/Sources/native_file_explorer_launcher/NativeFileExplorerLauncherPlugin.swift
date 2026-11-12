import AppKit
import FlutterMacOS
import UniformTypeIdentifiers

public final class NativeFileExplorerLauncherPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    LauncherApiSetup.setUp(binaryMessenger: registrar.messenger, api: Launcher())
  }
}

/// The macOS side of the Dart API. Pigeon calls it on the main actor and
/// sends the reply from there; the async methods themselves run off it.
final class Launcher: LauncherApi {
  /// Icons larger than this only cost memory: menus never draw them that big.
  static let maxIconSize = 1024

  func showInFileExplorer(path: String) async throws {
    let url = try existingFile(at: path)
    await MainActor.run {
      NSWorkspace.shared.activateFileViewerSelecting([url])
    }
  }

  func openFile(path: String, applicationId: String?) async throws {
    let url = try existingFile(at: path)
    let workspace = NSWorkspace.shared
    let configuration = NSWorkspace.OpenConfiguration()
    do {
      if let applicationId {
        let appURL = URL(fileURLWithPath: applicationId)
        guard FileManager.default.fileExists(atPath: appURL.path) else {
          throw LauncherError.applicationNotFound("No app at \(applicationId)")
        }
        _ = try await workspace.open([url], withApplicationAt: appURL, configuration: configuration)
      } else {
        guard workspace.urlForApplication(toOpen: url) != nil else {
          throw LauncherError.applicationNotFound("No app opens \(url.lastPathComponent)")
        }
        _ = try await workspace.open(url, configuration: configuration)
      }
    } catch let error as PigeonError {
      throw error
    } catch {
      throw LauncherError.failed(error.localizedDescription)
    }
  }

  func getApplications(fileName: String, iconSize: Int64) async throws -> [PlatformApplication] {
    let fileExtension = (fileName as NSString).pathExtension
    guard !fileExtension.isEmpty, let type = UTType(filenameExtension: fileExtension) else {
      return []
    }
    let workspace = NSWorkspace.shared
    let defaultPath = workspace.urlForApplication(toOpen: type)?.standardizedFileURL.path
    let size = min(max(Int(clamping: iconSize), 1), Self.maxIconSize)

    return workspace.urlsForApplications(toOpen: type).map { appURL in
      let path = appURL.standardizedFileURL.path
      return PlatformApplication(
        id: path,
        name: displayName(ofAppAt: appURL),
        isDefault: path == defaultPath,
        icon: icon(ofAppAt: path, size: size).map { FlutterStandardTypedData(bytes: $0) }
      )
    }
  }
}

enum LauncherError {
  static func fileNotFound(_ message: String) -> PigeonError {
    PigeonError(code: "fileNotFound", message: message, details: nil)
  }

  static func applicationNotFound(_ message: String) -> PigeonError {
    PigeonError(code: "applicationNotFound", message: message, details: nil)
  }

  static func failed(_ message: String) -> PigeonError {
    PigeonError(code: "failed", message: message, details: nil)
  }
}

/// Only reports missing files as missing. A sandboxed app may not be allowed
/// to look at a path it can still ask Finder to show.
func existingFile(at path: String) throws -> URL {
  if access(path, F_OK) != 0 && (errno == ENOENT || errno == ENOTDIR) {
    throw LauncherError.fileNotFound("No file at \(path)")
  }
  return URL(fileURLWithPath: path)
}

/// The name Finder shows, in the user's language, without ".app".
func displayName(ofAppAt url: URL) -> String {
  let name = (try? url.resourceValues(forKeys: [.localizedNameKey]))?.localizedName
    ?? url.lastPathComponent
  return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
}

/// Draws the app icon at exactly `size` pixels, instead of encoding all of
/// its representations up to 1024 pixels.
func icon(ofAppAt path: String, size: Int) -> Data? {
  guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
  ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    return nil
  }
  let image = NSWorkspace.shared.icon(forFile: path)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
  NSGraphicsContext.restoreGraphicsState()
  return bitmap.representation(using: .png, properties: [:])
}
