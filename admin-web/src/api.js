const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api'

export async function api(path, options = {}) {
  const token = localStorage.getItem('cococonnect_admin_token')
  const response = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
  })

  const body = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error(body?.message || body?.error || `Request failed (${response.status})`)
  }
  return body
}

export const authApi = {
  login: (phone, password) =>
    api('/auth/login', { method: 'POST', body: JSON.stringify({ phone, password }) }),
  me: () => api('/auth/me'),
}
