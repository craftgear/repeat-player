#coding: utf-8
require "colored"

#設定
@ini_file = "repeat_player.ini"
#speed = [1.8, 1.4, 1.2]
speed = [2.4, 1.8, 1.4]
file_types = "mp4,avi,mpg,mkv,mp3,flac,m4a"

def load_ini
  file_name = nil
  speed = nil
  position = nil
  if File.exists? @ini_file
      File.open(@ini_file, "r") do |f|
        file_name, speed, position = f.read.split(",")
        speed = speed.to_f
        position = position.to_i
      end
  end
  return file_name, speed, position
end

def save_ini(file_name, speed, position)
  File.open(@ini_file, "w") do |f|
    f.puts file_name+','+speed.to_s+','+position.to_i.to_s
  end
end

path = ARGV[0]
if path != nil && File.exists?(path)
  files = Dir.glob("#{path}/**/*.{#{file_types}}")
  @ini_file = path + File::SEPARATOR + @ini_file
else
  files = Dir.glob("./**/*.{#{file_types}}")
end
files.sort!

last_file, last_speed, last_position = load_ini
if files.index(last_file) == nil
  last_file = nil
end

files.each do |f|
  if last_file != nil && last_file != f
    next
  elsif last_file == f
    last_file = nil
  end

  video_info = `mplayer -vo null -ao null -frames 0 -identify \"#{f}\"`
  duration = 0
  video_info.each_line do |line|
    if line =~ /ID_LENGTH/
      hoge, duration = line.split("=")
      duration = duration.to_i
    end
  end

  speed.each do |s|
    if speed.index(last_speed) != nil && s != last_speed
      next
    elsif last_speed == s
      last_speed = nil
    end

    start_pos = ''
    if last_position != nil
      hh = last_position.div(3600)
      mm = last_position.div(60) - (hh*60)
      ss = last_position % 60
      start_pos = '-ss '+hh.to_s+':'+mm.to_s+':'+ss.to_s
    end

    start_time = Time.now.to_i

    puts ">>> start playing #{f}\n>>> with speed #{s}".green
    result = `mplayer -osdlevel 3 -msglevel all=0 -af scaletempo,volnorm #{start_pos} -speed #{s} \"#{f}\"`

    end_time = Time.now.to_i
    play_seconds = (end_time - start_time) * s + last_position.to_i
    last_position = nil

    puts ">>> duration     " + duration.to_s
    puts ">>> play seconds " + play_seconds.to_s

    if play_seconds + 10 < duration
        save_ini f, s, play_seconds - 5
        exit
    end

  end
end
File.delete @ini_file
`beep`
`beep`
