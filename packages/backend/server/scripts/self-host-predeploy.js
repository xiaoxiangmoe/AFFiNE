import { execSync } from 'node:child_process';
import { generateKeyPairSync } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

import { parse } from 'dotenv';

const SELF_HOST_CONFIG_DIR = '/root/.affine/config';
/**
 * @type {Array<{ from: string; to?: string, modifier?: (content: string): string }>}
 */
const configFiles = [
  { from: './dist/config/affine.js', modifier: configCleaner },
  { from: './dist/config/affine.env.js', modifier: configCleaner },
];

function configCleaner(content) {
  return content.replace(
    /(^\/\/#.*$)|(^\/\/\s+TODO.*$)|("use\sstrict";?)|(^.*eslint-disable.*$)/gm,
    ''
  );
}

const datasource = {
  user: process.env.DB_USER || 'affine',
  password: process.env.DB_PASSWORD || '',
  host: process.env.DB_HOST || 'postgres',
  port: process.env.DB_PORT || 5432,
  databaseName: process.env.DB_DATABASE_NAME || 'affine',
};

function getDatasourceUrl() {
  return (
    process.env.DATABASE_URL ||
    `postgres://${datasource.user}:${datasource.password}@${datasource.host}:${datasource.port}/${datasource.databaseName}`
  );
}

function prepare() {
  fs.mkdirSync(SELF_HOST_CONFIG_DIR, { recursive: true });
  process.env.DATABASE_URL = getDatasourceUrl();

  for (const { from, to, modifier } of configFiles) {
    const targetFileName = to ?? path.parse(from).base;
    const targetFilePath = path.join(SELF_HOST_CONFIG_DIR, targetFileName);
    if (!fs.existsSync(targetFilePath)) {
      console.log(`creating config file [${targetFilePath}].`);
      if (modifier) {
        const content = fs.readFileSync(from, 'utf-8');
        fs.writeFileSync(targetFilePath, modifier(content), 'utf-8');
      } else {
        fs.cpSync(from, targetFilePath, {
          force: false,
        });
      }
    }

    // make the default .env
    if (to === '.env') {
      const dotenvFile = fs.readFileSync(targetFilePath, 'utf-8');
      const envs = parse(dotenvFile);
      // generate a new private key
      if (!envs.AFFINE_PRIVATE_KEY) {
        const privateKey = generateKeyPairSync('ec', {
          namedCurve: 'prime256v1',
        }).privateKey.export({
          type: 'sec1',
          format: 'pem',
        });

        fs.writeFileSync(
          targetFilePath,
          `AFFINE_PRIVATE_KEY=${privateKey}\n` + dotenvFile
        );
      }
    }
  }
}

function runPredeployScript() {
  console.log('running predeploy script.');
  execSync('yarn predeploy', {
    encoding: 'utf-8',
    env: process.env,
    stdio: 'inherit',
  });
}

prepare();
runPredeployScript();
