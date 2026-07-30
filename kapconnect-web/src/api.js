const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080/api/v1'

export async function api(path, options = {}) {
  const token = localStorage.getItem('kapconnect_token')
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
    throw new Error(body?.error || body?.message || `Request failed (${response.status})`)
  }
  return body
}

export const authApi = {
  sendOtp: (phone) =>
    api('/auth/otp/send', { method: 'POST', body: JSON.stringify({ phone }) }),
  verifyOtp: (phone, code) =>
    api('/auth/otp/verify', { method: 'POST', body: JSON.stringify({ phone, code }) }),
  register: (details) =>
    api('/auth/register', { method: 'POST', body: JSON.stringify(details) }),
}
