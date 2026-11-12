import Cocoa
import FlutterMacOS
import Foundation
import CoreServices
import UniformTypeIdentifiers

public class NativeFileExplorerLauncherPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "native_file_explorer_launcher", binaryMessenger: registrar.messenger)
    let instance = NativeFileExplorerLauncherPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }


  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      let arguments = call.arguments as! Dictionary<String, Any>
      let filePath = arguments["filePath"] as? String
      let applicationPath = arguments["applicationPath"] as? String
      guard let filePath = filePath, let fileURL = URL(fileURLWithPath: filePath) as URL? else {
          result(invalidFilePath(filePath))
          return
      }
      
      switch call.method {
      case "showFileInNativeFileExplorer":
          showFileInNativeFileExplorer(fileURL, result: result)
      case "launchFile":
          launchFile(fileURL, applicationURL: applicationPath != nil ? URL(string: applicationPath!) : nil,  result: result)
      case "getSupportedApplications":
          getSupportedApplications(fileURL, result: result)
      default:
          result(FlutterMethodNotImplemented)
    }
  }
}

private func showFileInNativeFileExplorer(_ fileURL: URL, result: @escaping FlutterResult) {
    result(NSWorkspace.shared.selectFile(fileURL.path , inFileViewerRootedAtPath: ""))
}

private func launchFile(_ fileURL: URL, applicationURL: URL? = nil, result: @escaping FlutterResult) {
    //TODO figure out a way to preselct directory in order to make it a user-selected directory so as to have acces to it
    // let savePanel = NSOpenPanel()
    // let launcherLogPathWithTilde = "~/Users/apoorv/learning_course" as NSString
    // let expandedLauncherLogPath = launcherLogPathWithTilde.expandingTildeInPath
    // savePanel.directoryURL = NSURL.fileURL(withPath: expandedLauncherLogPath, isDirectory: true)
    // savePanel.directoryURL = FileManager.homeDirectoryForCurrentUser
    // savePanel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
    if let applicationURL = applicationURL {
        if #available(macOS 10.15, *) {
            NSWorkspace.shared.open([fileURL], withApplicationAt: applicationURL, configuration: NSWorkspace.OpenConfiguration()) { _, err in
                if let err = err {
                    result(FlutterError(code: "argument_error", message: err.localizedDescription, details: nil))
                    return
                }
                result(true)
            }
        } else {
            // fallback for earlier macOS versions
            let fileCFArray = [fileURL] as CFArray
            let unmanagedFileCFArray = Unmanaged<CFArray>.passUnretained(fileCFArray)
            let appCFURL = applicationURL as CFURL
            let unmanagedAppURL = Unmanaged<CFURL>.passUnretained(appCFURL)
            var launchURLSpec = LSLaunchURLSpec(appURL: unmanagedAppURL, itemURLs: unmanagedFileCFArray, passThruParams: nil, launchFlags: .defaults, asyncRefCon: nil)
            
            var outLaunchedURL: UnsafeMutablePointer<Unmanaged<CFURL>?>?
            LSOpenFromURLSpec(&launchURLSpec, outLaunchedURL)
            
            if let _ = outLaunchedURL {
                result(false)
                return
            }
            result(true)
        }
        
        return
    }
    
    result(NSWorkspace.shared.open(fileURL))
}

/// Returns a list of supported applications which can open the desired file.
///
/// the return type is a list of dictionaries which has the following format:
/// {
///     "name": String
///     "url": String
///     "icon": Data
/// }
private func getSupportedApplications(_ fileURL: URL, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInteractive).async {
        let fileExtension = fileURL.pathExtension
        if fileExtension.isEmpty {
            result(nil)
            return
        }
        
        var uniformIdentifier: String
        if #available(macOS 11.0, *) {
            guard let uti = UTTypeReference(filenameExtension: fileExtension) else {
                result(nil)
                return
            }
            uniformIdentifier = uti.identifier
        } else {
            guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension as CFString, nil) else {
                result(nil)
                return
            }
            uniformIdentifier = uti.takeRetainedValue() as String
        }
        
        guard let list = LSCopyAllRoleHandlersForContentType(uniformIdentifier as CFString, .all)?.takeRetainedValue() as? Array<String> else {
            result(nil)
            return
        }
        
        var apps: [[String: Any]] = []
        for bundleId in list {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                continue
            }
            
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            guard let bundle = Bundle(url: url), let icon = icon.png else {
                continue
            }
            
            var applicationName = url.lastPathComponent
            let bundleDisplayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            if let bundleDisplayName = bundleDisplayName {
                applicationName = bundleDisplayName
            } else if let bundleName = bundleName {
                applicationName = bundleName
            }
            
            let thisApp: [String : Any] = ["name": applicationName, "url": url.absoluteString, "icon": icon]
            apps.append(thisApp)
        }
        
        result(apps)
    }
}

/// Returns an error for the case where, provided, filePath string can't be parsed as a URL.
private func invalidFilePath(_ filePath: String?) -> FlutterError {
    return FlutterError(code: "argument_error", message: "Unable to parse file path as URL", details: "file Path provided: \(String(describing: filePath))")
}

