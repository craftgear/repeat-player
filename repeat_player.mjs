
import fs from 'node:fs';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_SPEED = '1.6';
const DEFAULT_VOLUME = '100';
const MAX_WIDTH = '640';
const POSITION_TOP = '0%';
const POSITION_LEFT = '100%';
const EXTENSIONS = ['mp4', 'mkv', 'avi', 'webm', 'mp3', 'm4b'];

const play = (fileName, speed) => {
  console.info(`playing ${path.basename(fileName)} at x${speed}`);
  return spawn('mpv', ['--alang=en,eng', '--focus-on=never', '--save-position-on-quit', `--speed=${speed}`, `--geometry=${MAX_WIDTH}+${POSITION_LEFT}+${POSITION_TOP}`, `--volume=${DEFAULT_VOLUME}`, '--af=lavfi=[loudnorm=I=-16:TP=-3:LRA=4]', fileName]);
};
// , '--video-aspect-override=16:9'

const lastFileExistsInPlayList = (lastFileName, playList) => {
  if (!lastFileName) {
    return playList[0];
  }

  const index = playList.findIndex(x => x.endsWith(path.basename(lastFileName)));

  if (index === -1) {
    return playList[0];
  }
  return playList[index];
};

const findNextFileName = (currentFileName, playList) => {
  const index = playList.findIndex(x => x.endsWith(path.basename(currentFileName)));

  if (index >= playList.length - 1) {
    return playList[0];
  }

  return playList[index + 1];
};


export const createRepeater = ({ play, saveConfig }) => {
  const repeat = (lastFileName, playList, speed) => {
    const p = play(lastFileName, speed);

    saveConfig(lastFileName, speed);

    let tempSpeed = speed;
    let shouldPlayNext = false;

    p.stdout.on('data', (data) => {
      if (data.includes(' x')) {
        tempSpeed = String(data).split(' x').at(1).slice(0, 4);
      }
      if (data.includes('End of file') || data.includes('Some errors happened')) {
        shouldPlayNext = true;
      }
    });

    p.once('close', () => {
      saveConfig(lastFileName, tempSpeed);
      console.log('exit');

      if (shouldPlayNext) {
        const nextFileName = findNextFileName(lastFileName, playList);
        repeat(nextFileName, playList, tempSpeed);
      }
    });
  };

  return { repeat };
};

const saveConfig = (lastFileName, speed) => {
  const json = {
    lastFileName,
    speed,
  };
  fs.writeFileSync('./repeat_player.json', JSON.stringify(json));
};

const loadConfig = () => {
  try {
    const file = fs.readFileSync('./repeat_player.json');
    const json = JSON.parse(file);
    return json;
  } catch (_e) {
    return {};
  }
};

const main = async () => {
  const targetDirs = process.argv.slice(2);
  const playList = targetDirs.filter(dir => fs.existsSync(dir))
    .flatMap((dir) => fs.globSync(`${dir}/**/*`))
    .filter(x => EXTENSIONS.some(ext => x.endsWith(ext)));
  playList.sort();
  const conf = loadConfig();
  const lastFileName = lastFileExistsInPlayList(conf.lastFileName, playList);
  const speed = conf.speed ?? DEFAULT_SPEED;
  createRepeater({ play, saveConfig }).repeat(lastFileName, playList, speed);
};

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main();
}
