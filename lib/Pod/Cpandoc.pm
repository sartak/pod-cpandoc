package Pod::Cpandoc;
use strict;
use warnings;
use base 'Pod::Perldoc';
use Pod::Cpandoc::Scraper;

our $VERSION = '0.01';

use constant scraper => 'Pod::Cpandoc::Scraper';

sub grand_search_init {
    my $self = shift;
    my @found = $self->SUPER::grand_search_init(@_);

    if (@found == 0) {
        my $pages = shift;

        for my $module (@$pages) {
            push @found, $self->scraper->get_documentation_for($module);
        }
    }

    return @found;
}

1;

