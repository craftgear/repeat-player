#coding: utf-8
require "rubygems"
require "colored"
require "optparse"

#設定
@ini_file = "repeat_player.ini"
@default_speeds = [1.6, 1.4, 1.2]
#@default_speeds = (12..20).to_a.reverse.map{|i|
   #i / 10.0;
#}
#@default_speeds = @default_speeds + (13..20).to_a.map{|i|
   #i / 10.0;
#}

file_types = "mp4,avi,mpg,mkv,mp3,flac,m4a,ogg"
@partial_repeat = false
@partial_duration = 610
@loop = true
@rewind_margin = 5
@full_screen = false

# TODO Cut head and tail
#head_trim=0
#tail_trim=0

# TODO audio file output
# -ao pcm:file=audio.wav

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
  position = position.to_i - 2 * speed.to_f
  File.open(@ini_file, "w") do |f|
    f.puts "last_file=" + File::basename(file_name)
    f.puts "last_speed=" + speed.to_s
    f.puts "last_position=" + position.to_s
    f.puts "speeds=" + speeds.join(",") #if speeds != @default_speeds
    f.puts "partial_repeat="+@partial_repeat.to_s
    f.puts "partial_duration="+@partial_duration.to_s
  end
end

def format_startpos(seconds)
  seconds = seconds - @rewind_margin
  seconds = 0 if seconds < 0
  hh = seconds.div(3600)
  mm = seconds.div(60) - (hh*60)
  ss = seconds % 60
  pos = '-ss '+hh.to_s+':'+mm.to_s+':'+ss.to_s
  return pos
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

last_file_in_list = false
files.each do |f|
  last_file_in_list = true if last_file && f =~ /#{Regexp.escape(last_file)}/
end
last_file = nil unless last_file_in_list

if last_speeds != nil && last_speeds != @default_speeds
  speeds = last_speeds
else
  speeds = @default_speeds
end

begin
  files.each do |f|
    if last_file != nil && last_file != File::basename(f)
      next
    elsif last_file == File::basename(f)
      last_file = nil
    end

    media_info = `mplayer -vo null -ao null -frames 0 -identify \"#{f}\"`
    duration = 0
    puts media_info
    #todo store audio tracks and subtitle tracks
    media_info.each_line do |line|
      if line =~ /ID_LENGTH/
        hoge, duration = line.split("=")
        duration = duration.to_i
      end
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

        #equalizer_setting = ",equalizer=2:3:4:4:4:3:3:2:1:1";
        equalizer_setting = "";
        osdlevel = 3;
        full_screen = @full_screen ? '-fs' : ''
        begin
          start_time = Time.now.to_i
          lang = "-alang eng" # -slang eng"
          result = `/usr/bin/mplayer -zoom #{full_screen} -geometry 0%:99% -really-quiet -framedrop -double -dr -nolirc -osdlevel #{osdlevel} -vo x11 -vf eq2=1.5:1.0:0.0:1.0 -af scaletempo,volnorm#{equalizer_setting} #{start_pos} #{end_pos} -speed #{s} -msglevel all=0 #{lang} \"#{f}\"`
        ensure
          end_time = Time.now.to_i
          position = (end_time - start_time + 3) * s + last_position.to_i
          if @partial_repeat
            remain_seconds = @partial_duration
            if last_position
              remain_seconds = [@partial_duration - (last_position % @partial_duration), duration - last_position].min
            end
            if (end_time - start_time + 1) * s < remain_seconds
              save_ini f, s, position, speeds
            end
          elsif position < duration
            save_ini f, s, position, speeds
          else
            save_ini f, s, position, speeds
            start_pos = ''
          end
          puts ">>> duration     " + duration.to_s
          puts ">>> play seconds " + position.to_s
        end

        last_position = nil
      end

    end
  end
end while @loop
#File.delete @ini_file
save_ini '', s, position, speeds
`beep`
`beep`
