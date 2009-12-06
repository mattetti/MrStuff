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

  def test_simple_task_doesnt_explode
    task = MrTask.new("/bin/ls")
    assert_nothing_raised { task.launch }
  end

  require "monitor"

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

end