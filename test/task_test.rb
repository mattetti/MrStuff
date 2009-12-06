require "test/unit"
framework "Cocoa"
framework "CoreFoundation"

$:.push File.join(File.dirname(__FILE__), "..", "lib")
require "mr_task"
require "#{File.dirname(__FILE__)}/async_helpers"

class TestMrTask < Test::Unit::TestCase
  include MrAsyncHelpers

  def test_task_doesnt_segfault_with_invalid_executable
    assert_raises(MrTask::InvalidExecutable) { MrTask.new("/bin/mrinvalid") }
    assert_raises(MrTask::InvalidExecutable) do
      MrTask.new("/bin/mrinvalid", with_directory:"/")
    end
  end

  def test_simple_task_doesnt_explode
    task = MrTask.new("/bin/ls")
    assert_nothing_raised { task.launch }
  end

  def test_task_triggers_output_event
    task = MrTask.new("/bin/ls").on_output do |output|
      set_async_result(output)
    end

    task.launch
    assert async_result
  end

  def test_task_works_with_a_directory
    task = MrTask.new("/bin/ls").on_output do |output|
      set_async_result(output)
    end

    task.launch("/")
    assert_match %r{Applications}, async_result
  end

  def test_task_waits_for_exit_and_calls_block_with_output
    task = MrTask.new("/bin/ls") do |output|
      set_async_result(output)
    end

    task.launch
    assert_match %r{lib}, async_result
  end

  def test_task_with_directory_waits_for_exit_and_calls_block_with_output
    task = MrTask.new("/bin/ls", with_directory:"/") do |output|
      set_async_result(output)
    end

    task.launch
    assert_match %r{Applications}, async_result
  end

  def test_task_works_with_a_streaming_task
    run, result = 0, ""
    file = File.join(File.dirname(__FILE__), "log.log")

    task = MrTask.new("/usr/bin/tail").on_output do |output|
      File.open(file, "a") {|f| f.puts "into log" }
      run += 1
      result << output
      set_async_result(result) if run == 3
    end

    task.launch("-f", file)
    File.open(file, "w") {|f| f.puts "into log" }
    assert_match /(into log\n){3}/, async_result
  ensure
    File.delete(file)
  end
  
  def test_task_works_in_sync_mode
    assert_match %r{Applications}, MrTask.launch("/bin/ls /")
  end
  
  def test_task_cannot_be_launched_twice
    ls = MrTask.new("/bin/ls")
    ls.launch('/')
    assert_raises(RuntimeError){ls.launch('/')}
  end
  
end