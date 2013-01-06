use inc::Module::Install;

name           'Pod-Cpandoc';
all_from       'lib/Pod/Cpandoc.pm';
readme_from    'lib/Pod/Cpandoc.pm';
githubmeta;

requires       'HTTP::Tiny';
requires       'JSON';

install_script 'bin/cpandoc';

manifest_skip;
auto_manifest;
WriteAll;

