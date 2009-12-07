framework 'Cocoa'

$:.push "#{Dir.pwd}/lib"
require "mr_notification_center"
require "mr_task"

task = MrTask.new("/bin/cat", with_directory:"/bin/") do |output, notification|
  puts "finished task"
  puts output
  task = notification.object
  exit
end

task.launch(File.expand_path("~/.profile"))

task = MrTask.new("/usr/bin/tail")

task.on_output do |output|
  puts output
end

`touch #{Dir.pwd}/log.log`

File.open("#{Dir.pwd}/log.log", "w") do |file|
  task.launch("-f", "#{Dir.pwd}/log.log")
end

NSApplication.sharedApplication.run