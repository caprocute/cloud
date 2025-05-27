import fs from 'fs';
import path from 'path';
import process from 'process';
import { execSync } from 'child_process';

function findVueFiles(dir) {
  let results = [];
  const list = fs.readdirSync(dir);

  list.forEach((file) => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      results = results.concat(findVueFiles(filePath));
    } else if (file.endsWith('.vue')) {
      results.push(path.resolve(filePath));
    }
  });

  return results;
}

const vueFiles = findVueFiles('./src');
let tempFileCreated = false;

vueFiles.forEach((file) => {
  const dir = path.dirname(file);

  console.log(file);

  const content = fs.readFileSync(file, 'utf-8');

  const scssMatch = content.match(
    /<style lang="scss">([\s\S]*?)<\/style>/,
  );
  if (scssMatch) {
    const scssCode = scssMatch[1].trim();

    // process.chdir(dir);

    fs.writeFileSync('temp.scss', scssCode);
    tempFileCreated = true;

    execSync('sass-migrator module temp.scss');

    const migratedScss = fs.readFileSync('temp.scss', 'utf-8');

    const updatedContent = content.replace(scssMatch[1], `\n${migratedScss}\n`);
    fs.writeFileSync(file, updatedContent);
    fs.unlinkSync('temp.scss');
  }
});

if (tempFileCreated) {
  fs.unlinkSync('temp.scss');
}
