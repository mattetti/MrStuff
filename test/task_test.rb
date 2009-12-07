require "test/unit"
framework "Cocoa"

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
    task.pipe
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
    file = File.expand_path(File.join(File.dirname(__FILE__), "log.log"))
    `touch #{file}`

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

  def test_task_launch_works
    MrTask.launch("/bin/ls", with_arguments:"/") do |output|
      set_async_result(output)
    end

    assert_match %r{Applications}, async_result
  end

  def test_task_cannot_be_launched_twice
    ls = MrTask.new("/bin/ls")
    ls.pipe
    ls.launch('/')
    assert_raises(RuntimeError){ls.launch('/')}
  end

  def test_task_knows_its_pwd
    ls = MrTask.new("/bin/ls")
    assert_equal File.expand_path(Dir.pwd), ls.pwd
  end

  def test_task_knows_its_custom_pwd
    ls = MrTask.new("/bin/ls", with_directory:"/")
    assert_equal "/", ls.pwd
  end

  def test_task_knows_its_not_running_before_it_started
    ls = MrTask.new("/bin/ls")
    assert !ls.running?
  end

  def test_task_knows_when_its_running
    ls = MrTask.new("/usr/bin/ruby")
    ls.launch("-e", "'sleep'")
    assert ls.running?
  ensure
    ls.kill
  end

  def test_task_knows_its_not_running_once_its_dead
    ls = MrTask.new("/usr/bin/ruby")
    ls.launch("-e", "'sleep'")
    ls.kill(9)
    assert !ls.running?
  end

  def test_task_sends_stderr
    rb = MrTask.new("/usr/bin/ruby") do |output, error|
      set_async_result(error)
    end
    rb.launch("-e", "$stderr.puts 'omg'; exit 1")
    assert_equal "omg\n", async_result
  end

end