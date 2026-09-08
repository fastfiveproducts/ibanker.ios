#!/usr/bin/env ruby
#
#  add-test-target.rb — one-time unit-test-target creation (#51)
#
#  Adopted into iBanker from template.ios v0.4.6 (tools/add-test-target.rb), a
#  consumer-copyable recipe; kept close to the template so it re-syncs cleanly.
#  Created by Claude, Fast Five Products LLC, on 7/31/26.
#
#  Copyright © 2026 Fast Five Products LLC. All rights reserved.
#
#  This file is part of a project licensed under the GNU Affero General Public
#  License v3.0. An exception applies: Fast Five Products LLC retains the right
#  to use this code and derivative works in proprietary software without being
#  subject to the AGPL terms. See the LICENSE and LICENSE-EXCEPTIONS.md files at
#  the root of the template repository (github.com/fastfiveproducts/template.ios)
#  for full terms.
#
#  For licensing inquiries, contact: licenses@fastfiveproducts.com
#
# One-time creation of the unit-test target for a folder-synchronized Xcode
# project (the fleet's project shape: PBXFileSystemSynchronizedRootGroup,
# objectVersion 77), scripted so no Xcode GUI session is needed.  Validated
# on template.ios with the xcodeproj gem 1.27.0.
#
# What it does (the Xcode "File > New > Target > Unit Testing Bundle" analog):
#   1. Creates a unit-test-bundle target "<AppTarget>Tests" hosted in the
#      app (TEST_HOST/BUNDLE_LOADER), depending on the app target, with
#      settings copied from the app target (Swift version, deployment
#      target, device family, team).
#   2. Attaches a folder-synchronized root group for "<AppTarget>Tests/" —
#      after this, any test file dropped in that directory auto-joins the
#      test target; no per-file pbxproj work, ever.
#   3. Adds the test target as a testable to the shared "default" scheme's
#      TestAction, so `xcodebuild test -scheme default` runs it.
#
# Usage (from the repo root):
#   ruby tools/add-test-target.rb [project.xcodeproj] [AppTargetName]
#
#   Both arguments optional: with a single .xcodeproj in the repo root and
#   a single application target, the defaults find them.  The test dir name
#   is always "<AppTargetName>Tests".
#
# Consumer notes:
#   - Copy this file into your repo's tools/ and run once.  Create the
#     "<AppTargetName>Tests/" directory with at least one test file before
#     the first `xcodebuild test` run.
#   - @testable import uses the app MODULE name: the target name with
#     non-identifier characters replaced by underscores (template ->
#     template; fast-five -> fast_five; bg.ios -> bg_ios).
#   - Safe to re-run: exits without touching anything if the test target
#     already exists.
#

require 'xcodeproj'

# --- Locate the project ---
project_path = ARGV[0]
if project_path.nil?
  candidates = Dir.glob('*.xcodeproj')
  abort "Error: pass the .xcodeproj path (found #{candidates.size} in cwd)" unless candidates.size == 1
  project_path = candidates.first
end
abort "Error: no project at #{project_path}" unless File.exist?(project_path)
project = Xcodeproj::Project.open(project_path)

# --- Locate the app target ---
app_target_name = ARGV[1]
app_targets = project.native_targets.select { |t| t.product_type == 'com.apple.product-type.application' }
app_target =
  if app_target_name
    project.native_targets.find { |t| t.name == app_target_name }
  else
    abort "Error: #{app_targets.size} application targets found — pass the app target name" unless app_targets.size == 1
    app_targets.first
  end
abort "Error: app target not found" unless app_target

test_target_name = "#{app_target.name}Tests"
if project.native_targets.any? { |t| t.name == test_target_name }
  puts "Target #{test_target_name} already exists — nothing to do."
  exit 0
end

# --- Read the app settings we mirror onto the test target ---
app_debug = app_target.build_configurations.find { |c| c.name == 'Debug' }
abort "Error: app target has no Debug configuration" unless app_debug
deployment  = app_debug.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
swift_ver   = app_debug.build_settings['SWIFT_VERSION']
family      = app_debug.build_settings['TARGETED_DEVICE_FAMILY']
team        = app_debug.build_settings['DEVELOPMENT_TEAM']
app_bundle  = app_debug.build_settings['PRODUCT_BUNDLE_IDENTIFIER']
app_product = app_target.product_reference.path.sub(/\.app\z/, '')

