// logger.js — journal console + fichier logs/deploy-<date>.log
import fs from 'fs';
import path from 'path';
import { config } from './config.js';

const dir = path.join(config.root, 'logs');
fs.mkdirSync(dir, { recursive: true });
const file = path.join(dir, `deploy-${new Date().toISOString().slice(0, 10)}.log`);

function write(line) {
  fs.appendFileSync(file, line + '\n');
}

const stamp = () => new Date().toISOString().slice(11, 19);

export const log = {
  info: (m) => { const l = `[${stamp()}] ${m}`; console.log(l); write(l); },
  ok: (m) => { const l = `[${stamp()}] ✓ ${m}`; console.log('\x1b[32m%s\x1b[0m', l); write(l); },
  skip: (m) => { const l = `[${stamp()}] ↷ ${m}`; console.log('\x1b[33m%s\x1b[0m', l); write(l); },
  err: (m) => { const l = `[${stamp()}] ✗ ${m}`; console.log('\x1b[31m%s\x1b[0m', l); write(l); },
  file,
};
