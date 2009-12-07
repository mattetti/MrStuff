framework "Cocoa"

class MrNotification
  # This is an internal listener that is used by MrNotification to convert
  # a block into a valid Cocoa listener.
  #
  # In addition to wrapping the block, it also makes n.object equal to the
  # MrObject, and n.ns_object equal to the original NSObject.
  class Listener
    def initialize(object, block)
      @object, @block = object, block
    end

    def ready(notification)
      object = @object
      
      notification.instance_eval do
        @ns_obect  = notification.object
        @mr_object = object

        def self.ns_object() @ns_object end
        def self.object()    @mr_object end
      end

      @block.call(notification)
    end
  end

  # Subscribe to a particular event for an object. Equivalent to:
  #
  #   new(NSNotificationCenter.defaultCenter).subscribe(object, event, &block)
  def self.subscribe(object, event, &block)
    @center ||= new
    @center.subscribe(object, event, &block)
    @center
  end

  # Creates a new MrNotification that wraps an NSNotificationCenter. By default
  # it uses the defaultCenter.
  def initialize(notification_center = NSNotificationCenter.defaultCenter)
    @notification_center = notification_center
    @listeners = []
  end

  # Subscribe an event for an object to the center. If the object has a
  # NOTIFICATIONS constant on it, it contains a Hash of symbols that can
  # be used in place of the full constant.
  #
  # For example, the NOTIFICATIONS constant for MrTask is:
  #   NOTIFICATIONS = {
  #     done: NSTaskDidTerminateNotification
  #   }
  #
  # This means that you can do: 
  #   MrNotification.subscribe(@mr_task, :done) do |notification|
  #     # stuff that should happen when NSTaskDidTerminateNotification
  #     # is triggered on the NSTask that the MrTask is wrapping
  #   end
  #
  # Example:
  #
  #   center = MrNotification.new(NSNotificationCenter.alloc.init)
  #   center.subscribe(@ns_object, @ns_notification_name) do |notification|
  #   end
  def subscribe(object, event, &block)
    @listeners << Listener.new(object, block)

    event  = object.class::NOTIFICATIONS[event] if object.class.const_defined?(:NOTIFICATIONS)
    object = object.ns_object if object.respond_to?(:ns_object)

    @notification_center.addObserver(@listeners.last,
      selector:"ready:", name:event, object:object)
  end
end