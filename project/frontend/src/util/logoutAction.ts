'use server';

import { headers } from 'next/headers';
import { redirect } from 'next/navigation';
import { DefaultApi } from '../generated';

export async function logoutAction(_: FormData) {
  const hdrs = await headers();
  const cookie = hdrs.get('cookie') || '';

  const api = new DefaultApi();
  try {
    await api.logout({ headers: { cookie }, credentials: 'include' } as RequestInit);
  } catch (e) {
    // best-effort logout
  }

  return redirect('/');
}
