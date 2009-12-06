#
# rb_main.rb
# MrRails
#
# Created by Matt Aimonetti on 12/6/09.
# Copyright m|a agile 2009. All rights reserved.
#

# Loading the Cocoa framework. If you need to load more frameworks, you can
# do that here too.
framework 'Cocoa'
framework 'WebKit'

# Loading all the Ruby project files.
dir_path = NSBundle.mainBundle.resourcePath.fileSystemRepresentation
Dir.glob(dir_path + '/*.{rb,rbo}').map { |x| File.basename(x, File.extname(x)) }.uniq.each do |path|
  if path != File.basename(__FILE__)
    require(path)
  end
end

# Starting the Cocoa main loop.
NSApplicationMain(0, nil)