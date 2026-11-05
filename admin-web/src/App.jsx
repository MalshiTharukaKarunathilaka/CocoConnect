import { useEffect, useState } from 'react'
import { authApi } from './api'
import AdminApp from './AdminApp'

function Login({ onLogin }) {
  const [phone, setPhone] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  async function submit(event) {
    event.preventDefault()
    setBusy(true)
    setError('')
    try {
      const result = await authApi.login(phone, password)
      if (result.user?.role !== 'ADMIN') {
        throw new Error('This account is not an admin. Ask the team to set role = ADMIN.')
      }
      onLogin(result)
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <main className="login-page">
      <form className="login-card" onSubmit={submit}>
        <h1>CocoConnect Admin</h1>
        <p>Sign in with an ADMIN account to manage the marketplace.</p>
        {error && <div className="error">{error}</div>}
        <label>
          Phone
          <input
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="07XXXXXXXX"
            required
          />
        </label>
        <label>
          Password
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </label>
        <button className="login-submit" type="submit" disabled={busy}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
        <p className="hint">
          Backend must be running on port 5000. To make a user admin, run in Supabase:
          <br />
          <code>update users set role = &apos;ADMIN&apos; where phone = &apos;07XXXXXXXX&apos;;</code>
        </p>
      </form>
    </main>
  )
}

export default function App() {
  const [session, setSession] = useState(null)
  const [booting, setBooting] = useState(true)

  useEffect(() => {
    const token = localStorage.getItem('cococonnect_admin_token')
    if (!token) {
      setBooting(false)
      return
    }
    authApi
      .me()
      .then((user) => {
        if (user.role !== 'ADMIN') {
          localStorage.removeItem('cococonnect_admin_token')
          return
        }
        setSession({ token, user })
      })
      .catch(() => localStorage.removeItem('cococonnect_admin_token'))
      .finally(() => setBooting(false))
  }, [])

  function handleLogin(result) {
    localStorage.setItem('cococonnect_admin_token', result.token)
    setSession({ token: result.token, user: result.user })
  }

  function logout() {
    localStorage.removeItem('cococonnect_admin_token')
    setSession(null)
  }

  if (booting) return <div style={{ padding: 40 }}>Loading…</div>
  if (!session) return <Login onLogin={handleLogin} />
  return <AdminApp user={session.user} logout={logout} />
}
