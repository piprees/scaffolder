import { headers } from 'next/headers';
import { DefaultApi } from '../generated';

export type User = { id: number; username: string; role: string } | null;

export async function getUser(): Promise<User | null> {
  const hdrs = await headers();
  const cookie = hdrs.get('cookie') || '';
  const api = new DefaultApi();

  let user: User = null;
  try {
    user = await api.me({ headers: { cookie }, credentials: 'include' } as RequestInit);
  } catch (_e) {
    return null;
  }

  return user;
}
