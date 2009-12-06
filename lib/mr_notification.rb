framework "Cocoa"

class MrNotification
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

  def self.subscribe(object, event, &block)
    @center ||= new
    @center.subscribe(object, event, &block)
    @center
  end

  def initialize(notification_center = NSNotificationCenter.defaultCenter)
    @notification_center = notification_center
    @listeners = []
  end

  def subscribe(object, event, &block)
    @listeners << Listener.new(object, block)

    event  = object.class::NOTIFICATIONS[event] if object.class.const_defined?(:NOTIFICATIONS)
    object = object.ns_object if object.respond_to?(:ns_object)

    @notification_center.addObserver(@listeners.last,
      selector:"ready:", name:event, object:object)
  end
end