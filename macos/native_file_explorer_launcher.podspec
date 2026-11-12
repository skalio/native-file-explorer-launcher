Pod::Spec.new do |s|
  s.name             = 'native_file_explorer_launcher'
  s.version          = '2.0.0'
  s.summary          = 'Show files in Finder, open them, and list the apps that can open them.'
  s.homepage         = 'https://github.com/skalio/native-file-explorer-launcher'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Skalio GmbH'
  s.source           = { :path => '.' }
  s.source_files     = 'native_file_explorer_launcher/Sources/native_file_explorer_launcher/**/*.swift'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
