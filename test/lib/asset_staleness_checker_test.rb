# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'fileutils'
require 'tmpdir'
require 'stringio'
require 'minitest/mock'
require_relative '../../lib/asset_staleness_checker'

# rubocop:disable Metrics/ClassLength, Rails/TimeZone
class AssetStalenessCheckerTest < ActiveSupport::TestCase
  def setup
    super
    @temp_dir = Dir.mktmpdir('asset_staleness_test')
    @source_dir = File.join(@temp_dir, 'source')
    @compiled_dir = File.join(@temp_dir, 'compiled')
    FileUtils.mkdir_p(@source_dir)
    FileUtils.mkdir_p(@compiled_dir)
  end

  def teardown
    FileUtils.remove_entry(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def create_checker(output: StringIO.new)
    AssetStalenessChecker.new(
      source_paths: [@source_dir],
      compiled_assets_path: @compiled_dir,
      output: output
    )
  end

  def create_file_with_mtime(path, mtime)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, 'content')
    File.utime(mtime, mtime, path)
  end

  test 'assets not stale when compiled is newer than source' do
    create_file_with_mtime(File.join(@source_dir, 'app.js'), Time.now - 100)
    create_file_with_mtime(File.join(@compiled_dir, 'app.js'), Time.now - 50)

    checker = create_checker
    assert_equal false, checker.assets_stale?
  end

  test 'assets stale when source is newer than compiled' do
    create_file_with_mtime(File.join(@compiled_dir, 'app.js'), Time.now - 100)
    create_file_with_mtime(File.join(@source_dir, 'app.js'), Time.now - 50)

    checker = create_checker
    assert_equal true, checker.assets_stale?
  end

  test 'not stale when no source files' do
    create_file_with_mtime(File.join(@compiled_dir, 'app.js'), Time.now - 50)

    checker = create_checker
    assert_equal false, checker.assets_stale?
  end

  test 'not stale when no compiled files' do
    create_file_with_mtime(File.join(@source_dir, 'app.js'), Time.now - 50)

    checker = create_checker
    assert_equal false, checker.assets_stale?
  end

  test 'check_and_warn returns false when not stale' do
    create_file_with_mtime(File.join(@source_dir, 'app.js'), Time.now - 100)
    create_file_with_mtime(File.join(@compiled_dir, 'app.js'), Time.now - 50)

    output = StringIO.new
    checker = create_checker(output: output)
    result = checker.check_and_warn

    assert_equal false, result
    assert_empty output.string
  end

  test 'check_and_warn returns true and warns when stale' do
    create_file_with_mtime(File.join(@compiled_dir, 'app.js'), Time.now - 100)
    create_file_with_mtime(File.join(@source_dir, 'app.js'), Time.now - 50)

    output = StringIO.new
    checker = create_checker(output: output)
    result = checker.check_and_warn

    assert_equal true, result
    assert_match(/WARNING: Stale precompiled assets detected/, output.string)
    assert_match(/rake assets:precompile/, output.string)
  end

  test 'raises in development when stale' do
    create_file_with_mtime(File.join(@compiled_dir, 'app.js'), Time.now - 100)
    create_file_with_mtime(File.join(@source_dir, 'app.js'), Time.now - 50)

    checker = create_checker
    error =
      assert_raises(RuntimeError) do
        checker.check_and_warn(env: 'development')
      end

    assert_match(/Stale precompiled assets detected/, error.message)
    assert_match(/rake assets:precompile/, error.message)
  end

  test 'raises in test env when stale' do
    create_file_with_mtime(File.join(@compiled_dir, 'app.js'), Time.now - 100)
    create_file_with_mtime(File.join(@source_dir, 'app.js'), Time.now - 50)

    checker = create_checker
    error =
      assert_raises(RuntimeError) do
        checker.check_and_warn(env: :test)
      end

    assert_match(/Stale precompiled assets detected/, error.message)
  end

  test 'does not raise in production when stale' do
    create_file_with_mtime(File.join(@compiled_dir, 'app.js'), Time.now - 100)
    create_file_with_mtime(File.join(@source_dir, 'app.js'), Time.now - 50)

    output = StringIO.new
    checker = create_checker(output: output)
    result = checker.check_and_warn(env: 'production')

    assert_equal true, result
    assert_match(/WARNING: Stale precompiled assets detected/, output.string)
  end

  test 'checks nested directories recursively' do
    create_file_with_mtime(
      File.join(@source_dir, 'deep', 'nested', 'file.js'),
      Time.now - 50
    )
    create_file_with_mtime(File.join(@compiled_dir, 'app.js'), Time.now - 100)

    checker = create_checker
    assert_equal true, checker.assets_stale?
  end

  test 'handles multiple source paths' do
    source_dir2 = File.join(@temp_dir, 'source2')
    FileUtils.mkdir_p(source_dir2)

    create_file_with_mtime(File.join(source_dir2, 'new.js'), Time.now - 50)
    create_file_with_mtime(File.join(@compiled_dir, 'app.js'), Time.now - 100)

    checker = AssetStalenessChecker.new(
      source_paths: [@source_dir, source_dir2],
      compiled_assets_path: @compiled_dir,
      output: StringIO.new
    )

    assert_equal true, checker.assets_stale?
  end

  test 'from_rails_config creates checker when compiled assets exist' do
    # Test line 125: new() call when compiled path exists
    # Ensure public/assets exists for this test
    public_assets = Rails.public_path.join('assets')
    FileUtils.mkdir_p(public_assets)

    output = StringIO.new
    checker = AssetStalenessChecker.from_rails_config(
      Rails.application,
      output: output
    )
    # Should create a checker since public/assets exists
    assert_instance_of AssetStalenessChecker, checker
  end
end
# rubocop:enable Metrics/ClassLength, Rails/TimeZone
