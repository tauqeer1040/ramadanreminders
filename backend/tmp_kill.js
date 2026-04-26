const { execSync } = require('child_process');
try {
  execSync('taskkill /F /PID 23952 /T');
  console.log('Killed 23952');
} catch (e) {
  console.log('PID not found');
}
