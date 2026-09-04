const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send(`
    <html>
      <head><title>Azure CI/CD Demo</title></head>
      <body style="font-family: sans-serif; text-align: center; margin-top: 100px;">
        <h1>🚀 Deployed via GitHub Actions + Azure App Service</h1>
        <p>Version: ${process.env.APP_VERSION || 'local-dev'}</p>
        <p>Deployed at: ${new Date().toISOString()}</p>
      </body>
    </html>
  `);
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

app.listen(port, () => {
  console.log(`App listening on port ${port}`);
});
