# android cfg
#
# create your own cfg file

use strict;
use warnings;

package MyConfig;

my $root_dir = '/storage/emulated/legacy';

sub get {
    return {
        -perl_meta_db_file => "$root_dir/perl_sw/info/perl_meta_dump.pl.dump",
        -cpan_lib_path     => "$root_dir/CCTools/Perl/CPAN/lib",
        -perl_lib_path     => '../lib',
        -html_out_path     => '../html',
    };
}

1;