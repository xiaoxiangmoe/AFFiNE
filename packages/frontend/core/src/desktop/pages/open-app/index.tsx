import { OpenInAppPage } from '@affine/core/modules/open-in-app/views/open-in-app-page';
import { appSchemaUrl, appSchemes } from '@affine/core/utils';
import type { GetCurrentUserQuery } from '@affine/graphql';
import { fetcher, getCurrentUserQuery } from '@affine/graphql';
import type { LoaderFunction } from 'react-router-dom';
import { redirect, useLoaderData } from 'react-router-dom';
import { z } from 'zod';

const LoaderData = z.object({
  action: z.enum(['url', 'signin-redirect']),
  url: appSchemaUrl,
  params: z.record(z.string()),
});

type LoaderData = z.infer<typeof LoaderData> & {
  currentUser?: GetCurrentUserQuery['currentUser'];
};

const OpenUrl = () => {
  const { params, url } = useLoaderData() as LoaderData;

  if (!url) {
    return null;
  }

  const urlObj = new URL(url || '');

  Object.entries(params).forEach(([k, v]) => {
    urlObj.searchParams.set(k, v);
  });

  return <OpenInAppPage urlToOpen={urlObj.toString()} />;
};

/**
 * @deprecated
 */
const OpenOAuthJwt = () => {
  const { currentUser, params } = useLoaderData() as LoaderData;

  const maybeScheme = appSchemes.safeParse(params['scheme']);
  const scheme = maybeScheme.success ? maybeScheme.data : 'affine';

  if (!currentUser || !currentUser?.token?.sessionToken) {
    return null;
  }

  const urlToOpen = `${scheme}://signin-redirect?token=${
    currentUser.token.sessionToken
  }&next=${params['next'] || ''}`;

  return <OpenInAppPage urlToOpen={urlToOpen} />;
};

export const Component = () => {
  const { action } = useLoaderData() as LoaderData;

  if (action === 'url') {
    return <OpenUrl />;
  } else if (action === 'signin-redirect') {
    return <OpenOAuthJwt />;
  }
  return null;
};

export const loader: LoaderFunction = async args => {
  const action = args.params.action || '';

  try {
    const { url, ...params } = Array.from(
      new URL(args.request.url).searchParams.entries()
    ).reduce(
      (acc, [k, v]) => ((acc[k] = v), acc),
      {} as Record<string, string>
    );
    const res =
      (action === 'signin-redirect' &&
        (await fetcher({
          query: getCurrentUserQuery,
        }).catch(console.error))) ||
      null;

    return Object.assign(LoaderData.parse({ action, url, params }), {
      currentUser: res?.currentUser || null,
    });
  } catch (e) {
    console.error(e);
    return redirect('/404');
  }
};
