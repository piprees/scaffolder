'use server';

import { DefaultConfig } from '../generated';

export async function getSignInLink(returnTo: string) {
  const oauth = new URL('/oauth2/authorization/github', DefaultConfig.basePath);
  oauth.searchParams.set('return_to', returnTo);
  return oauth.toString();
}
