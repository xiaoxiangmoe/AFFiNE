import './config';

import { Global, Module, Provider } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

import { Config } from '../config';
import { PrismaService } from './service';

export function getDatasourceUrl(config: Config) {
  const database = config.prisma.database;
  if ('datasourceUrl' in database) {
    return database.datasourceUrl;
  }
  console.log(database.user);
  return `postgres://${database.user}:${database.password}@${database.host}:${database.port}/${database.databaseName}`;
}

// only `PrismaClient` can be injected
const clientProvider: Provider = {
  provide: PrismaClient,
  useFactory: (config: Config) => {
    if (PrismaService.INSTANCE) {
      return PrismaService.INSTANCE;
    }
    console.log(getDatasourceUrl(config));

    return new PrismaService({
      ...config.prisma.options,
      datasourceUrl: getDatasourceUrl(config),
    });
  },
  inject: [Config],
};

@Global()
@Module({
  providers: [clientProvider],
  exports: [clientProvider],
})
export class PrismaModule {}
export { PrismaService } from './service';

export type PrismaTransaction = Parameters<
  Parameters<PrismaClient['$transaction']>[0]
>[0];
