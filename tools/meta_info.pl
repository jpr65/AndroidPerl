#==============================================================================
#
# meta_info.pl
#
#      Read dump of PQL::Cache created by meta_scan.pl and
#      start query info system.
#
# Ralf Peine, Mon Apr 27 21:45:17 2015
#
#==============================================================================

use strict;
use vars qw($VERSION);
$VERSION ='0.101';

$| = 1;
use v5.10;

use Data::Dumper;

# spartanic libs, stored in github
use lib '../spartanic/lib';

use Perl5::Spartanic;
use Scalar::Validation qw(:all);
use PQL::Cache qw (:all);
use Report::Porf qw(:all);

use Perl5::MetaInfo::DB;

# --- handle call args and configuration ----
my $config_file = par configuration => -Default => './android.cfg.pl' => ExistingFile => shift;

require $config_file;

my $config = MyConfig::get();

my $perl_meta_db_file = npar -perl_meta_db_file => ExistingFile => $config;
my $max_method_rows   = 100;
my $max_class_rows    =  30;

# --- load database ------

our $perl_meta_info_db;
our $meta_perl_info_service = new Perl5::MetaInfo::DB();

$meta_perl_info_service->read($perl_meta_db_file);

# ----------

# s/^'//o;

# c | search class     .*name.*
# m | search method    .*name.*|class::name 
# p | search parameter .*name.*|class::method::name 

# cm  | class & method             | 
# cmp | class & method & parameter | 

sub report_methods {
    my $method_infos = par method_infos => ArrayRef => shift;
    
    my $method_count = scalar @$method_infos;
    if ($method_count > $max_method_rows) {
        say "# $method_count methods found, list only first $max_method_rows";
    }
    else {
        say "# $method_count methods found.";
    }
    auto_report(
        $method_infos,
        -max_rows => $max_method_rows
    );
}

sub handle_regex {
    my $regex = par regex => -Default => '.*' => Filled => shift;

    $regex =~ s/§/^/og;
    
    return $regex;
}

my @history;
sub history {
    my $cmd_nr = par command_nbr => -Default => 0 => Int => shift;
    
    my $i = 1;
    my @print_history = map { sprintf ("[%3d] $_\n", $i++); } @history;
    say @print_history;
}

sub print_help {
    say "# ====================";
    say "#   Help";
    say "# ====================";
    say "# c:  select classes: <class_regex>";
    say "# m:  select methods: <method_regex>";
    say "# mc: select methods of classes: <class_regex> <method_regex>";
    say "# qq: quit";
    say "# h:  history";
    say "# ?:  help";
    say "# § will be replaced by ^ in regexes";
    say "# ====================";
}

print "? ";
while (my $command_str = <STDIN>) {
    chomp $command_str;
    
    $command_str =~ s/^\s+//;
    
    if ($command_str =~ /^!\s*(\d*)\s*$/) {
        my $cmd_nbr = ($1 || 0) - 1;
        $command_str = $history[$cmd_nbr];
    }
    
    say "command $command_str";
    
    push (@history, $command_str);
    
    my ($command, @args) = split (/\s+/, $command_str);
    
    $command = lc($command || '<undef>');
    
    if ($command eq 'c') {
        my $name_regex = handle_regex($args[0]);
        
        say "# select classes '$name_regex'";

        my $class_infos = $meta_perl_info_service->select_classes($name_regex);

        my $class_count = scalar @$class_infos;
        
        if ($class_count > $max_class_rows) {
            say "# $class_count classes found, list only first $max_class_rows";
        }
        else {
            say "# $class_count classes found.";
        }
    
        auto_report( $class_infos, -max_rows => $max_class_rows);
    }
    elsif ($command eq 'm') {
        my $name_regex = handle_regex($args[0]);
        
        say "# select methods '$name_regex'";
        
        report_methods($meta_perl_info_service->select_methods($name_regex));
    }
    elsif ($command eq 'mc') {
        my $class_name_regex  = handle_regex($args[0]);
        my $method_name_regex = handle_regex($args[1]);
        
        say "# select methods '$method_name_regex'";
        say "#     of classes '$class_name_regex'";
        
        report_methods($meta_perl_info_service->select_methods_of_classes(
                            $class_name_regex,
                            $method_name_regex,
                            ));
    }
    elsif ($command eq 'qq') {
        say "# Goodbye!";
        last;
    }
    elsif ($command eq 'h') {
        pop @history;
        history();
    }
    elsif ($command eq '?') {
        pop @history;
        print_help();
    }
    else {
        pop @history;
        say '';
        say "*** unknown command: $command @args";
        say '';
        print_help();
    }

    print "? ";
}
