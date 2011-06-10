package Pod::Cpandoc::Scraper;
use strict;
use warnings;
use URI;
use Web::Scraper;
use File::Temp 'tempfile';
use LWP::Simple;

sub get_documentation_for {
    my $self   = shift;
    my $module = shift;

    my $cpan = scraper {
        process "h2.sr>a", url => '@href';
    };
    my $res = $cpan->scrape(URI->new("http://search.cpan.org/search?mode=module&query=$module"));

    (my $url = $res->{url}) =~ s/author/src/;
    $url =~ s{~(\w+)}{"src/".uc($1)}e;
    my $contents = get($url);

    $module =~ s/::/-/g;
    my ($fh, $fn) = tempfile("${module}-XXXX", UNLINK => 1);
    print { $fh } $contents;
    close $fh;

    return $fn;
}

1;

