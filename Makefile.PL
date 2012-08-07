use inc::Module::Install;

name           'Pod-Cpandoc';
all_from       'lib/Pod/Cpandoc.pm';
readme_from    'lib/Pod/Cpandoc.pm';
githubmeta;

requires       'HTTP::Tiny';
requires       'Archive::Tar';
requires       'Archive::Zip';
requires       'File::Spec';
requires       'IO::Uncompress::Gunzip';

install_script 'bin/cpandoc';

manifest_skip;
auto_manifest;
WriteAll;

