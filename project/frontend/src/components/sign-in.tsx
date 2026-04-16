import { getSignInLink } from '../util/getSignInLink';

export default async function SignIn({ returnPath }: { returnPath: string }) {
  const signInLink = await getSignInLink(returnPath);
  return (
    <main>
      <h1>Sign in required</h1>
      <p>
        <a href={signInLink}>Sign in with GitHub</a>
      </p>
    </main>
  );
}
