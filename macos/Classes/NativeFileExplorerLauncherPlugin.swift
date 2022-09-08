import Cocoa
import FlutterMacOS
import Foundation

public class NativeFileExplorerLauncherPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "native_file_explorer_launcher", binaryMessenger: registrar.messenger)
    let instance = NativeFileExplorerLauncherPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }


  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let filePath: String? = (call.arguments as? [String: Any])?["filePath"] as? String
     guard let unwarappedFilePathString = filePath, 
        let fileURL: URL = URL.init(fileURLWithPath: unwarappedFilePathString) as URL?
      else {
        result(invalidFilePath(filePath))
        return
      }
    switch call.method {
    case "showFileInNativeFileExplorer":
      result(NSWorkspace.shared.selectFile(fileURL.path , inFileViewerRootedAtPath: ""))
    case "launchFile":
      //TODO figure out a way to preselct directory in order to make it a user-selected directory so as to have acces to it
      // let savePanel = NSOpenPanel()
      // let launcherLogPathWithTilde = "~/Users/apoorv/learning_course" as NSString
      // let expandedLauncherLogPath = launcherLogPathWithTilde.expandingTildeInPath
      // savePanel.directoryURL = NSURL.fileURL(withPath: expandedLauncherLogPath, isDirectory: true)
      // savePanel.directoryURL = FileManager.homeDirectoryForCurrentUser
      // savePanel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
      result(NSWorkspace.shared.open(fileURL)) 
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Returns an error for the case where, provided, filePath string can't be parsed as a URL.
private func invalidFilePath(_ filePath: String?)  -> FlutterError{
  return FlutterError(
    code: "argument_error",
    message: "Unable to parse file path as URL",
    details: "file Path provided: \(String(describing: filePath))")
}

