#!/usr/bin/env ruby

require 'yaml'

# rtsp capture class
class VideoCapture
  def run(url, path)
    timestamp = Time.now.strftime('%d-%m-%Y_%H-%M-%S')
    puts timestamp + ' ' + url
    command = 'rtmpdump -q -r ' + url + ' -o ' + path + '/video-'\
    + timestamp + '.mov'
    @pid = Process.spawn(command)
    Process.wait(@pid) # wait till process is running.
    # Crashed process will result in thread restart
    # as thread will exit too soon.
  end

  def stop
    Process.kill(:TERM, @pid) # kill capture process
  end
end

# video capture thread
class VideoThread
  def create(url, path)
    @proc = VideoCapture.new
    @th = Thread.new { @proc.run(url, path) }
  end

  def wait_for_timeout(timeout)
    @result = @th.join(timeout)
    @result
  end

  def stop_thread
    puts 'Stopping capture, exitting thread'
    @proc.stop
    puts 'Exitting thread'
    @th.exit
  end
end

conf = YAML.load_file('config.yml')
thr_nr = 0
thr = []
thr[thr_nr] = VideoThread.new
thr[thr_nr].create(conf['video']['url'], conf['video']['path'])
loop do
  result = thr[thr_nr].wait_for_timeout(conf['video']['length'])
  if result.nil? # timeout reached, need to stop thread
    old_thread = thr_nr
    thr_nr += 1
    thr_nr = 0 if thr_nr == 2
    puts "Timeout reached, starting new thread nr #{thr_nr}"
    thr[thr_nr] = VideoThread.new
    thr[thr_nr].create(conf['video']['url'], conf['video']['path'])
    thr[old_thread].stop_thread
    puts "Thread nr #{old_thread} stopped"
  else # thread exited too soon (due failure)
    puts "Exited #{thr_nr} due failure. Restarting"
    thr[thr_nr] = VideoThread.new
    thr[thr_nr].create(conf['video']['url'], conf['video']['path'])
  end
end
