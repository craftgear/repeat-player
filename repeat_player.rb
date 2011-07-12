#coding: utf-8
require "colored"

#設定
@ini_file = "repeat_player.ini"
@default_speeds = [1.8, 1.2, 1.4]
#default_speeds = [2.0, 1.6, 1.2]
#default_speeds = [1.7, 1.4, 1.2, 1.0]
file_types = "mp4,avi,mpg,mkv,mp3,flac,m4a"
@partial_repeat = false
@partial_duration = 610

def load_ini
  last_file = nil
  last_speed = nil
  last_position = nil
  last_speeds = nil
  if File.exists? @ini_file
      File.open(@ini_file, "r") do |f|
        f.each do |line|
          last_file = line.sub("last_file=", "").strip if line =~ /^last_file=/
          last_speed = line.sub("last_speed=", "").strip.to_f if line =~ /^last_speed=/
          last_position = line.sub("last_position=", "").strip.to_i if line =~ /^last_position=/
          if line =~ /^speeds=/
            last_speeds = line.sub("speeds=", "").strip.split(",")
            last_speeds.map!{|s| s.to_f}
          end
          if line =~ /^partial_repeat=/
            @partial_repeat = line.sub("partial_repeat=", "").strip
            if @partial_repeat == 'true'
              @partial_repeat = true
            else
              @partial_repeat = false
            end
          end
          @partial_duration = line.sub("partial_duration=", "").strip.to_i if line =~ /^partial_duration=/
        end
      end
  end
  return last_file, last_speed, last_position, last_speeds
end

def save_ini(file_name, speed, position, speeds)
  File.open(@ini_file, "w") do |f|
    f.puts "last_file=" + file_name.force_encoding('UTF-8')
    f.puts "last_speed=" + speed.to_s
    f.puts "last_position=" + position.to_i.to_s
    f.puts "speeds=" + speeds.join(",") if speeds != @default_speeds
    f.puts "partial_repeat="+@partial_repeat.to_s
    f.puts "partial_duration="+@partial_duration.to_s
  end
end

@rewind_margin = 3
def format_startpos(seconds)
  seconds = seconds - @rewind_margin
  seconds = 0 if seconds < 0
  hh = seconds.div(3600)
  mm = seconds.div(60) - (hh*60)
  ss = seconds % 60
  return '-ss '+hh.to_s+':'+mm.to_s+':'+ss.to_s
end

def format_endpos(seconds)
  seconds = seconds + @rewind_margin
  return "-endpos #{seconds}"
end

path = ARGV[0]
path = path + File::SEPARATOR if !path.nil? && path[-1] != File::SEPARATOR
if path != nil && File.exists?(path)
  files = Dir.glob("#{path}**/*.{#{file_types}}")
  @ini_file = path + File::SEPARATOR + @ini_file
else
  files = Dir.glob("./**/*.{#{file_types}}")
end
files.sort!

last_file, last_speed, last_position, last_speeds = load_ini
if files.index(last_file) == nil
  last_file = nil
end
if last_speeds != nil && last_speeds != @default_speeds
  speeds = last_speeds
else
  speeds = @default_speeds
end

files.each do |f|
  if last_file != nil && last_file != f
    next
  elsif last_file == f
    last_file = nil
  end

  media_info = `mplayer -vo null -ao null -frames 0 -identify \"#{f}\"`
  duration = 0
  media_info.each_line do |line|
    if line =~ /ID_LENGTH/
      hoge, duration = line.split("=")
      duration = duration.to_i
    end
  end
  if last_position.to_i + 5 > duration
    last_position = nil
    next
  end

  if @partial_repeat
    parts = duration.div(@partial_duration) + 1
  else
    parts = 1
  end

  parts.times do |part|
    start_pos = ''
    end_pos = ''

    if last_position != nil
      if @partial_repeat
        next if last_position.div(@partial_duration).to_i != part
        end_pos = format_endpos(@partial_duration - (last_position % @partial_duration))
      end
      start_pos = format_startpos(last_position)
    end

    speeds.each do |s|
      s = s.to_f
      if last_position == nil && @partial_repeat
        last_position = part * @partial_duration
        start_pos = format_startpos(part * @partial_duration)
        end_pos = format_endpos(@partial_duration)
      end

      if speeds.index(last_speed) != nil && s != last_speed
        next
      elsif last_speed == s
        last_speed = nil
      end

      puts ">>> start playing #{f}".green
      puts ">>> part #{part+1} of #{parts}".green if parts > 1
      puts ">>> with speed #{s}".green

      begin
        start_time = Time.now.to_i
        result = `mplayer -nolirc -osdlevel 3 -vo x11 -af scaletempo,volnorm #{start_pos} #{end_pos} -speed #{s} -msglevel all=0 \"#{f}\"`

      ensure
        end_time = Time.now.to_i
        play_seconds = (end_time - start_time) * s + last_position.to_i
        if @partial_repeat
          if (end_time - start_time) * s + 5 < @partial_duration - (last_position % @partial_duration)
            save_ini f, s, play_seconds, speeds
            exit
          end
        elsif play_seconds + 5 < duration
          save_ini f, s, play_seconds, speeds
          exit
        else
          start_pos = ''
        end
        puts ">>> duration     " + duration.to_s
        puts ">>> play seconds " + play_seconds.to_s
      end

      last_position = nil
    end

  end
end
File.delete @ini_file
`beep`
`beep`
