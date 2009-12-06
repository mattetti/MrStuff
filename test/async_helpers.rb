framework "CoreFoundation"

module MrAsyncHelpers
  def async_result
    run_loop = NSRunLoop.currentRunLoop.getCFRunLoop
    CFRunLoopRun(run_loop)
    @result
  end

  def set_async_result(result)
    run_loop = NSRunLoop.currentRunLoop.getCFRunLoop
    CFRunLoopStop(run_loop)
    @result = result
  end
end