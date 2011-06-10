use inc::Module::Install;

name       'Pod-Cpandoc';
all_from   'lib/Pod/Cpandoc.pm';
repository 'http://github.com/sartak/pod-cpandoc';

requires 'Pod::Perldoc';
requires 'Web::Scraper';
requires 'File::Temp';
requires 'LWP::Simple';
requires 'URI';

install_script('bin/cpandoc');

WriteAll;

