require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  # Keep the pod name UNSCOPED even though the npm package is @javascriptcommon-scoped,
  # so the iOS Bridging-Header (<react-native-orientation-locker/Orientation.h>),
  # AppDelegate, and autolinking stay unchanged.
  s.name           = 'react-native-orientation-locker'
  s.version        = package['version']
  s.summary        = package['summary']
  s.description    = package['description']
  s.author         = package['author']['name']
  s.license        = package['license']
  s.homepage       = package['homepage']
  s.source         = { :git => 'https://github.com/wonday/react-native-orientation-locker.git', :tag => "v#{s.version}" }
  s.requires_arc   = true
  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '11.0'
  s.preserve_paths = 'README.md', 'package.json', 'index.js'
  s.source_files   = 'iOS/**/*.{h,m}'
  s.dependency     'React-Core'
end
