#!perl
#===============================================================================
#
# t/04_par.t
#
# DESCRIPTION
#   Test script to check PAR::Filter::Crypto module (and decryption filter).
#
# COPYRIGHT
#   Copyright (C) 2004-2006, 2008-2009, 2012 Steve Hay.  All rights reserved.
#
# LICENCE
#   You may distribute under the terms of either the GNU General Public License
#   or the Artistic License, as specified in the LICENCE file.
#
#===============================================================================

use 5.006000;

use strict;
use warnings;

use Carp qw();
use Config qw(%Config);
use Cwd qw(abs_path);
use File::Spec::Functions qw(canonpath catdir catfile curdir updir);
use FindBin qw($Bin);
use Test::More;

#===============================================================================
# INITIALIZATION
#===============================================================================

my($pp);

BEGIN {
    my $top_dir = canonpath(abs_path(catdir($Bin, updir())));
    my $lib_dir = catfile($top_dir, 'blib', 'lib', 'Filter', 'Crypto');

    unless (-f catfile($lib_dir, 'CryptFile.pm')) {
        plan skip_all => 'CryptFile component not built';
    }

    unless (-f catfile($lib_dir, 'Decrypt.pm')) {
        plan skip_all => 'Decrypt component not built';
    }

    unless (eval { require PAR::Filter; 1 }) {
        plan skip_all => 'PAR::Filter required to test PAR::Filter::Crypto';
    }

    if ($Carp::VERSION eq '1.18' or $Carp::VERSION eq '1.19' or
        $Carp::VERSION eq '1.20')
    {
        plan skip_all => 'Carp 1.21 or higher required to use PAR::Filter::Crypto';
    }

    my @keys = qw(
        installsitescript installvendorscript installscript
        installsitebin    installvendorbin    installbin
    );

    foreach my $key (@keys) {
        next unless exists $Config{$key} and $Config{$key} ne '';
        next unless -d $Config{$key};
        $pp = catfile($Config{$key}, 'pp');
        last if -f $pp;
        undef $pp;
    }

    if (defined $pp) {
        plan tests => 16;
    }
    else {
        plan skip_all => "'pp' required to test PAR::Filter::Crypto";
    }
}

#===============================================================================
# MAIN PROGRAM
#===============================================================================

MAIN: {
    my $fh;
    my $mbfile = 'myblib.pm';
    my $mbname = 'myblib';
    my $ifile  = 'test.pl';
    my $ofile  = "test$Config{_exe}";
    my $str    = 'Hello, world.';
    my $prog   = qq[use strict; print "$str\\n";\n];
    my $head   = 'use Filter::Crypto::Decrypt;';

    # Before 5.7.3, -Mblib emitted a "Using ..." message on STDERR, which looks
    # ugly when we spawn a child perl process and breaks the --silent test.
    open $fh, ">$mbfile" or die "Can't create file '$mbfile': $!\n";
    print $fh qq[local \$SIG{__WARN__} = sub { };\neval 'use blib';\n1;\n];
    close $fh;

    my $perl_exe = $^X =~ / /o ? qq["$^X"] : $^X;
    my $perl = qq[$perl_exe -M$mbname];

    my $have_archive_zip = eval { require Archive::Zip; 1 };
    my $have_broken_module_scandeps;
    if (eval { require Module::ScanDeps; 1 }) {
        $have_broken_module_scandeps = ($Module::ScanDeps::VERSION eq '0.75');
    }

    my($line, $cur_ofile);

    unlink $ifile or die "Can't delete file '$ifile': $!\n" if -e $ifile;
    unlink $ofile or die "Can't delete file '$ofile': $!\n" if -e $ofile;

    open $fh, ">$ifile" or die "Can't create file '$ifile': $!\n";
    print $fh $prog;
    close $fh;

    qx{$perl $pp -f Crypto -M Filter::Crypto::Decrypt -o $ofile $ifile};
    is($?, 0, 'pp -f Crypto exited successfully');
    cmp_ok(-s $ofile, '>', 0, '... and created a non-zero size PAR archive');

    SKIP: {
        skip 'Archive::Zip required to inspect PAR archive', 5
            unless $have_archive_zip;

        my $zip = Archive::Zip->new() or die "Can't create new Archive::Zip\n";
        my $ret = eval { $zip->read($ofile) };
        is($@, '', 'No exceptions were thrown reading the PAR archive');
        is($ret, Archive::Zip::AZ_OK(), '... and read() returned OK');
        like($zip->contents("script/$ifile"), qr/^\Q$head\E/,
             '... and the script contents are as expected');
        unlike($zip->contents("lib/strict.pm"), qr/^\Q$head\E/,
             '... and the included module contents are as expected');
        unlike($zip->contents("lib/Filter/Crypto/Decrypt.pm"), qr/^\Q$head\E/,
             '... and the decryption module contents are as expected');
    }

    SKIP: {
        skip "Module::ScanDeps $Module::ScanDeps::VERSION is broken", 1
            if $have_broken_module_scandeps;

        # Some platforms search the directories in PATH before the current
        # directory so be explicit which file we want to run.
        $cur_ofile = catfile(curdir(), $ofile);
        chomp($line = qx{$cur_ofile});
        is($line, $str, 'Running the PAR archive produces the expected output');
    }

    unlink $ofile;

    qx{$perl $pp -f Crypto -F Crypto -M Filter::Crypto::Decrypt -o $ofile $ifile};
    is($?, 0, 'pp -f Crypto -F Crypto exited successfully');
    cmp_ok(-s $ofile, '>', 0, '... and created a non-zero size PAR archive');

    SKIP: {
        skip 'Archive::Zip required to inspect PAR archive', 5
            unless $have_archive_zip;

        my $zip = Archive::Zip->new() or die "Can't create new Archive::Zip\n";
        my $ret = eval { $zip->read($ofile) };
        is($@, '', 'No exceptions were thrown reading the PAR archive');
        is($ret, Archive::Zip::AZ_OK(), '... and read() returned OK');
        like($zip->contents("script/$ifile"), qr/^\Q$head\E/,
             '... and the script contents are as expected');
        like($zip->contents("lib/strict.pm"), qr/^\Q$head\E/,
             '... and the included module contents are as expected');
        unlike($zip->contents("lib/Filter/Crypto/Decrypt.pm"), qr/^\Q$head\E/,
             '... and the decryption module contents are as expected');
    }

    SKIP: {
        skip "Module::ScanDeps $Module::ScanDeps::VERSION is broken", 1
            if $have_broken_module_scandeps;

        # Some platforms search the directories in PATH before the current
        # directory so be explicit which file we want to run.
        $cur_ofile = catfile(curdir(), $ofile);
        chomp($line = qx{$cur_ofile});
        is($line, $str, 'Running the PAR archive produces the expected output');
    }

    unlink $mbfile;
    unlink $ifile;
    unlink $ofile;
}
