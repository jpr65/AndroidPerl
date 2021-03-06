#==============================================================================
#
# meta_scan.pl
#
#      Scan dirs with perl source code for packages and subs,
#      fill this meta information into a PQL::Cache and
#      dump it to file system
#
# Ralf Peine, Wed May 26 08:10:13 2015
#
#------------------------------------------------------------------------------
#
# Ideas
#
#------------------------------------------------------------------------------
#
# Use perl5i::Meta on PC (MSWin / Linux) 
#     to extract Meta data from running instances
#
#==============================================================================

use strict;
use warnings;

$| = 1;

use vars qw($VERSION);
$VERSION ='0.120';

use v5.10;

use Cwd;
use Data::Dumper;
use FileHandle;
use File::Find;

# local cpan adaptions, currently not released on CPAN, but stored in github
use lib '../spartanic/lib';
use Perl5::Spartanic;

use Alive qw(:all);
use Log::Trace;

use Report::Porf qw(:all);
use Scalar::Validation qw(:all);
use PQL::Cache qw (:all);
use Perl5::MetaInfo::DB;

# --- handle call args and configuration ----
my $config_file = par configuration => -Default => './android.cfg.pl' => ExistingFile => shift;

require $config_file;

my $config = MyConfig::get();

my $perl_meta_db_file = npar -perl_meta_db_file =>              Filled      => $config;
my $cpan_lib_path     = npar -cpan_lib_path     => -Optional => ExistingDir => $config;
my $perl_lib_path     = npar -perl_lib_path     => -Optional => ExistingDir => $config;

my $scan_paths        = npar -scan_paths        => -Optional => HashRef     => $config;

# my @paths = map {$_ ? $_:()}  (
#     $cpan_lib_path,
#     $perl_lib_path,
# );

unless (defined $scan_paths) {
    $scan_paths = {};
    
    $scan_paths->{CPAN} = $cpan_lib_path if $cpan_lib_path;
    $scan_paths->{Perl} = $perl_lib_path if $perl_lib_path;
}

# --- setup trace ---
my $trace_mode  = npar -trace_mode => -Default => off
                     => -Enum => [qw(off print file)]
                     => $config;
                    
my $trace_level = npar -trace_level => -Default  => -1 => Int    => $config;
my $trace_file  = npar -trace_file  => -Optional =>    => Filled => $config;

my @trace_args;

if ($trace_mode ne 'off') {
    
    my %trace_opts;
    
    if ($trace_level >= 0) {
        $trace_opts{Level} = [$trace_level, undef];
        $trace_opts{Deep}  = 4;    
    }
    
    if ($trace_mode eq 'file') {
        $trace_file = par -trace_file  => Filled => $trace_file;
        @trace_args = ($trace_mode => $trace_file, \%trace_opts);
        say "# Trace (level $trace_level) into file $trace_file";
    }
    else {
        @trace_args = ($trace_mode => \%trace_opts);
    }
    
    import Log::Trace @trace_args;
    
    TRACE '# === Start at ' . localtime() . ' ========================';
}

if ($trace_mode eq 'print') {
    Alive::all_off();
}
else {
    Alive::setup(
        -factor => 10,
        -name   => '# ',
    );
}

my $meta_perl_info_service = new Perl5::MetaInfo::DB();
my $meta_infos             = $meta_perl_info_service->new_database();

my $next_class_id    = 1;
my $next_method_id   = 1;
my $next_namspace_id = 1;
my $next_uses_id     = 1;

# --- TODO: Overwork code from cpan -----------
sub extract_perl_version {
        if (
                $_[0] =~ m/
                ^\s*
                (?:use|require) \s*
                v?
                ([\d_\.]+)
                \s* ;
                /ixms
        ) {
                my $perl_version = $1;
                $perl_version =~ s{_}{}g;
                return $perl_version;
        } else {
                return;
        }
}

sub insert_namespace {
    my $namespace = par namespace => Filled => shift;
    
    if ($namespace) {
        my $namespace_known = $meta_infos->select(
            what  => all       =>  
            from  => namespace =>
            where => [ name => $namespace ]
        );
                
        return 1 if (scalar @$namespace_known);
            
        $meta_infos->insert(
            namespace => {
                ID    => $next_namspace_id++, 
                name  => $namespace,
            }
        );
        
        # say "added namespace: $next_namspace_id => $namespace";
    }
    
    return 0;
}
            
sub scan_file {
    my $file = par PerlFile => ExistingFile => shift;
    my $part = par part     => Filled       => shift;
    my $path = par path     => ExistingDir  => shift; 
    
    # say "# --- scan $file ---";
    
    tack;
    
    my $fh = new FileHandle();
    my $full_file_name = $File::Find::name;
    
    $full_file_name =~ s{\\}{/}og;

    return unless $fh->open($full_file_name);
    
    my @file_content = $fh->getlines();
    $fh->close;
    
    scan_content($full_file_name, \@file_content, $part, $path);
}
    
