#
# Be sure to run `pod lib lint TikTokBusinessSDK-Event.podspec' to ensure this is a
# valid spec before submitting.
#

Pod::Spec.new do |s|
  s.name             = 'TikTokBusinessSDK-Event'
  s.version          = '1.6.0'
  s.summary          = 'TikTok Business SDK Event Module for iOS'
  s.module_name      = 'TikTokBusinessSDK'
  s.description      = <<-DESC
The Events module of TikTok Business SDK, responsible for event logging and related business logic.
                       DESC

  s.homepage         = 'https://ads.tiktok.com/marketing_api/docs?rid=rscv11ob9m9&id=1683138352999426'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'TikTok'
  s.source           = { :git => 'https://github.com/tiktok/tiktok-business-ios-sdk.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'

  s.frameworks = 'CoreGraphics','AdSupport','StoreKit','UIKit','WebKit'
  s.weak_frameworks = 'AppTrackingTransparency'

  s.source_files = [
    'TikTokBusinessSDK/**/*.{h,m,c,mm,pch,hh,hpp,cpp}'
  ]
  s.exclude_files = [
    "TikTokBusinessSDK/*.plist",
    "TikTokBusinessSDK/TTSDKCrash/**/*",
    "TikTokBusinessSDK/Public/TikTokBusinessSDK/*.h"
  ]
  s.public_header_files = [
    'TikTokBusinessSDK/Public/**/*.h'
  ]
  s.resource_bundles = {
    "#{s.module_name}_Privacy" => 'PrivacyInfo.xcprivacy'
  }
  s.swift_version = '5.0'
end
