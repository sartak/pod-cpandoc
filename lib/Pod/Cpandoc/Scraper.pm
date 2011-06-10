package Pod::Cpandoc::Scraper;
use strict;
use warnings;
use File::Temp 'tempfile';
use HTTP::Tiny;

sub get_documentation_for {
    my $self   = shift;
    my $module = shift;

    my $ua = HTTP::Tiny->new;
    my $response = $ua->get(
        "http://api.metacpan.org/pod/$module",
        { headers => { 'Content-Type' => 'application/x-perl' } },
    );
    return unless $response->{success};

    $module =~ s/::/-/g;
    my ($fh, $fn) = tempfile("${module}-XXXX", UNLINK => 1);
    print { $fh } $response->{content};
    close $fh;

    return $fn;
}

1;