sub scan_content {
    my $full_file_name = par full_file_name => Filled   => shift;
    my $file_content   = par file_content   => ArrayRef => shift;
    my $part           = par part     => Filled       => shift;
    my $path           = par path     => ExistingDir  => shift; 
    
    TRACE "# --- scan content of $full_file_name ---";
    
    $part =~ s{\\}{/}og;
    $path =~ s{\\}{/}og;

    $full_file_name =~ s{$path/}{{$part}/}i;
    
    my $full_class;
    my $current_class_id = 1;
    my $line;
    my $class_meta_info;
    my %modules_used;
    my $perl_version = '';
    
    my $line_nbr = 0;
    while (my $line = shift @$file_content) {
        $line =~ s/\s+$//o;
        
        $line_nbr++;
        
        last if $line =~ /^\s*__END__\s*$/;
        
        if ($line =~ /^\s*use\s([\w\.:]+)/) {
            my $used_str = $1;
            if ($used_str =~ /^v?([\d\.]+)$/) {
                $perl_version = $1;
                $class_meta_info->{perl_vers} = $perl_version if $class_meta_info;
            }
            else { 
                $modules_used{$used_str}++;
            }
        }
        elsif ($line =~ /^\s*package\s+([\w:]+);/) {
            $full_class = $1;
            # say "class $full_class";
            
            my $namespace  = "";
            my $class_name = $full_class;
            
            if ($full_class =~ /(.*)::(\w+)$/) {
                $namespace  = $1;
                $class_name = $2;
            }
            my @modules_used_names = sort (keys (%modules_used));
            $current_class_id = $next_class_id++;
            $class_meta_info  = {
                    ID        => $current_class_id,
                    fullname  => $full_class,
                    filename  => $full_file_name,
                    location  => $part,
                    namespace => $namespace,
                    classname => $class_name,
                    line_nbr  => $line_nbr,
                    line      => $line,
                    perl_vers => $perl_version,  
                    subs      => {},
                    uses      => \@modules_used_names,
                };
            $meta_infos->insert(class => 
                $class_meta_info
            );
            
            while ($namespace  &&  ! insert_namespace($namespace)) {
                last unless $namespace =~ /::/;
                $namespace =~ s/::\w+$//;
            }
        }
        elsif ($line =~ /^\s*sub\s+(\w+)(.*)/) {
            my $sub_name = $1;
            my $sub_rest_of_line = $2;
            
            my $current_method_id = $next_method_id++;
            my $method_meta_info = {
                    ID       => $current_method_id,
                    name     => $sub_name,
                    class_ID => $current_class_id,
                    line_nbr => $line_nbr,
                    line     => $line,
                };
                
            $class_meta_info->{subs}->{$sub_name} = $method_meta_info if $class_meta_info;
            $meta_infos->insert(method => 
                $method_meta_info
            );

        # $meta_infos->{$doc_class_name}->{subs}->{$doc_class_method} = {};
        }
    }
    # say "# used: %modules_used";
    foreach my $used_module (sort(keys(%modules_used))) {
        my $uses_info = {
            ID       => $next_uses_id++,
            class_ID => $current_class_id,
            used     => $used_module,
        };
        $meta_infos->insert(uses => $uses_info); 
    }
    # say "# --- done ---";
}

say '';
say '# --- start scan for classes and methods -----------------------';
say '';

$meta_infos->insert(class => {
                        ID        => $next_class_id++,
                        location  => '-',
                        fullname  => 'main',
                        filename  => '',
                        namespace => '',
                        classname => 'main',
                        line_nbr  => '',
                        line      => '',
                        perl_vers => '',  
                        subs      => {},
                        uses      => [],
                }
);

TRACE '# --- dirs to scan recursive ------------------------------------';
TRACE '';

foreach my $dir (sort (values (%$scan_paths))) { TRACE $dir; };

TRACE '';
TRACE '# --- start scan ---';
TRACE '';

foreach my $part (sort (keys (%$scan_paths))) {
    my $path = $scan_paths->{$part};
    
    $path = File::Spec->rel2abs($path);
    
    find( sub {
        if (-d $_) {
           TRACE "# --- scan dir $_ ---";
        }
        elsif (/\.pm$/i) {
            scan_file($_, $part, $path);
        }
    }, $path);
}
                
my $class_meta_infos = $meta_infos->select(
                what => all    =>
                from => 'class',
                );

my $method_meta_infos = $meta_infos->select(
                what => all    =>
                from => 'method',
                );

TRACE '# ' . $#$class_meta_infos  . ' classes found.';
TRACE '# ' . $#$method_meta_infos . ' methods found.';

TRACE "# Dump DB into file $perl_meta_db_file ...";
    
$meta_perl_info_service->write($perl_meta_db_file);
                
TRACE '# === All done at ' . localtime . ' ========================';

unless ($trace_mode eq 'print') {
    say '';
    say '# === All done. ========================';
}

1;

__END__

=head1 NAME

meta_scan.pl - Pure perl tool to extract meta data from perl source code

Scan dirs with perl source code for packages and subs,
fill this meta information into a PQL::Cache and
dump it to file system

=head1 VERSION

This documentation refers to version 0.101 of meta_scan.pl

=head1 SYNOPSIS

  meta_scan.pl <config_file.pl>
  
All parameters are defined in the config file, which is a simple Perl file:

  package MyConfig;

  my $root_dir = '/storage/emulated/legacy';

  sub get {
      return {
          -perl_meta_db_file => "$root_dir/perl_sw/info/perl_meta_dump.pl.dump",
          -cpan_lib_path     => "$root_dir/CCTools/Perl/CPAN/lib",
          # -perl_lib_path     => '.',
      };
  }

  1;
  
Create your own config file by copy of android.cfg.pl

=head1 DESCRIPTION

Just create config file and start script. Wait some seconds.

Wait a little longer when parsing your local cpan installation.

Thats all!

=head2 What is extracted

Currently only package name and all subs matching

  /^\s*sub\s+(\w+)/

