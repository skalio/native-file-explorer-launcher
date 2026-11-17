import AppKit
import Testing

@testable import native_file_explorer_launcher

/// Runs against the real system, but never opens an app or a Finder window.
struct LauncherTests {
  let launcher = Launcher()

  @Test func listsTextEditForTextFiles() async throws {
    let apps = try await launcher.getApplications(fileName: "notes.txt", iconSize: 64)
    let textEdit = try #require(apps.first { $0.id.hasSuffix("/TextEdit.app") })
    #expect(textEdit.name == displayName(ofAppAt: URL(fileURLWithPath: textEdit.id)))
    #expect(!textEdit.name.hasSuffix(".app"))
  }

  @Test func marksExactlyOneDefaultApp() async throws {
    let apps = try await launcher.getApplications(fileName: "notes.txt", iconSize: 16)
    #expect(apps.filter(\.isDefault).count == 1)
  }

  @Test func listsEachAppOnce() async throws {
    let apps = try await launcher.getApplications(fileName: "notes.txt", iconSize: 16)
    let bundleIds = apps.compactMap { Bundle(path: $0.id)?.bundleIdentifier }
    #expect(bundleIds.count == Set(bundleIds).count)
  }

  @Test func onlyUsesTheExtension() async throws {
    let byName = try await launcher.getApplications(fileName: "notes.TXT", iconSize: 16)
    let byPath = try await launcher.getApplications(fileName: "/does/not/exist.txt", iconSize: 16)
    #expect(Set(byName.map(\.id)) == Set(byPath.map(\.id)))
  }

  @Test(arguments: [16, 64, 128])
  func drawsIconsAtTheRequestedSize(size: Int) async throws {
    let apps = try await launcher.getApplications(fileName: "notes.txt", iconSize: Int64(size))
    let icon = try #require(apps.first?.icon)
    let bitmap = try #require(NSBitmapImageRep(data: icon.data))
    #expect(bitmap.pixelsWide == size)
    #expect(bitmap.pixelsHigh == size)
  }

  @Test func capsHugeIcons() async throws {
    let apps = try await launcher.getApplications(fileName: "notes.txt", iconSize: 100_000)
    let bitmap = try #require(apps.first?.icon.flatMap { NSBitmapImageRep(data: $0.data) })
    #expect(bitmap.pixelsWide == Launcher.maxIconSize)
  }

  @Test(arguments: ["Makefile", "", "a.zzqx-unknown"])
  func returnsNoAppsForUnknownTypes(fileName: String) async throws {
    #expect(try await launcher.getApplications(fileName: fileName, iconSize: 16).isEmpty)
  }

  @Test func showInFileExplorerReportsMissingFiles() async {
    await expectError("fileNotFound") {
      try await launcher.showInFileExplorer(path: "/does/not/exist.txt")
    }
  }

  @Test func openFileReportsMissingFiles() async {
    await expectError("fileNotFound") {
      try await launcher.openFile(path: "/does/not/exist.txt", applicationId: nil)
    }
  }

  @Test func openFileReportsMissingApps() async throws {
    let file = try temporaryFile(named: "notes.txt")
    await expectError("applicationNotFound") {
      try await launcher.openFile(path: file.path, applicationId: "/Applications/Gone.app")
    }
  }

  @Test func openFileReportsFilesNoAppOpens() async throws {
    let file = try temporaryFile(named: "data.zzqx-unknown")
    await expectError("applicationNotFound") {
      try await launcher.openFile(path: file.path, applicationId: nil)
    }
  }

  @Test func treatsUnreadablePathsAsExisting() throws {
    // Outside the sandbox container: may be unreadable, but it is not missing.
    #expect(throws: Never.self) { try existingFile(at: "/System/Applications/TextEdit.app") }
    #expect(throws: PigeonError.self) { try existingFile(at: "/does/not/exist") }
    #expect(throws: PigeonError.self) { try existingFile(at: "/etc/hosts/below-a-file") }
  }
}

/// Fakes the app copies an updater leaves around, which CI Macs do not have.
struct OneCopyPerAppTests {
  let app = URL(fileURLWithPath: "/Applications/Edge.app")
  let updaterCopy = URL(fileURLWithPath: "/Users/me/Library/EdgeUpdater/Edge.app")
  let other = URL(fileURLWithPath: "/Applications/Other.app")
  let noBundle = URL(fileURLWithPath: "/Applications/Script.app")

  func bundleId(_ url: URL) -> String? {
    switch url {
    case app, updaterCopy: "com.example.edge"
    case other: "com.example.other"
    default: nil
    }
  }

  @Test func keepsTheCopyMacOSWouldLaunch() {
    let apps = oneCopyPerApp(
      [updaterCopy, other, app], defaultPath: nil,
      bundleId: bundleId, preferredCopy: { $0 == "com.example.edge" ? app : nil })
    #expect(apps == [app, other])
  }

  @Test func prefersTheDefaultCopy() {
    let apps = oneCopyPerApp(
      [app, updaterCopy], defaultPath: updaterCopy.path,
      bundleId: bundleId, preferredCopy: { _ in app })
    #expect(apps == [updaterCopy])
  }

  @Test func keepsAppsWithoutBundleIdAndUnknownCopies() {
    let apps = oneCopyPerApp(
      [noBundle, updaterCopy, app], defaultPath: nil,
      bundleId: bundleId, preferredCopy: { _ in nil })
    #expect(apps == [noBundle, updaterCopy])
  }
}

private func expectError(
  _ code: String,
  sourceLocation: SourceLocation = #_sourceLocation,
  _ body: () async throws -> Void
) async {
  do {
    try await body()
    Issue.record("Expected \(code), but nothing was thrown", sourceLocation: sourceLocation)
  } catch let error as PigeonError {
    #expect(error.code == code, sourceLocation: sourceLocation)
  } catch {
    Issue.record("Expected \(code), got \(error)", sourceLocation: sourceLocation)
  }
}

private func temporaryFile(named name: String) throws -> URL {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let file = directory.appendingPathComponent(name)
  try Data("hello".utf8).write(to: file)
  return file
}
