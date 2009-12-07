The MrStuff package provides wrappers for Cocoa APIs that are more familiar to Rubyists.

So far, there is a wrapper for `NSTask` (`MrTask`), and associated wrappers for `NSNotificationCenter`,
`NSTask`, and `NSFileHandle`.

MrNotificationCenter integrates with other Cocoa wrappers as follows:

- Wrappers have an `#ns_object` method which returns the original `NSObject`
- A `NOTIFICATIONS` constant is provided, which provides shorter `Symbol` names
  for each notification provided by the original Cocoa class.

For instance, you can do the following:

    task = MrTask.new("/usr/bin/ls")
    MrNotificationCenter.subscribe(task, :done) do |notification|
      # notification.object is the MrTask
      # notification.object.ns_object is the wrapped NSTask
    end

However, the wrapper provides improved async APIs. For instance:

    task = MrTask.new("/usr/bin/ls")
    task.on_output do |output, notification|
      # When the task gets data in its stdout, this event
      # is triggered. A String is provided, rather than
      # forcing you to extract the data from notification.userInfo
      # and initializing a new String from the data.
      #
      # Note that the block arguments are optional
    end
    task.launch("/")

The above example could be reduced even further to:

    MrTask.launch("/usr/bin/ls", "/") do |out, err, notification|
      # This block is triggered once the task is terminated,
      # and provides a String for both the standard output and
      # error.
      #
      # The block arguments are optional
    end

Other events are also available as needed:

    task = MrTask.new("/usr/bin/ls")
    task.on_done do |notification|
      # This event is triggered once the task is done.
      #
      # You can call notification.object.standard_output
      # or notification.object.error_output to get a
      # String for the outputs.
    end

As you can see, the APIs are fairly flexible and allow you to approach the
same problem in different (asynchronous) ways. At the same time, common
tasks are wrapped up with appropriate async callbacks.

    task = MrTask.launch("/usr/bin/ruby", "-e", "'sleep'")
    task.kill do |notification|
      # This will be the :done event
    end