package Pod::Cpandoc;
use 5.8.1;
use strict;
use warnings;
use base 'Pod::Perldoc';

use Archive::Tar;
use Archive::Zip qw(AZ_OK);
use HTTP::Tiny;
use File::Spec;
use File::Temp 'tempfile';
use IO::Uncompress::Gunzip;

our $VERSION = '0.11';

sub live_cpan_url {
    my $self   = shift;
    my $module = shift;

    return "http://api.metacpan.org/source/$module";
}

sub unlink_tempfiles {
    my $self = shift;
    return $self->opt_l ? 0 : 1;
}

sub fetch_url {
    my $self = shift;
    my $url  = shift;

    $self->aside("Going to query $url\n");

    if ($ENV{CPANDOC_FETCH}) {
        print STDERR "Fetching $url\n";
    }

    my $ua = HTTP::Tiny->new(
        agent => "cpandoc/$VERSION",
    );

    my $response = $ua->get($url);

    if (!$response->{success}) {
        $self->aside("Got a $response->{status} error from the server\n");
        return;
    }

    $self->aside("Successfully received " . length($response->{content}) . " bytes\n");
    return $response->{content};
}

sub query_live_cpan_for {
    my $self   = shift;
    my $module = shift;

    my $url = $self->live_cpan_url($module);
    return $self->fetch_url($url);
}

sub use_minicpan {
    my ( $self ) = @_;

    my $rc_file = File::Spec->catfile((getpwuid $<)[7], '.minicpanrc');
    return -e $rc_file;
}

sub get_minicpan_path {
    my ( $self ) = @_;

    my $rc_file = File::Spec->catfile((getpwuid $<)[7], '.minicpanrc');
    my $minicpan_path;

    my $fh;
    unless(open $fh, '<', $rc_file) {
        $self->aside("Unable to open '$rc_file': $!");
        return;
    }
    while(<$fh>) {
        chomp;
        if(/local:\s*(.*)/) {
            $minicpan_path = $1;
            last;
        }
    }
    close $fh;

    return $minicpan_path;
}

sub find_module_archive {
    my ( $self, $module ) = @_;

    my $minicpan_path = $self->get_minicpan_path;

    unless(defined $minicpan_path) {
        $self->aside("Unable to parse minicpan path from .minicpanrc");
        return;
    }

    my $packages = File::Spec->catfile($minicpan_path, 'modules',
        '02packages.details.txt.gz');

    my $h = IO::Uncompress::Gunzip->new($packages);

    my $archive_path;

    while(<$h>) {
        chomp;
        if(/^\Q$module\E\s/) {
            ( undef, undef, $archive_path ) = split;
            last;
        }
    }
    close $h;

    if($archive_path) {
        $archive_path = File::Spec->catfile($minicpan_path, 'authors', 'id',
            $archive_path);
    }
    return $archive_path;
}

sub load_archive {
    my ( $self, $archive_path ) = @_;

    my $archive;

    if($archive_path =~ /\.zip$/) {
        $archive = Archive::Zip->new;
        unless($archive->read($archive_path) == AZ_OK) {
            undef $archive;
        }
    } else { # assume it's a tarball
        $archive = Archive::Tar->new($archive_path);
    }

    return $archive;
}

sub get_archive_files {
    my ( $self, $archive ) = @_;

    if($archive->isa('Archive::Zip')) {
        return $archive->memberNames;
    } else {
        return $archive->list_files;
    }
}

sub find_module_file {
    my ( $self, $module, @files ) = @_;

    $module =~ s!::!/!g;
    $module .= '.pm';

    my $base = $module;
    $base    =~ s!.*/!!;

    my %topdirs = map {
        my $file = $_;
        $file    =~ s!/.*!!;
        $file => 1;
    } @files;

    my $prefix = '';
    if(keys(%topdirs) == 1) { # if all files begin with the same directory,
                              # we strip the top level directory to make
                              # finding files under strange archives easier
        ( $prefix ) = keys(%topdirs);
        $prefix .= '/';
        @files = map { s/^\Q$prefix\E//; $_ } @files;
    }

    my @tests = (
        "lib/$module",
        $module,
        $base,
    );

    foreach my $test (@tests) {
        if(my @matches = grep { $_ eq $test } @files) {
            return $prefix . $matches[0];
        }
    }
}

sub extract_archive_file {
    my ( $self, $archive, $file ) = @_;

    if($archive->isa('Archive::Zip')) {
        return $archive->contents($file);
    } else {
        return $archive->get_content($file);
    }
}

sub fetch_from_minicpan {
    my ( $self, $module ) = @_;

    $self->aside("Fetching documentation from minicpan\n");

    my $archive_path = $self->find_module_archive($module);

    unless(defined $archive_path) {
        $self->aside("Unable to find '$module' in minicpan");
        return;
    }

    my $archive = $self->load_archive($archive_path);
    unless($archive) {
        $self->aside("Unable to load archive '$archive'");
        return;
    }

    my @files = $self->get_archive_files($archive);
    my $file  = $self->find_module_file($module, @files);
    if($file) {
        return $self->extract_archive_file($archive, $file);
    }
}

sub scrape_documentation_for {
    my $self   = shift;
    my $module = shift;

    my $content;
    if ($module =~ m{^https?://}) {
        $content = $self->fetch_url($module);
    }
    else {
        if($self->use_minicpan) {
            $content = $self->fetch_from_minicpan($module);
        }

        unless($content) {
            $content = $self->query_live_cpan_for($module);
        }
    }
    return if !defined($content);

    $module =~ s{.*/}{}; # directories and/or URLs with slashes anger File::Temp
    $module =~ s/::/-/g;
    my ($fh, $fn) = tempfile(
        "${module}-XXXX",
        SUFFIX => ".pm",
        UNLINK => $self->unlink_tempfiles,
        TMPDIR => 1,
    );
    print { $fh } $content;
    close $fh;

    return $fn;
}

our $QUERY_CPAN;
sub grand_search_init {
    my $self = shift;

    local $QUERY_CPAN = 1;
    return $self->SUPER::grand_search_init(@_);
}

sub searchfor {
    my $self = shift;
    my ($recurse,$s,@dirs) = @_;

    my @found = $self->SUPER::searchfor(@_);

    if (@found == 0 && $QUERY_CPAN) {
        $QUERY_CPAN = 0;
        return $self->scrape_documentation_for($s);
    }

    return @found;
}

sub opt_V {
    my $self = shift;

    print "Cpandoc v$VERSION, ";

    return $self->SUPER::opt_V(@_);
}

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

    cpandoc -m Acme::BadExample | grep system
        -- options are respected even if the module was scraped

    vim `cpandoc -l Web::Scraper`
        -- getting the idea yet?

    cpandoc http://darkpan.org/Eval::WithLexicals::AndGlobals
        -- URLs work too!

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

If you set the environment variable C<CPANDOC_FETCH> to a true value,
then we will print a message to STDERR telling you that C<cpandoc> is
going to make a request against the live CPAN index.

=head1 TRANSLATIONS

=over 4

=item Japanese

    Japanese documentation can be found at
    L<http://perldoc.jp/docs/modules/Pod-Cpandoc-0.09/Cpandoc.pod>,
    contributed by @bayashi.

=back

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

L<http://tech.bayashi.jp/archives/entry/perl-module/2011/003305.html>

L<http://sartak.org/talks/yapc-na-2011/cpandoc/>

=head1 AUTHOR

Shawn M Moore C<sartak@gmail.com>

=head1 COPYRIGHT

Copyright 2011 Shawn M Moore.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