# --- 1. Create the unit-test-bundle target ---
test_target = project.new_target(:unit_test_bundle, test_target_name, :ios, deployment)
test_target.add_dependency(app_target)

# new_target's platform boilerplate links Foundation.framework via a
# hardcoded SDK path and adds Frameworks/iOS navigator groups — modern
# Xcode adds neither to a test target; strip them (pruning only groups the
# gem created that are left empty, so an existing Frameworks group with
# real content is untouched).
test_target.frameworks_build_phase.files.select { |bf|
  bf.file_ref && bf.file_ref.path.to_s.end_with?('Foundation.framework')
}.each do |bf|
  ref = bf.file_ref
  bf.remove_from_project
  parent = ref.parent
  ref.remove_from_project
  while parent.is_a?(Xcodeproj::Project::Object::PBXGroup) &&
        parent.children.empty? && ['iOS', 'Frameworks'].include?(parent.name)
    grandparent = parent.parent
    parent.remove_from_project
    parent = grandparent
  end
end

test_target.build_configurations.each do |config|
  s = config.build_settings
  s.delete('CLANG_ENABLE_OBJC_WEAK')   # dated gem default; inherit the project's
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'   # required: without it the bundle builds as ".xctest"
  s['BUNDLE_LOADER'] = '$(TEST_HOST)'
  s['TEST_HOST'] = "$(BUILT_PRODUCTS_DIR)/#{app_product}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/#{app_product}"
  s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{app_bundle}Tests"
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['SWIFT_EMIT_LOC_STRINGS'] = 'NO'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['MARKETING_VERSION'] = '1.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = deployment if deployment
  s['SWIFT_VERSION'] = swift_ver if swift_ver
  s['TARGETED_DEVICE_FAMILY'] = family if family
  s['DEVELOPMENT_TEAM'] = team if team
end

# --- 2. Attach the folder-synchronized group for the test directory ---
sync_group = project.new(Xcodeproj::Project::Object::PBXFileSystemSynchronizedRootGroup)
sync_group.path = test_target_name
sync_group.source_tree = '<group>'
project.main_group << sync_group
test_target.file_system_synchronized_groups = [] if test_target.file_system_synchronized_groups.nil?
test_target.file_system_synchronized_groups << sync_group

project.save
puts "Created target #{test_target_name} (synchronized dir: #{test_target_name}/)"

# --- 3. Add the testable to the shared "default" scheme ---
scheme_dir = Xcodeproj::XCScheme.shared_data_dir(project.path)
scheme_path = File.join(scheme_dir, 'default.xcscheme')
if File.exist?(scheme_path)
  scheme = Xcodeproj::XCScheme.new(scheme_path)
  scheme_dirty = false

  already = scheme.test_action.testables.any? do |t|
    t.buildable_references.any? { |r| r.target_name == test_target_name }
  end
  if already
    puts "Scheme default already has testable #{test_target_name} — skipped."
  else
    scheme.test_action.add_testable(Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target))
    scheme_dirty = true
    puts "Added #{test_target_name} to the shared default scheme's TestAction."
  end

  # Xcode's project-creation scheme carries an AutocreatedTestPlanReference
  # build entry with buildForArchiving/-Profiling = YES.  Harmless while no
  # testable exists — but once one does, Product ▸ Archive (and Profile)
  # pull the test bundle into a RELEASE build, where @testable import
  # cannot resolve (testability is Debug-only): "Unable to resolve Swift
  # module dependency to a compatible module".  Test code never belongs in
  # Release-based actions — force those flags off.
  entries = scheme.build_action ? (scheme.build_action.entries || []) : []
  entries.each do |entry|
    next unless entry.buildable_references.empty?   # the autocreated-test-plan row
    next unless entry.build_for_archiving? || entry.build_for_profiling?
    entry.build_for_archiving = false
    entry.build_for_profiling = false
    scheme_dirty = true
    puts 'Excluded the autocreated test plan from Archive/Profile builds (Release has no testability).'
  end

  scheme.save! if scheme_dirty
else
  warn "WARNING: no shared default scheme at #{scheme_path} — add the testable manually, and exclude tests from Archive/Profile builds."
end

puts "Done.  Next: create #{test_target_name}/ with a test file, then run:"
puts "  xcodebuild test -scheme \"default\" -destination 'platform=iOS Simulator,name=<your repo simulator>'"
