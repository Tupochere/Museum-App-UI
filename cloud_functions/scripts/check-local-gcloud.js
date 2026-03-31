const { execSync } = require('child_process');
const { GoogleAuth } = require('google-auth-library');

function run(command) {
  try {
    return execSync(command, {
      stdio: ['ignore', 'pipe', 'ignore'],
      encoding: 'utf8',
    }).trim();
  } catch (_) {
    return '';
  }
}

function getProjectId() {
  const envProject =
    process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT || '';
  if (envProject) {
    return {
      value: envProject,
      source: 'environment',
    };
  }

  const gcloudCommand =
    process.platform === 'win32'
      ? 'gcloud.cmd config get-value project'
      : 'gcloud config get-value project';
  const configuredProject = run(gcloudCommand);
  if (configuredProject && configuredProject !== '(unset)') {
    return {
      value: configuredProject,
      source: 'gcloud config',
    };
  }

  return {
    value: '',
    source: '',
  };
}

function printProjectHelp() {
  console.error('');
  console.error('Project id not found.');
  console.error('Set one of these before starting the local proxy:');
  if (process.platform === 'win32') {
    console.error('  gcloud.cmd config set project YOUR_PROJECT_ID');
    console.error('  $env:GOOGLE_CLOUD_PROJECT = "YOUR_PROJECT_ID"');
  } else {
    console.error('  gcloud config set project YOUR_PROJECT_ID');
    console.error('  export GOOGLE_CLOUD_PROJECT="YOUR_PROJECT_ID"');
  }
}

function printAdcHelp(projectId) {
  console.error('');
  console.error('Application Default Credentials are missing or invalid.');
  if (process.platform === 'win32') {
    console.error('Run these commands in PowerShell:');
    console.error('  gcloud.cmd auth login');
    console.error('  gcloud.cmd auth application-default login');
    console.error(`  $env:GOOGLE_CLOUD_PROJECT = "${projectId}"`);
  } else {
    console.error('Run these commands in your shell:');
    console.error('  gcloud auth login');
    console.error('  gcloud auth application-default login');
    console.error(`  export GOOGLE_CLOUD_PROJECT="${projectId}"`);
  }
  console.error('');
  console.error(
    'The local proxy uses ADC for Vertex AI, Translation, and Text-to-Speech.',
  );
}

async function checkAdc() {
  const auth = new GoogleAuth();
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  return typeof token === 'string' ? token : token?.token;
}

async function main() {
  console.log('Checking local Google Cloud setup for mtengatenga-ai-proxy...');

  const project = getProjectId();
  if (!project.value) {
    printProjectHelp();
    process.exitCode = 1;
    return;
  }

  console.log(`Project id: ${project.value} (${project.source})`);

  try {
    await checkAdc();
    console.log('Application Default Credentials: ok');
    console.log('Local proxy is ready to call Google Cloud APIs.');
  } catch (_error) {
    printAdcHelp(project.value);
    process.exitCode = 1;
  }
}

main();
