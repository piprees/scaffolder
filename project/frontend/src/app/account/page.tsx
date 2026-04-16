import SignIn from '../../components/sign-in';
import { getUser } from '../../util/getUser';
import { logoutAction } from '../../util/logoutAction';

export default async function AccountPage() {
  const user = await getUser();

  if (!user) {
    return <SignIn returnPath="/account" />;
  }

  return (
    <main>
      <h1>Account area</h1>
      <p>
        Signed in as {user.username} (id: {user.id})
      </p>
      <form action={logoutAction} method="post">
        <button type="submit">Sign out</button>
      </form>
    </main>
  );
}
