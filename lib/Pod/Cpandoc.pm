package Pod::Cpandoc;
use 5.8.1;
use strict;
use warnings;
use base 'Pod::Perldoc';
use HTTP::Tiny;
use File::Temp 'tempfile';

our $VERSION = '0.05';

sub unlink_tempfiles {
    my $self = shift;
    return $self->opt_l ? 0 : 1;
}

sub scrape_documentation_for {
    my $self   = shift;
    my $module = shift;

    $self->aside("Going to query api.metacpan.org for $module\n");

    my $ua = HTTP::Tiny->new(
        agent => "cpandoc/$VERSION",
    );

    my $response = $ua->get(
        "http://api.metacpan.org/pod/$module",
        { headers => { 'Content-Type' => 'text/x-pod' } },
    );
    return unless $response->{success};

    $module =~ s/::/-/g;
    my ($fh, $fn) = tempfile(
        "${module}-XXXX",
        UNLINK => $self->unlink_tempfiles,
        TMPDIR => 1,
    );
    print { $fh } $response->{content};
    close $fh;

    return $fn;
}

sub grand_search_init {
    my $self = shift;
    my @found = $self->SUPER::grand_search_init(@_);

    if (@found == 0) {
        my $pages = shift;

        for my $module (@$pages) {
            my @files = $self->scrape_documentation_for($module);
            if (@files == 0) {
                $self->real_report_no_matches($module);
            }
            push @found, @files;
        }
    }

    return @found;
}

sub opt_V {
    my $self = shift;

    print "Cpandoc v$VERSION, ";

    return $self->SUPER::opt_V(@_);
}

# these next two functions attempt to cover Pod-Perldoc versions
# with and without my report_no_matches patch
sub real_report_no_matches {
    my $self = shift;

    # if SUPER::can('report_no_matches') fails, then we have already reported
    # no matches before even trying to scrape CPAN
    if ($self->SUPER::can('report_no_matches')) {
        $self->SUPER::report_no_matches(@_);
    }
}

# don't report_no_matches until we've tried scraping CPAN
sub report_no_matches { }

1;

__END__

=head1 NAME

Pod::Cpandoc - perldoc that works for modules you don't have installed

=head1 SYNOPSIS

    cpandoc File::Find
        -- shows the documentation of your installed File::Find

    cpandoc Acme::BadExample
        -- works even if you don't have Acme::BadExample installed!

    cpandoc -v '$?'
        -- passes everything through to regular perldoc

    cpandoc -tT Acme::BadExample | grep -i acme
        -- options are respected even if the module was scraped

    vim `cpandoc -l Web::Scraper`
        -- getting the idea yet?

=head1 DESCRIPTION

C<cpandoc> is a perl script that acts like C<perldoc> except that
if it would have bailed out with
C<No documentation found for "Uninstalled::Module">, it will instead
scrape a CPAN index for the module's documentation.

One important feature of C<cpandoc> is that it I<only> scrapes the
live index if you do not have the module installed. So if you use
C<cpandoc> on a module you already have installed, then it will
just read the already-installed documentation. This means that the
version of the documentation matches up with the version of the
code you have. As a fringe benefit, C<cpandoc> will be fast for
modules you've installed. :)

All this means that you should be able to drop in C<cpandoc> in
place of C<perldoc> and have everything keep working. See
L</SNEAKY INSTALL> for how to do this.

=head1 SNEAKY INSTALL

    cpanm Pod::Cpandoc

    then: alias perldoc=cpandoc
    or:   function perldoc () { cpandoc "$@" }

    Now `perldoc Acme::BadExample` works!

C<perldoc> should continue to work for everything that you're used
to, since C<cpandoc> passes all options through to it. C<cpandoc>
is merely a subclass that falls back to scraping a CPAN index when
it fails to find your queried file in C<@INC>.

=head1 SEE ALSO

The sneaky install was inspired by L<https://github.com/defunkt/hub>.

http://tech.bayashi.jp/archives/entry/perl-module/2011/003305.html

=head1 AUTHOR

Shawn M Moore C<sartak@gmail.com>

=head1 COPYRIGHT

Copyright 2011 Shawn M Moore.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

