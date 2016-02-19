# android cfg
#
# create your own cfg file

use strict;
use warnings;

package MyConfig;

my $root_dir          = '/storage/emulated/legacy';
my $html_template_dir = './html_templates';

sub get {
    return {
        # -trace_mode        => 'off',
        # -trace_mode        => 'print',
        -trace_mode        => 'file',
        -trace_level       => 2,
                              # absolute path needed for file find
        -trace_file        => '/storage/emulated/legacy/perl_sw/info/trace.log',
        
        -perl_meta_db_file => "$root_dir/perl_sw/info/perl_meta_dump.pl.dump",
        # -cpan_lib_path     => "$root_dir/CCTools/Perl/CPAN/lib",
        # -perl_lib_path     => '../lib',
        -html_out_path     => "$root_dir/perl_sw/info",
        -scan_paths        => { 
                                CPAN => "$root_dir/CCTools/Perl/CPAN/lib",
                                PERL => "$root_dir/perl_sw/perl_lib",
                                PROJ => '../lib',
                                SPRT => '../spartanic/lib',
                              },
        -doc_paths         => {
                                PERL => "$root_dir/perl_sw/doc/perldoc-html",
                                CPAN => "$root_dir/perl_sw/doc/cpandoc-html",
                                SPRT => "$root_dir/perl_sw/doc/spartanic-doc-html",
        },
        -html_templates    => {
                                package  => "$html_template_dir/package.htmpl",
                                overview => "$html_template_dir/overview.htmpl",
                              },
    };
}

1;
