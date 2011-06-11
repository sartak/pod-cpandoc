use inc::Module::Install;

name           'Pod-Cpandoc';
all_from       'lib/Pod/Cpandoc.pm';
readme_from    'lib/Pod/Cpandoc.pm';
repository     'http://github.com/sartak/pod-cpandoc';

requires       'HTTP::Tiny';

install_script 'bin/cpandoc';

WriteAll;

