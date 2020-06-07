var shell = require('shelljs');
 
if (!shell.which('git')) {
  shell.echo('Sorry, this script requires git');
  shell.exit(1);
}

shell.cd('test');
shell.chmod('755', 'test/build-test.sh');
if (shell.exec('./build-test.sh').code !== 0) {
  shell.echo('Error: test build failed');
  shell.exit(1);
}
