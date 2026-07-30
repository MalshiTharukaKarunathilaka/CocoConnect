const config = require('./config');
const { app } = require('./app');

app.listen(config.port, () => {
  console.log(`KapConnect API (Express) running on http://localhost:${config.port}`);
  console.log(`Health: http://localhost:${config.port}/api/v1/health`);
  console.log(`Demo OTP code = ${config.otpDemoCode}`);
});
