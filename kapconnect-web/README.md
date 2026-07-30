# KapConnect Web

Working React frontend for the KapConnect Spring Boot API.

## Start the full system

Double-click `start-kapconnect-system.bat` in the parent folder. It starts both the API and this website, then opens the browser.

Website: http://127.0.0.1:5173

## Demo users

- Buyer: `0771234567`
- Estate owner: `0715550199`
- Admin: `0700000000`
- OTP for all demo accounts: `123456`

The login screen has quick buttons for each demo role.

## Frontend only

```bash
npm install
npm run dev
```

Why there are separate start scripts: the API and website are two different programs. The root script starts both in the correct order.
