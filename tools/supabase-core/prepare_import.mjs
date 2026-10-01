import {readFile,writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {planImport,renderImportSql} from './import_plan.mjs';
const args=process.argv.slice(2);
const arg=k=>args[args.indexOf(k)+1];
if(!args.includes('--input'))throw new Error('Use --input EXPORT.json; add --sql OUTPUT.sql to prepare a reviewed import');
const bundle=JSON.parse(await readFile(resolve(arg('--input')),'utf8'));
const plan=planImport(bundle);
console.log(JSON.stringify({checksum:plan.checksum,counts:plan.counts,warnings:plan.warnings},null,2));
if(args.includes('--sql')) {
  if(bundle.writesFrozen!==true)throw new Error('SQL import requires a snapshot taken with writes frozen');
  await writeFile(resolve(arg('--sql')),renderImportSql(plan),{flag:'wx',mode:0o600});
  console.log('Import SQL prepared; not applied. Contains private data: do not commit it.');
}

