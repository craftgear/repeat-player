メディアファイルのあるディレクトリにスクリプトを置くか､シンボリックリンクを作って実行してください｡

引数なしでカレントディレクトリ以下の全てのファイルを､引数にディレクトリを与えるとそのディレクトリ以下の全てのファイルを再生します｡

同じファイルを再生速度を変えながら再生します｡
再生速度の指定はファイル先頭の配列でおこなってください｡

一つのファイルをいくつかの部分に分けて､各部分ごとに再生速度を変えながら再生することもできます｡
ファイル先頭の@partial_repeatをtrueにして､@partial_durationに区切る時間を秒で設定してください｡

一度でも再生したディレクトリの下にはrepeat_player.iniというファイルができるので､iniファイルでディレクトリごとに再生速度､部分再生､部分再生の時間を指定できます｡