
import fs from 'node:fs';
import { spawn } from 'child_process';
import path from 'node:path';

const DEFAULT_SPEED = '1.95';
const MAX_WIDTH = '640'
const POSITION_TOP = '0%';
const POSITION_LEFT = '100%'

const play = (fileName, speed) => {
  console.info(`playing ${fileName}`)
  return spawn('mpv', ['--save-position-on-quit', `--speed=${speed}`, `--geometry=${MAX_WIDTH}+${POSITION_LEFT}+${POSITION_TOP}`, fileName])
}

const lastFileExistsInPlayList = (lastFileName, playList) => {
  if (!lastFileName) {
    return playList[0]
  }

  const index = playList.findIndex(x => x.endsWith(path.basename(lastFileName)));

  if (index === -1) {
    return playList[0]
  }
  return playList[index]
}

const findNextFileName = (currentFileName, playList) => {
  const index = playList.findIndex(x => x.endsWith(path.basename(currentFileName)));

  if (index >= playList.length - 1) {
    return playList[0];
  }

  return playList[index + 1]
}


const repeat = (lastFileName, playList, speed) => {
  const p = play(lastFileName, speed);

  let tempSpeed = speed;
  p.stdout.on('data', (data) => {
    if (data.includes(' x')) {
      tempSpeed = String(data).split(' x').at(1).slice(0, 4);
    }
    if (data.includes('End of file')) {
      const nextFileName = findNextFileName(lastFileName, playList)
      repeat(nextFileName, playList, tempSpeed)
    }
  })

  p.on('exit', () => {
    saveConfig(lastFileName, tempSpeed);
  })

  // exit by Cmd+c
  process.on('SIGINT', () => {
    saveConfig(lastFileName, tempSpeed)
    process.exit()
  })

}

const saveConfig = (lastFileName, speed) => {
  const json = {
    lastFileName,
    speed
  }
  fs.writeFileSync('./repeat_player.json', JSON.stringify(json))
}

const loadConfig = () => {
  try {
    const file = fs.readFileSync('./repeat_player.json')
    const json = JSON.parse(file);
    return json
  } catch (_e) {
    return {}
  }
}

const main = async () => {
  const targetDir = process.argv[2];
  const playList = await fs.globSync(`${targetDir}/**/*`)
    .filter(x => ['mp4', 'mkv', 'avi'].some(ext => x.endsWith(ext)))
  playList.sort()
  const conf = loadConfig()
  const lastFileName = lastFileExistsInPlayList(conf.lastFileName, playList)
  const speed = conf.speed ?? DEFAULT_SPEED;
  repeat(lastFileName, playList, speed)
}

main()
