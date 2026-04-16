import SignIn from '../../components/sign-in';
import Unauthorised from '../../components/unauthorised';
import { getUser } from '../../util/getUser';
import { logoutAction } from '../../util/logoutAction';

export default async function AdminPage() {
  const user = await getUser();

  if (!user) {
    return <SignIn returnPath="/admin" />;
  }

  if (user.role !== 'ADMIN') return <Unauthorised />;

  return (
    <main>
      <h1>Admin area</h1>
      <p>
        Signed in as {user.username} (id: {user.id})
      </p>
      <form action={logoutAction} method="post">
        <button type="submit">Sign out</button>
      </form>
    </main>
  );
}
