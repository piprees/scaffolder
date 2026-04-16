import { logoutAction } from '../util/logoutAction';

export default function Unauthorised() {
  return (
    <main>
      <h1>Unauthorised</h1>
      <p>You are not permitted to access this page.</p>
      <form action={logoutAction} method="post">
        <button type="submit">Sign out</button>
      </form>
    </main>
  );
}
