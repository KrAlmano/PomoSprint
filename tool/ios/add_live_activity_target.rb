#!/usr/bin/env ruby
# frozen_string_literal: true

# PomoSprint: kilit ekranı sayacı (Canlı Etkinlik) için widget uzantısını
# ios/Runner.xcodeproj'a ekler. Tekrar çalıştırılabilir (idempotent): var olan
# öğeler yeniden oluşturulmaz, yalnızca ayarlar ve aşama sırası düzeltilir.
#
#   gem install xcodeproj   # 1.28.1 ile denendi
#   ruby tool/ios/add_live_activity_target.rb
#
# Yaptıkları:
#   - PomoSprintTimerWidget hedefi (app extension, iOS 16.2, Swift 5,
#     com.pomosprint.app.TimerWidget, takım AQGX8BJMYJ, otomatik imza;
#     Debug/Release/Profile, Flutter xcconfig'leri ile aynı sürüm numarası)
#   - ios/Shared/PomoSprintTimerAttributes.swift her iki hedefte derlenir
#   - Runner: LiveActivityChannel.swift, PrivacyInfo.xcprivacy (Resources),
#     ActivityKit zayıf bağlanır (Runner iOS 15'te de açılmalı)
#   - Runner → uzantı hedef bağımlılığı ve "Embed Foundation Extensions"
#     aşaması; bu aşama Flutter'ın "Thin Binary" aşamasından ÖNCE durur
#     (aksi halde Xcode "Cycle inside Runner" hatası verir).
# App Group KULLANILMAZ: veri MethodChannel + ActivityKit ile geçer.

require 'xcodeproj'

IOS_DIR = File.expand_path('../../ios', __dir__)
PROJECT_PATH = File.join(IOS_DIR, 'Runner.xcodeproj')

WIDGET_NAME = 'PomoSprintTimerWidget'
WIDGET_BUNDLE_ID = 'com.pomosprint.app.TimerWidget'
WIDGET_DEPLOYMENT_TARGET = '16.2'
TEAM_ID = 'AQGX8BJMYJ'
EMBED_PHASE_NAME = 'Embed Foundation Extensions'

WIDGET_SOURCES = %w[PomoSprintTimerWidgetBundle.swift PomoSprintTimerLiveActivity.swift].freeze
SHARED_SOURCE = 'PomoSprintTimerAttributes.swift'
RUNNER_SOURCE = 'LiveActivityChannel.swift'
PRIVACY_MANIFEST = 'PrivacyInfo.xcprivacy'

def find_or_create_group(parent, name, path)
  parent.children.find { |c| c.isa == 'PBXGroup' && (c.display_name == name || c.path == path) } ||
    parent.new_group(name, path)
end

def find_or_create_file(group, path)
  group.files.find { |f| f.path == path } || group.new_reference(path)
end

def ensure_in_phase(phase, file_ref, settings = nil)
  existing = phase.files.find { |bf| bf.file_ref == file_ref }
  return existing if existing

  build_file = phase.add_file_reference(file_ref, true)
  build_file.settings = settings if settings
  build_file
end

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' } or abort('Runner hedefi bulunamadı')

# Flutter'ın xcconfig'leri: $(FLUTTER_BUILD_NAME)/$(FLUTTER_BUILD_NUMBER)
# uzantıda da çözülsün (sürüm numarası uygulamayla aynı olmalı).
xcconfigs = runner.build_configurations.to_h { |c| [c.name, c.base_configuration_reference] }

# --- Dosya referansları -----------------------------------------------------
main_group = project.main_group
runner_group = main_group.children.find { |c| c.display_name == 'Runner' } or abort('Runner grubu bulunamadı')
widget_group = find_or_create_group(main_group, WIDGET_NAME, WIDGET_NAME)
shared_group = find_or_create_group(main_group, 'Shared', 'Shared')

widget_refs = WIDGET_SOURCES.map { |name| find_or_create_file(widget_group, name) }
find_or_create_file(widget_group, 'Info.plist')
shared_ref = find_or_create_file(shared_group, SHARED_SOURCE)
channel_ref = find_or_create_file(runner_group, RUNNER_SOURCE)
privacy_ref = find_or_create_file(runner_group, PRIVACY_MANIFEST)
privacy_ref.last_known_file_type = 'text.xml'

