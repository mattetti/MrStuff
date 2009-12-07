framework "Cocoa"

class MrNotification
  attr_reader :object
  def initialize(notification, mr_object)
    @notification, @object = notification, mr_object
  end

  def ns_object
    @object.ns_object if @object.respond_to?(:n_object)
  end

  def name
    @notification.name
  end
  
  def user_info
    @notification.userInfo
  end
end

class MrNotificationCenter
  # This is an internal listener that is used by MrNotificationCenter to convert
  # a block into a valid Cocoa listener.
  #
  # In addition to wrapping the block, it also makes n.object equal to the
  # MrObject, and n.ns_object equal to the original NSObject.
  class Listener
    def initialize(object, block)
      @object, @block = object, block
    end

    def ready(notification)
      @block.call MrNotification.new(notification, @object)
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

  # Creates a new MrNotificationCenter that wraps an NSNotificationCenter. By default
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
  #   MrNotificationCenter.subscribe(@mr_task, :done) do |notification|
  #     # stuff that should happen when NSTaskDidTerminateNotification
  #     # is triggered on the NSTask that the MrTask is wrapping
  #   end
  #
  # Example:
  #
  #   center = MrNotificationCenter.new(NSNotificationCenter.alloc.init)
  #   center.subscribe(@ns_object, @ns_notification_name) do |notification|
  #   end
  def subscribe(object, event, &block)
    @listeners << Listener.new(object, block)

    # If the object is a MrWrapped object, this allows the user to pass
    # a shorter :event_name instead of the normal, long NSEventName
    event  = object.class::NOTIFICATIONS[event] if object.class.const_defined?(:NOTIFICATIONS)

    # If the object is a MrWrapped object, get the ns_object from it
    object = object.ns_object if object.respond_to?(:ns_object)

    @notification_center.addObserver(@listeners.last,
      selector:"ready:", name:event, object:object)
  end
end