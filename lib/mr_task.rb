
# Mr Task is a NSTask wrapper that has for goal to give MacRuby developer 
# an API closer to what they would expect when using Ruby.
#
# For more information about NSTask, refer to:
# http://developer.apple.com/mac/library/documentation/cocoa/Reference/Foundation/Classes/NSTask_Class/Reference/Reference.html
# 
class MrTask
  class InvalidExecutable < StandardError; end

  attr_accessor :launch_path, :ns_object

  NOTIFICATIONS = {
    done: NSTaskDidTerminateNotification
  }

  # Creates a new task instance with a launch path and a directory
  # the directory is the location from which you want the task
  # to be executed from.
  # An optional block can be run asynchronously after the task is done.
  # The new instance task still needs to be triggered by calling the +launch+
  # method on it.
  #
  # Example: 
  #   task = MrTask.new("/bin/ls", with_directory:"/") do |output|
  #     puts output
  #   end
  #
  #   task.launch
  #
  def self.new(launch_path, with_directory:directory, &block)
    instance = new(launch_path, &block)
    instance.ns_object.currentDirectoryPath = directory
    instance
  end
  
  # Launches a synchronous/blocking task
  # it's using Ruby's backticks kernel method
  # http://ruby-doc.org/core/classes/Kernel.htm
  #
  # Example:
  #   MrTask.launch("/bin/ls ~/")
  #
  def self.launch(cmd_with_args)
    `#{cmd_with_args}`
  end

  
  def initialize(launch_path, &block)
    unless File.executable?(launch_path)
      raise InvalidExecutable, "#{launch_path} is not a valid executable"
    end

    @ns_object            = NSTask.alloc.init
    @ns_object.launchPath = launch_path
    @output               = ""

    # When a block is provided, it's a one-time event that gets
    # triggered with the output when the process terminates. This
    # is useful for "shelling out".
    if block_given?
      require "mr_notification"

      pipein, pipeout = pipe

      # Retaining object because NotificationCenter uses WeakRef
      done_notification = nil

      MrNotification.subscribe(self, :done) do |notification|
        done_notification = notification
        on_output {|output| block.call output, done_notification }
      end
    end
    self
  end

  # Triggers a MrTask instance.
  # Optionals arguments can be passed to the task to execute
  # Note: a task that was launched once cannot be launched another time.
  # If you try to do so, an exception will be raised.
  #
  # Usage:
  #   ls = MrTask.new("/bin/ls").launch('/')
  #
  def launch(*arguments)
    @ns_object.arguments ||= arguments
    @ns_object.launch
    return stdin, stdout
  end


  # Uses MrNotification in the background to monitor the status of your task.
  # Once the task is done executing, the output is read and passed to the block.
  #
  # The block will keep on being run everytime more output is being sent out from
  # the task. This makes this method really useful if you want to process a 
  # running process for instance.
  # 
  # Usage:
  #   task = MrTask.new("/usr/bin/tail").on_output do |output|
  #     puts output
  #   end
  #  
  #   task.launch("-f", "/var/log/apache2/access_log")
  #
  def on_output(&block)
    require "mr_notification"
    
    pipein, pipeout = pipe

    event_name = NSFileHandleReadCompletionNotification
    MrNotification.subscribe(pipeout, event_name) do |notification|
      data = notification.userInfo[NSFileHandleNotificationDataItem]

      if data.length > 0
        output = NSString.alloc.initWithData(data, encoding:NSUTF8StringEncoding) ||
                 NSString.alloc.initWithData(data, encoding:NSASCIIStringEncoding)

        block.call output
      end

      pipeout.readInBackgroundAndNotify
    end

    pipeout.readInBackgroundAndNotify
    self
  end

  # Setups or returns the in and out of the task's pipe
  # 
  def pipe
    return stdin, stdout if @ns_object.standardInput.respond_to?(:fileHandleForWriting)

    @ns_object.standardInput  = NSPipe.alloc.init
    @ns_object.standardOutput = NSPipe.alloc.init
    return stdin, stdout
  end

  def stdin
    stdin = @ns_object.standardInput
    stdin = stdin.fileHandleForWriting if stdin.respond_to?(:fileHandleForWriting)
    stdin
  end

  def stdout
    stdout = @ns_object.standardOutput
    stdout = stdout.fileHandleForReading if stdout.respond_to?(:fileHandleForReading)
    stdout
  end

  def stderr
    stderr = @ns_object.standardError
    stderr = stderr.fileHandleForReading if stderr.respond_to?(:fileHandleForReading)
    stderr
  end

  # Waits for the task to be done running in the background
  def wait
    @ns_object.waitUntilExit
  end

  def arguments
    @ns_object.arguments
  end

  # Returns the task's current directory path
  def pwd
    @ns_object.currentDirectoryPath
  end

  # Returns the executable that is going to be called by the task
  def executable
    @ns_object.launchPath
  end

  def interrupt
    kill(:INT)
  end

  def kill(signal = :TERM)
    Process.kill(signal, @ns_object.processIdentifier)
  end

  def running?
    @ns_object.isRunning
  end

  def pid
    @ns_object.process_identifier
  end

  def suspend
    raise "You probably didn't mean to suspend multiple times. If you did, use suspend!" if @suspended
    suspend!
  end

  def suspend!
    @suspended = true
    @ns_object.suspend
  end

  def resume
    @suspended = false
    @ns_object.resume
  end

  def suspended?
    @suspended
  end

  def status
    @ns_object.terminationStatus unless running?
  end

  def reason
    @ns_object.terminationReason unless running?
  end
end