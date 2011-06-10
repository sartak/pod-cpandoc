use inc::Module::Install;

name       'Pod-Cpandoc';
all_from   'lib/Pod/Cpandoc.pm';
repository 'http://github.com/sartak/pod-cpandoc';

requires 'Pod::Perldoc';
requires 'File::Temp';
requires 'HTTP::Tiny';

install_script('bin/cpandoc');

WriteAll;

