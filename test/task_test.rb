require "test/unit"
framework "Cocoa"
framework "CoreFoundation"

$:.push File.join(File.dirname(__FILE__), "..", "lib")
require "mr_task"

class TestMrTask < Test::Unit::TestCase
  def async_result
    run_loop = NSRunLoop.currentRunLoop.getCFRunLoop
    CFRunLoopRun(run_loop)
    @result
  end

  def set_async_result(result)
    run_loop = NSRunLoop.currentRunLoop.getCFRunLoop
    CFRunLoopStop(run_loop)
    @result = result
  end

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

  def test_task_works_with_a_directory
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
end