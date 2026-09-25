const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const cli = path.join(root, 'backend/firebase/functions/node_modules/firebase-tools/lib');
const {getGlobalDefaultAccount} = require(path.join(cli, 'auth'));
const {requireAuth} = require(path.join(cli, 'requireAuth'));
const rules = require(path.join(cli, 'gcp/rules'));

async function main() {
  const project = 'stewardie';
  const rulesPath = path.join(root, 'backend/firebase/firestore.rules');
  const content = fs.readFileSync(rulesPath, 'utf8');

  console.log(`Authenticating for project ${project}...`);
  await requireAuth({project, ...getGlobalDefaultAccount()});

  const files = [{name: 'firestore.rules', content}];

  console.log('Testing ruleset syntax with Google Firebase API...');
  const testResult = await rules.testRuleset(project, files);
  if (testResult.status !== 200) {
    throw new Error(`Ruleset validation failed: ${JSON.stringify(testResult.body)}`);
  }
  console.log('Ruleset syntax validated successfully.');

  console.log('Creating new ruleset on Firebase...');
  const rulesetName = await rules.createRuleset(project, files);
  console.log(`Created ruleset: ${rulesetName}`);

  console.log('Updating release cloud.firestore...');
  const releaseName = await rules.updateOrCreateRelease(project, rulesetName, 'cloud.firestore');
  console.log(`Successfully released: ${releaseName} with ${rulesetName}`);

  console.log('Verifying active ruleset...');
  const releases = await rules.listAllReleases(project);
  const active = releases.find(r => r.name.includes('cloud.firestore'));
  console.log('Active release now:', JSON.stringify(active, null, 2));
}

main().catch(err => {
  console.error('Deployment error:', err);
  process.exit(1);
});
