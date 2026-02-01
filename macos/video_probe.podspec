#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint video_probe.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'video_probe'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files = '../darwin/Classes/**/*'
  s.public_header_files = '../darwin/Classes/video_probe.h'

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Ensure C symbols are exported and visible to FFI
    'GCC_SYMBOLS_PRIVATE_EXTERN' => 'NO',
    'OTHER_CFLAGS' => '-fvisibility=default',
  }
  s.swift_version = '5.0'
end
