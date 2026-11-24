# How to share KapConnect with friends

Your project folder is **not yet on GitHub**. Follow these steps once.

## 1. Create a GitHub account repo

1. Open https://github.com/new
2. Name it `KapConnect`
3. Keep it **Private** if the client work is confidential
4. Do **not** add a README on GitHub (we already have files locally)
5. Click **Create repository**

## 2. Put this folder into Git (one-time on your PC)

Open PowerShell in `KapConnect` and run:

```powershell
git init
git add .
git commit -m "Share working KapConnect demo with team"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/KapConnect.git
git push -u origin main
```

Replace `YOUR_USERNAME` with your GitHub username.

If `git` is missing, install: https://git-scm.com/download/win  
If `git push` asks you to log in, use GitHub Login / Personal Access Token.

## 3. Invite friends

On the GitHub repo page:

1. **Settings → Collaborators → Add people**
2. Add each friend’s GitHub username
3. They accept the email invite

## 4. Friends clone and run

```powershell
git clone https://github.com/YOUR_USERNAME/KapConnect.git
cd KapConnect
```

**Start everything:**

1. Double-click `backend\start-api.bat` (API on port 8080)
2. Double-click `kapconnect-web\start-web.bat` (website on port 5173)
   Or use `start-kapconnect-system.bat` for both.

**Demo login OTP:** `123456`

| Role | Phone |
|------|-------|
| Buyer | `0771234567` |
| Estate | `0715550199` |
| Admin | `0700000000` |

## 5. What friends need installed

| Tool | Why |
|------|-----|
| Node.js 20+ | Express API + React website |
| Git | Download/share code |
| Docker (optional) | PostgreSQL database |

Flutter is **not** in the repo yet. Install Flutter later for the real mobile app.

## 6. Safety rules

- Never commit `.env`, Firebase keys, or password files
- Keep the repo **Private** until the client agrees it can be public
- Friends should pull before they push: `git pull` then `git push`