# --- Uzantı hedefi ------------------------------------------------------------
widget = project.targets.find { |t| t.name == WIDGET_NAME }
unless widget
  widget = project.new_target(:app_extension, WIDGET_NAME, :ios, WIDGET_DEPLOYMENT_TARGET, nil, :swift)
  # new_target, SDK sürümüne sabitlenmiş bir Foundation.framework yolu ekler;
  # sistem çerçeveleri (WidgetKit, SwiftUI, ActivityKit) Swift tarafından
  # otomatik bağlandığı için hiçbiri elle eklenmez.
  widget.frameworks_build_phase.files.to_a.each do |build_file|
    ref = build_file.file_ref
    build_file.remove_from_project
    ref.remove_from_project if ref && ref.build_files.empty?
  end
  frameworks_group = main_group.children.find { |c| c.isa == 'PBXGroup' && c.display_name == 'Frameworks' }
  if frameworks_group
    frameworks_group.groups.select { |g| g.children.empty? }.each(&:remove_from_project)
    frameworks_group.remove_from_project if frameworks_group.children.empty?
  end
end

widget.build_configurations.each do |config|
  debug = config.name == 'Debug'
  config.base_configuration_reference = xcconfigs[debug ? 'Debug' : 'Release'] || xcconfigs[config.name]
  settings = config.build_settings
  # xcodeproj, '16.2' < '5' (metin karşılaştırması) yüzünden bunu ekliyor.
  settings.delete('CLANG_ENABLE_OBJC_WEAK')
  settings.merge!(
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES',
    'CODE_SIGN_STYLE' => 'Automatic',
    'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
    'DEVELOPMENT_TEAM' => TEAM_ID,
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'INFOPLIST_FILE' => "#{WIDGET_NAME}/Info.plist",
    'IPHONEOS_DEPLOYMENT_TARGET' => WIDGET_DEPLOYMENT_TARGET,
    'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'],
    'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
    'PRODUCT_BUNDLE_IDENTIFIER' => WIDGET_BUNDLE_ID,
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SDKROOT' => 'iphoneos',
    'SKIP_INSTALL' => 'YES',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2'
  )
  if debug
    settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
    settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
    settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
  else
    settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'
    settings['SWIFT_COMPILATION_MODE'] = 'wholemodule'
    settings['SWIFT_OPTIMIZATION_LEVEL'] = '-O'
    settings['VALIDATE_PRODUCT'] = 'YES'
  end
end

(widget_refs + [shared_ref]).each { |ref| ensure_in_phase(widget.source_build_phase, ref) }

target_attributes = project.root_object.attributes['TargetAttributes'] ||= {}
target_attributes[widget.uuid] ||= { 'CreatedOnToolsVersion' => '16.2' }

# --- Runner -------------------------------------------------------------------
ensure_in_phase(runner.source_build_phase, channel_ref)
ensure_in_phase(runner.source_build_phase, shared_ref)
ensure_in_phase(runner.resources_build_phase, privacy_ref)

# ActivityKit iOS 16.1+'ta var; Runner iOS 15.0'da da açılabilsin diye zayıf bağlanır.
runner.build_configurations.each do |config|
  flags = Array(config.build_settings['OTHER_LDFLAGS'] || '$(inherited)')
  flags = ['$(inherited)'] + flags unless flags.include?('$(inherited)')
  flags += ['-weak_framework', 'ActivityKit'] unless flags.each_cons(2).include?(['-weak_framework', 'ActivityKit'])
  config.build_settings['OTHER_LDFLAGS'] = flags
end

runner.add_dependency(widget)

embed = runner.copy_files_build_phases.find { |p| p.name == EMBED_PHASE_NAME } ||
        runner.new_copy_files_build_phase(EMBED_PHASE_NAME)
embed.symbol_dst_subfolder_spec = :plug_ins
embed.dst_path = ''
ensure_in_phase(embed, widget.product_reference, { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] })

# "Embed Foundation Extensions", Flutter'ın "Thin Binary" aşamasından önce olmalı.
thin_binary = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' } or abort('Thin Binary aşaması bulunamadı')
runner.build_phases.delete(embed)
runner.build_phases.insert(runner.build_phases.index(thin_binary), embed)

project.save

# xcodeproj yerel paket referansının yorumunu kısaltıyor; Xcode/Flutter'ın
# yazdığı biçime geri çevrilir (yalnızca yorum, anlam değişmez).
pbxproj = File.join(PROJECT_PATH, 'project.pbxproj')
content = File.read(pbxproj)
fixed = content.gsub('/* XCLocalSwiftPackageReference "FlutterGeneratedPluginSwiftPackage" */',
                     '/* XCLocalSwiftPackageReference "Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage" */')
File.write(pbxproj, fixed) if fixed != content

puts "#{WIDGET_NAME} hazır: #{runner.build_phases.map(&:display_name).join(' → ')}"
