import type { Prisma } from '@prisma/client';

import { defineStartupConfig, ModuleConfig } from '../config';

interface PrismaStartupConfiguration {
  options?: Prisma.PrismaClientOptions;
  database:
    | {
        host: string;
        port: number;
        user: string;
        password: string;
        databaseName: string;
      }
    | {
        datasourceUrl: string;
      };
}

declare module '../config' {
  interface AppConfig {
    prisma: ModuleConfig<PrismaStartupConfiguration>;
  }
}

defineStartupConfig('prisma', {
  database: {
    host: 'localhost',
    port: 5432,
    user: 'affine',
    password: '',
    databaseName: 'affine',
  },
});
