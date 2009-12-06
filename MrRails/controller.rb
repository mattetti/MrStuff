# controller.rb
# MrRails
#
# Created by Matt Aimonetti on 12/6/09.
# Copyright 2009 m|a agile. All rights reserved.

class Controller
  
  attr_accessor :start_stop_btn
  attr_accessor :log_view, :web_view
  
  def awakeFromNib
  
  end
  
  def start_stop(sender)
  
  end
  
  
  # Application callbacks
  
  def applicationShouldTerminateAfterLastWindowClosed(app)
    true
  end
  
  def windowWillClose(notification)
    stop
  end
end
