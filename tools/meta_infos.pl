# meta info system

use warnings;
use strict;

use v5.10;

use Data::Dumper;

use lib '/storage/emulated/legacy/CCTools/Perl/CPAN/lib';
use lib 'e:/user/peine/prj/my_cpan/lib';

use Report::Porf qw(:all);
use Scalar::Validation qw(:all);
use PQL::Cache qw (:all);

# --- handle call args and configuration ----
my $config_file = par configuration => -Default => './android.cfg.pl' => ExistingFile => shift;

require $config_file;

my $config = MyConfig::get();
my $perl_meta_db_file = npar -perl_meta_db_file => ExistingFile => $config;

# --- load database ------

our $perl_meta_info_db;

load_perl_meta_info($perl_meta_db_file);
# load_perl_meta_info('e:/user/peine/prj/my_cpan/ide/perl_meta_dump.pl.dump');


# ----------

# s/^'//o;

# c | search class     .*name.*
# m | search method    .*name.*|class::name 
# p | search parameter .*name.*|class::method::name 

# cm  | class & method             | 
# cmp | class & method & parameter | 

my $max_method_rows = 100;
my $max_class_rows  =  30;

sub load_perl_meta_info {
    my $dump_db_file_name = par dump_file => ExistingFile => shift;
    say "# Load from file $dump_db_file_name";
    $perl_meta_info_db = PQL::Cache::new_from_dump("PerlMeta", $dump_db_file_name);
    
    my $classes = $perl_meta_info_db->select(
	        what => [qw(ID fullname line_nbr)],
	        from => 'class',
	   );
    
    say '# '.scalar (@$classes) . " class infos loaded.";
    
    my $methods = $perl_meta_info_db->select(
        what  => 'all',
	       from  => 'method',
	   );

    say '# '.scalar (@$methods) . " method infos loaded.";    
}



# --- Add infos of class to method infos ---------------------------
sub join_class_to_method {
    my $method_list     = par method_list => ArrayRef => shift;

    my %class_ids_hash = map { $_->{class_ID} ? ($_->{class_ID} => 1) : (1, 1); } @$method_list;
        
    my @class_ids = sort keys %class_ids_hash;
    # say "# class Ids @class_ids";
        
    my $class_infos_selection = $perl_meta_info_db->select(
        what  => [qw(ID fullname)],
        from  => 'class',
        where => [ ID => {in => [@class_ids] }
        ],
    );
    
    # auto_report($class_infos_selection);
    
    my %class_infos = map { $_->{ID} => $_; } @$class_infos_selection;
        
    foreach my $method_info (@$method_list) {
        my $class_id = delete $method_info->{class_ID} || "1";
        my $class_info_ref = $class_infos{$class_id};
        
        $method_info->{class} 
            = $class_info_ref
            ? $class_info_ref->{fullname}
            : "?$class_id";
    }
    
    return $method_list;
}

sub sort_by {
    my $sort_column  = par sort_column => Filled   => shift;
    my $rows         = par rows        => ArrayRef => shift; 
    my $sort_mode    = par sort_mode   => -Default => String => -Enum => [qw (String Numbers)] => shift;

    # say "sort mode $sort_mode";

    my @sorted_rows
            = lc($sort_mode) eq 'string'
            ? sort {($a->{$sort_column}||'') cmp ($b->{$sort_column}||'')} @$rows
            : sort {($a->{$sort_column}||'0') <=> ($b->{$sort_column}||'0')} @$rows
            ; 
    return \@sorted_rows
}

sub report_methods {
    my $method_infos = par method_infos => ArrayRef => shift;
    
    my $method_count = scalar @$method_infos;
    say "# $method_count methods found, list only first $max_method_rows"
        if $method_count > $max_method_rows;
        
    auto_report(
        sort_by(
            name =>
            join_class_to_method($method_infos),
        ),
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
        say "# select classes matching names by '$name_regex'";
        my $class_infos = $perl_meta_info_db->select(
                    what  => [qw(ID fullname line_nbr)],
                    from  => 'class',
                    where => [ fullname => {like => $name_regex}
                    ],
                );
        
        say "# ".scalar(@$class_infos)." classes found";
        
        auto_report( sort_by( fullname => $class_infos ),
                     -max_rows => 30                
        );
    }
    elsif ($command eq 'm') {
        my $name_regex = handle_regex($args[0]);
        
        say "# select methods matching names by '$name_regex'";
        my $method_infos = 
        $perl_meta_info_db->select(
            what  => [qw(ID class_ID name line_nbr)],
            from  => 'method',
            where => [ name => {like => $name_regex}
                     ],
        );
        
        report_methods($method_infos);
    }
    elsif ($command eq 'mc') {
        my $class_name_regex  = handle_regex($args[0]);
        my $method_name_regex = handle_regex($args[1]);
        
        say "# select methods of classes '$class_name_regex'";
        
        my $class_infos = $perl_meta_info_db->select(
                    what  => [qw(ID fullname line_nbr)],
                    from  => 'class',
                    where => [ fullname => {like => $class_name_regex}
                    ],
        );
        
        my @class_ids = map { $_->{ID}; } @$class_infos;
        # auto_report($class_infos);
        say "# ".scalar(@class_ids)." classes found.";
        say "# select methods with matching names by '$method_name_regex'";
        my $method_infos = 
            $perl_meta_info_db->select(
            what  => [qw(ID class_ID name line_nbr)],
            from  => 'method',
            where => [ class_ID => [@class_ids],
                       name     => {like => $method_name_regex},
                     ],
        );
        
        report_methods($method_infos);
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