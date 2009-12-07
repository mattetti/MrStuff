
# Mr Task is a NSTask wrapper that has gives MacRuby developers
# an API closer to what they would expect when using Ruby.
#
# For more information about NSTask, refer to:
# http://developer.apple.com/mac/library/documentation/cocoa/Reference/Foundation/Classes/NSTask_Class/Reference/Reference.html
class MrTask
  class InvalidExecutable < StandardError; end

  attr_reader :ns_object

  # The NSTaskDidTerminateNotification is mapped to :done when
  # using the MrNotificationCenter for a MrTask
  NOTIFICATIONS = {
    done: NSTaskDidTerminateNotification
  }

  # Creates a new task instance with a launch path and a directory.
  # The directory is the working directory from which you want the task
  # to be executed.
  #
  # An optional block can be run asynchronously after the task is done.
  # The block takes the task's output and the done notification.
  #
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
  
  # Instantiates and launches a MrTask asynchronously. This method
  # takes an optional block that is passed to #new.
  #
  # Example:
  #   MrTask.launch("/bin/ls", with_arguments:"~/")
  # is equivalent to:
  #   MrTask.new("/bin/ls").launch("~/")
  def self.launch(cmd, with_arguments:arguments, &block)
    new(cmd, &block).launch(arguments)
  end

  # Instantiates and launching a MrTask with no arguments
  #
  # Example:
  #   MrTask.launch("/bin/ls")
  # is equivalent to:
  #   MrTask.new("/bin/ls").launch
  def self.launch(cmd, &block)
    launch(cmd, with_arguments:[], &block)
  end

  def initialize(launch_path, &block)
    unless File.executable?(launch_path)
      raise InvalidExecutable, "#{launch_path} is not a valid executable"
    end

    @ns_object            = NSTask.alloc.init
    @ns_object.launchPath = launch_path
    @output               = ""
    @suspended            = 0

    # When a block is provided, it's a one-time event that gets
    # triggered with the output when the process terminates. This
    # is useful for "shelling out".
    if block_given?
      require "mr_notification"

      pipein, pipeout = pipe

      # Retaining object because NotificationCenter uses WeakRef
      done_notification = nil

      MrNotificationCenter.subscribe(self, :done) do |notification|
        done_notification = notification
        on_output {|output| block.call output, done_notification }
      end
    end
    self
  end

  # Launches a MrTask instance.
  #
  # Optional arguments can be passed to launch, which will be sent
  # to the task when executed.
  #
  # Note: a task that was launched once cannot be launched another time.
  # If you try to do so, an exception will be raised.
  #
  # Usage:
  #   ls = MrTask.new("/bin/ls").launch('/')
  def launch(*arguments)
    @ns_object.arguments ||= arguments
    @ns_object.launch
    return stdin, stdout
  end


  # Uses MrNotificationCenter in the background to monitor the status of your task.
  # As output streams back, the block that you passed is called with the output
  # and the original notification (NSFileHandleReadCompletionNotification).
  #
  # The block is triggered once for each chunk of output that comes back from
  # the task. This is especially useful for monitoring a running task.
  # 
  # Usage:
  #   task = MrTask.new("/usr/bin/tail").on_output do |output|
  #     puts output
  #   end
  #
  #   task.launch("-f", "/var/log/apache2/access_log")
  def on_output(&block)
    require "mr_notification"
    
    pipein, pipeout = pipe

    event_name = NSFileHandleReadCompletionNotification
    MrNotificationCenter.subscribe(pipeout, event_name) do |notification|
      data = notification.userInfo[NSFileHandleNotificationDataItem]

      if data.length > 0
        output = NSString.alloc.initWithData(data, encoding:NSUTF8StringEncoding) ||
                 NSString.alloc.initWithData(data, encoding:NSASCIIStringEncoding)

        block.call output, notification
      end

      pipeout.readInBackgroundAndNotify
    end

    pipeout.readInBackgroundAndNotify
    self
  end

  # Pipes the output through new NSPipes. This means that you will not see
  # the output of the child task in the stdout of your main process.
  #
  # Returns [stdin, stdout] as NSFileHandles
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

  # Returns the arguments that were sent to the task
  def arguments
    @ns_object.arguments
  end

  # Returns the task's current directory path
  def pwd
    @ns_object.currentDirectoryPath
  end

  # Returns the executable for the task
  def executable
    @ns_object.launchPath
  end

  # Send a SIGINT to the task
  def interrupt
    kill(:INT)
  end

  # Send a signal to the task (defaults to SIGTERM)
  def kill(signal = :TERM)
    Process.kill(signal, @ns_object.processIdentifier)
  end

  # Returns a boolean reflecting whether the task is still running
  def running?
    @ns_object.isRunning
  end

  # Returns the pid of the task
  def pid
    @ns_object.process_identifier
  end

  # Returns true if the task is suspended. This does not reflect calls to suspend
  # made directly on the NSTask.
  def suspended?
    @suspended.nonzero?
  end

  # Suspends the task. You can only call suspend once. However, Cocoa supports suspending
  # a task multiple times (which requires multiple resumes to fully resume). If you want
  # to require multiple calls to resume to resume the task, use suspend!
  def suspend
    raise "You probably didn't mean to suspend multiple times. If you did, use suspend!" if suspended?
    suspend!
  end

  # Suspends the task. Multiple calls to suspend! require multiple calls to resume
  # to resume the task.
  def suspend!
    @suspended += 1
    @ns_object.suspend
  end

  # Resumes a suspended task. If suspend! was called multiple times, multiple calls
  # to resume will be required to resume the task.
  def resume
    @ns_object.resume
    @suspended -= 1
  end

  # Returns the status code for the task. Returns nil if the task is still running.
  def status
    @ns_object.terminationStatus unless running?
  end

  TERMINATION_REASONS = {
    NSTaskTerminationReasonExit => :exit,
    NSTaskTerminationReasonUncaughtSignal => :uncaught_signal
  }

  # Returns the reason for termination. This is one of :exit or :uncaught_signal.
  # This is not always available, even if the task is terminated. Returns nil
  # if the reason is unavailable or the task is still running.
  def reason
    @ns_object.terminationReason unless running?
  end
end