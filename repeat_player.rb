#coding: utf-8
require "colored"

#設定
@ini_file = "repeat_player.ini"
@default_speeds = [1.8, 1.2, 1.5]
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
          last_speeds = line.sub("speeds=", "").strip.split(",") if line =~ /^speeds=/
          @partial_repeat = line.sub("partial_repeat=", "").strip if line =~ /^partial_repeat=/
          @partial_repeat = @partial_repeat == 'true' ? true : false
          @partial_duration = line.sub("partial_duration=", "").strip.to_i if line =~ /^partial_duration=/
          puts @partial_repeat, @partial_duration
        end
      end
  end
  return last_file, last_speed, last_position, last_speeds
end

def save_ini(file_name, speed, position, speeds)
  position = position - 5
  position = 0 if position < 0
  File.open(@ini_file, "w") do |f|
    f.puts "last_file=" + file_name
    f.puts "last_speed=" + speed.to_s
    f.puts "last_position=" + position.to_i.to_s
    f.puts "speeds=" + speeds.join(",") if speeds != @default_speeds
    f.puts "partial_repeat="+@partial_repeat.to_s
    f.puts "partial_duration="+@partial_duration.to_s
  end
end

def format_seconds(seconds)
  rewind_seconds = 5
  seconds = seconds - rewind_seconds
  seconds = 0 if seconds < 0
  hh = seconds.div(3600)
  mm = seconds.div(60) - (hh*60)
  ss = seconds % 60
  return '-ss '+hh.to_s+':'+mm.to_s+':'+ss.to_s
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
if last_speeds != nil && last_speeds != speeds
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

  if @partial_repeat
    parts = duration.div(@partial_duration)
  else
    parts = 1
  end

  parts.times do |part|
    start_pos = ''
    end_pos = ''
    if last_position != nil
      if @partial_repeat
        next if last_position.div(@partial_duration * part +1).to_i > 1
      end
      start_pos = format_seconds(last_position)
    else
      if @partial_repeat
        last_position = part * @partial_duration
        start_pos = format_seconds(part * @partial_duration)
      end
    end

    if @partial_repeat
      end_pos = "-endpos " + @partial_duration.to_s
    end
    speeds.each do |s|
      if speeds.index(last_speed) != nil && s != last_speed
        next
      elsif last_speed == s
        last_speed = nil
      end

      start_time = Time.now.to_i

      puts ">>> start playing #{f}".green
      puts ">>> part #{part} of #{parts}".green if parts > 1
      puts ">>> with speed #{s}".green
      result = `mplayer -nolirc -osdlevel 3 -vo x11 -af scaletempo,volnorm #{start_pos} #{end_pos} -speed #{s} -msglevel all=0 \"#{f}\"`

      end_time = Time.now.to_i
      play_seconds = (end_time - start_time) * s + last_position.to_i

      puts ">>> duration     " + duration.to_s
      puts ">>> play seconds " + play_seconds.to_s

      if @partial_repeat
        if (end_time - start_time) * s + 5< @partial_duration
          save_ini f, s, play_seconds, speeds
          exit
        end
      elsif play_seconds + 5 < duration
        save_ini f, s, play_seconds, speeds
        exit
      end
    end
    last_position = nil

  end
end
File.delete @ini_file
`beep`
`beep`
