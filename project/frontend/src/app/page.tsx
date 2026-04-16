import { DefaultApi } from '../generated';

export default async function Page() {
  const api = new DefaultApi();
  const greeting = await api.getGreeting();

  return (
    <main>
      <h1>Hello, World!</h1>
      <p>{greeting.message}</p>
    </main>
  );
}
