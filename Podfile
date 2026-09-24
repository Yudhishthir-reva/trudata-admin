platform :ios, '16.0'

target 'Truedata' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Truedata
  pod 'IQKeyboardManagerSwift'
  pod 'FirebaseCore'
  pod 'FirebaseMessaging'
  pod 'FirebaseRemoteConfig'


end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Silence Xcode warnings: pods still ship with IPHONEOS_DEPLOYMENT_TARGET < 15
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 16.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      end
    end
  end
end
