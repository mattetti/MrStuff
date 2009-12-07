class MrFileHandle
  attr_reader :ns_object

  def initialize(file_handle)
    # Handle NSPipe
    if file_handle.respond_to?(:fileHandleForReading)
      file_handle = file_handle.fileHandleForReading
    elsif file_handle.respond_to?(:fileHandleForWriting)
      file_handle = file_handle.fileHandleForWriting
    end

    @ns_object = file_handle
  end

  NOTIFICATIONS = {
    :connected      => NSFileHandleConnectionAcceptedNotification,
    :data_available => NSFileHandleDataAvailableNotification,
    :read_finished  => NSFileHandleReadCompletionNotification,
    :end_of_file    => NSFileHandleReadToEndOfFileCompletionNotification,
  }

  def read(&block)
    read_in_background(:readInBackgroundAndNotify, :read_finished, &block)
  end

  def read_to_end(&block)
    if block_given?
      read_in_background(:readToEndOfFileInBackgroundAndNotify, :end_of_file, &block)
    else
      data = @ns_object.readDataToEndOfFile
      NSString.alloc.initWithData(data, encoding:NSUTF8StringEncoding)
    end
  end

private
  def read_in_background(selector, notification, &block)
    require "mr_notification_center"

    MrNotificationCenter.subscribe(self, notification) do |notification|
      data = notification.user_info[NSFileHandleNotificationDataItem]

      if data.length > 0
        output = NSString.alloc.initWithData(data, encoding:NSUTF8StringEncoding)
        block.call output, notification
      end

      @ns_object.send(selector)
    end

    @ns_object.send(selector)
  end
end